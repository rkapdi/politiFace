-- Onboarding phase 1: one console for faculty onboarding and student
-- browser identity (spec 2026-09-27, sections 1 and 2).
--
--   1. Faculty invites become links: expiry, revocation, a recipient hint,
--      and a signed-out preview for the #/welcome page. Staff can mint.
--   2. Faculty access requests: a professor without a link asks; staff
--      approve with one click.
--   3. my_console_role / my_student_classes: the console picks a home.
--   4. Live sessions: a signed-out preview, a member join that enrolls on
--      first use (same account as the iOS app), and guests opt-in.

-- ── 1. invite links ─────────────────────────────────────────────────────────
alter table public.faculty_invites
  add column expires_at timestamptz not null default now() + interval '14 days',
  add column recipient_email text
    check (recipient_email is null or length(recipient_email) <= 254),
  add column revoked_at timestamptz;

drop function public.mint_faculty_invite(text);
create function public.mint_faculty_invite(
  p_note text default null,
  p_recipient_email text default null
) returns text
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_code text;
begin
  if not (app.is_verified_faculty(auth.uid()) or app.is_admin(auth.uid())) then
    raise exception 'only verified faculty can mint invites';
  end if;
  insert into public.faculty_invites (minted_by, note, recipient_email)
  values (auth.uid(), nullif(trim(p_note), ''),
          nullif(lower(trim(p_recipient_email)), ''))
  returning code into v_code;
  return v_code;
end;
$$;
revoke all on function public.mint_faculty_invite(text, text) from public, anon;
grant execute on function public.mint_faculty_invite(text, text) to authenticated;

create function public.revoke_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  update public.faculty_invites
     set revoked_at = coalesce(revoked_at, now())
   where code = upper(trim(p_code))
     and (minted_by = auth.uid() or app.is_admin(auth.uid()));
  if not found then raise exception 'invite not found'; end if;
end;
$$;
revoke all on function public.revoke_faculty_invite(text) from public, anon;
grant execute on function public.revoke_faculty_invite(text) to authenticated;

-- Signed-out preview for the welcome page: validity and the inviter's
-- display name only. Nothing else about the invite leaves the server.
create function public.invite_preview(p_code text) returns jsonb
language sql stable security definer set search_path = public, app, pg_temp as $$
  select coalesce(
    (select jsonb_build_object(
              'valid', i.revoked_at is null and i.expires_at > now()
                       and i.uses < i.max_uses,
              'inviter', p.handle)
       from public.faculty_invites i
       join public.profiles p on p.id = i.minted_by
      where i.code = upper(trim(p_code))),
    jsonb_build_object('valid', false, 'inviter', null));
$$;
grant execute on function public.invite_preview(text) to anon, authenticated;

create or replace function public.redeem_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_invites%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.faculty_invites
   where code = upper(trim(p_code)) for update;
  if not found or v_row.uses >= v_row.max_uses
     or v_row.revoked_at is not null or v_row.expires_at <= now() then
    raise exception 'invalid or exhausted invite code';
  end if;
  update public.faculty_invites set uses = uses + 1 where code = v_row.code;
  insert into app.verified_faculty (user_id, granted_by, note)
  values (v_user, v_row.minted_by, v_row.note)
  on conflict (user_id) do nothing;
end;
$$;

-- ── 2. faculty access requests ──────────────────────────────────────────────
create table public.faculty_access_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  school     text not null check (length(trim(school)) between 2 and 120),
  courses    text not null check (length(trim(courses)) between 2 and 200),
  note       text check (note is null or length(note) <= 500),
  status     text not null default 'pending'
             check (status in ('pending', 'approved', 'denied')),
  decided_by uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index faculty_access_requests_one_open
  on public.faculty_access_requests (user_id) where status = 'pending';
-- RPC-only: RLS on, no policies.
alter table public.faculty_access_requests enable row level security;

create function public.request_faculty_access(
  p_school text, p_courses text, p_note text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_access_requests%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if app.is_verified_faculty(v_user) then
    raise exception 'already a verified instructor';
  end if;
  update public.faculty_access_requests
     set school = trim(p_school), courses = trim(p_courses),
         note = nullif(trim(p_note), '')
   where user_id = v_user and status = 'pending'
  returning * into v_row;
  if not found then
    insert into public.faculty_access_requests (user_id, school, courses, note)
    values (v_user, trim(p_school), trim(p_courses), nullif(trim(p_note), ''))
    returning * into v_row;
  end if;
  return jsonb_build_object('id', v_row.id, 'status', v_row.status,
    'school', v_row.school, 'courses', v_row.courses, 'note', v_row.note,
    'created_at', v_row.created_at);
end;
$$;
revoke all on function public.request_faculty_access(text, text, text) from public, anon;
grant execute on function public.request_faculty_access(text, text, text) to authenticated;

create function public.my_faculty_access_request() returns jsonb
language sql stable security definer set search_path = public, app, pg_temp as $$
  select jsonb_build_object('id', r.id, 'status', r.status, 'school', r.school,
           'courses', r.courses, 'note', r.note, 'created_at', r.created_at)
    from public.faculty_access_requests r
   where r.user_id = auth.uid()
   order by r.created_at desc
   limit 1;
$$;
revoke all on function public.my_faculty_access_request() from public, anon;
grant execute on function public.my_faculty_access_request() to authenticated;

create function public.admin_list_faculty_requests()
returns table (id uuid, user_id uuid, handle text, email text, school text,
               courses text, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = public, app, auth, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select r.id, r.user_id, p.handle, u.email::text, r.school, r.courses,
           r.note, r.created_at
      from public.faculty_access_requests r
      join public.profiles p on p.id = r.user_id
      join auth.users u on u.id = r.user_id
     where r.status = 'pending'
     order by r.created_at;
end;
$$;
revoke all on function public.admin_list_faculty_requests() from public, anon;
grant execute on function public.admin_list_faculty_requests() to authenticated;

create function public.admin_decide_faculty_request(p_id uuid, p_approve boolean)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_user uuid;
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  update public.faculty_access_requests
     set status = case when p_approve then 'approved' else 'denied' end,
         decided_by = auth.uid(), decided_at = now()
   where id = p_id and status = 'pending'
  returning user_id into v_user;
  if v_user is null then raise exception 'request not found or already decided'; end if;
  if p_approve then
    insert into app.verified_faculty (user_id, granted_by, note)
    values (v_user, auth.uid(), 'approved access request')
    on conflict (user_id) do nothing;
  end if;
end;
$$;
revoke all on function public.admin_decide_faculty_request(uuid, boolean) from public, anon;
grant execute on function public.admin_decide_faculty_request(uuid, boolean) to authenticated;

-- ── 3. console home ─────────────────────────────────────────────────────────
-- Highest role wins: staff, then faculty (verified or teaching a class as
-- faculty), then ta, then student, else none.
create function public.my_console_role() returns text
language sql stable security definer set search_path = public, app, pg_temp as $$
  select case
    when app.is_admin(auth.uid()) then 'staff'
    when app.is_verified_faculty(auth.uid())
      or exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'faculty') then 'faculty'
    when exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'ta') then 'ta'
    when exists (select 1 from public.cohort_members
                  where user_id = auth.uid() and role = 'student') then 'student'
    else 'none'
  end;
$$;
revoke all on function public.my_console_role() from public, anon;
grant execute on function public.my_console_role() to authenticated;

create function public.my_student_classes()
returns table (cohort_id uuid, name text, term text, professor text,
               roster_name text)
language sql stable security definer set search_path = public, app, pg_temp as $$
  select c.id, c.name, c.term, p.handle, m.roster_name
    from public.cohort_members m
    join public.cohorts c on c.id = m.cohort_id
    left join public.profiles p on p.id = c.created_by
   where m.user_id = auth.uid() and m.role = 'student'
   order by c.name;
$$;
revoke all on function public.my_student_classes() from public, anon;
grant execute on function public.my_student_classes() to authenticated;
