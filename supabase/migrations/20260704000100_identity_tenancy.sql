-- Identity and tenancy: pseudonymous profiles, orgs, cohorts, membership.
-- PII (email) lives only in auth.users. Nothing here may ever hold political
-- affiliation, voting history, or education records (see ARCHITECTURE.md).

-- Internal schema: helpers, protected data (answer keys), server-only logic.
-- Never exposed through PostgREST; clients have no privileges here.
create schema if not exists app;
revoke all on schema app from public, anon, authenticated;

-- ── profiles ────────────────────────────────────────────────────────────────
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  handle     text not null
             check (handle ~ '^[A-Za-z0-9_]{3,20}$'),
  school     text,  -- self-selected label, NOT institutional identity
  created_at timestamptz not null default now()
);
create unique index profiles_handle_lower_idx on public.profiles (lower(handle));

-- ── orgs / cohorts / membership ─────────────────────────────────────────────
create table public.orgs (
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.cohorts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid references public.orgs (id),
  name        text not null,
  term        text,
  exam_window daterange,
  join_code   text unique not null,
  created_by  uuid not null references public.profiles (id),
  created_at  timestamptz not null default now()
);

create table public.cohort_members (
  cohort_id uuid not null references public.cohorts (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      text not null check (role in ('student', 'faculty')),
  joined_at timestamptz not null default now(),
  primary key (cohort_id, user_id)
);
create index cohort_members_user_idx on public.cohort_members (user_id);

-- ── membership helpers ──────────────────────────────────────────────────────
-- SECURITY DEFINER so RLS policies can consult membership without recursing
-- into cohort_members' own policies.
create function app.is_cohort_member(p_cohort uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = p_cohort and user_id = auth.uid()
  );
$$;

create function app.is_cohort_faculty(p_cohort uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  );
$$;

-- Most recently joined cohort; used to tag events when no explicit context.
create function app.current_cohort(p_user uuid) returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select cohort_id from public.cohort_members
  where user_id = p_user
  order by joined_at desc
  limit 1;
$$;

-- Share-a-cohort join codes: 6 chars, unambiguous alphabet, retry on the
-- (unlikely) collision.
create function app.gen_join_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := (
      select string_agg(substr(alphabet, 1 + floor(random() * 31)::int, 1), '')
      from generate_series(1, 6)
    );
    exit when not exists (select 1 from public.cohorts where join_code = code);
  end loop;
  return code;
end;
$$;

alter table public.cohorts alter column join_code set default app.gen_join_code();

-- Creator automatically becomes faculty of their cohort.
create function app.cohort_creator_membership() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.cohort_members (cohort_id, user_id, role)
  values (new.id, new.created_by, 'faculty')
  on conflict do nothing;
  return new;
end;
$$;

create trigger cohorts_creator_membership
  after insert on public.cohorts
  for each row execute function app.cohort_creator_membership();

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.profiles       enable row level security;
alter table public.orgs           enable row level security;
alter table public.cohorts        enable row level security;
alter table public.cohort_members enable row level security;

grant select, insert, update on public.profiles to authenticated;
grant select on public.orgs to authenticated;
grant select, insert, update on public.cohorts to authenticated;
grant select on public.cohort_members to authenticated;

-- Own profile: full read/write. Co-cohort members: read (leaderboard handles).
create policy profiles_select on public.profiles for select
  to authenticated using (
    id = auth.uid()
    or exists (
      select 1
      from public.cohort_members mine
      join public.cohort_members theirs on theirs.cohort_id = mine.cohort_id
      where mine.user_id = auth.uid() and theirs.user_id = profiles.id
    )
  );
create policy profiles_insert on public.profiles for insert
  to authenticated with check (id = auth.uid());
create policy profiles_update on public.profiles for update
  to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Orgs are provisioned by the service role; members of any cohort in the org
-- can read the org name.
create policy orgs_select on public.orgs for select
  to authenticated using (
    exists (
      select 1 from public.cohorts c
      where c.org_id = orgs.id and app.is_cohort_member(c.id)
    )
  );

-- Any authenticated user can create a cohort (they become its faculty).
-- Members read their cohorts; faculty update theirs.
create policy cohorts_select on public.cohorts for select
  to authenticated using (app.is_cohort_member(id));
create policy cohorts_insert on public.cohorts for insert
  to authenticated with check (created_by = auth.uid());
create policy cohorts_update on public.cohorts for update
  to authenticated using (app.is_cohort_faculty(id))
  with check (app.is_cohort_faculty(id));

-- Membership rows are created by the creator trigger and the join_cohort RPC
-- only; members can read the roster of their own cohorts.
create policy cohort_members_select on public.cohort_members for select
  to authenticated using (app.is_cohort_member(cohort_id));
