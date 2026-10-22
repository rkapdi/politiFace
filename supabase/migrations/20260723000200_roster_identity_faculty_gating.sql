-- Classroom identity architecture:
--
--   1. roster_name on cohort_members: the name the professor knows the
--      student by, collected at class join, visible ONLY to that cohort's
--      faculty. Global pseudonymity (handles) is untouched everywhere else.
--   2. Verified-faculty gating: instructors redeem an invite code to gain
--      faculty status; cohort creation requires it. Verified faculty can
--      mint invites for colleagues (the department growth loop).
--   3. Live-session presence: joins write a participant row so the lobby
--      can show a headcount before START.
--   4. Identified reporting for faculty of a cohort: per-student live
--      session report and per-student class progress. Aggregate views
--      keep their k-anonymity floors; these views are the deliberate,
--      faculty-only identified surface.

-- ── 1. roster names ─────────────────────────────────────────────────────────

alter table public.cohort_members
  add column roster_name text
  check (roster_name is null or length(trim(roster_name)) between 2 and 60);

-- join_cohort gains the roster name. Verbatim behavior otherwise; drop and
-- recreate because the signature changes.
drop function if exists public.join_cohort(text);
create function public.join_cohort(p_code text, p_roster_name text default null)
returns uuid
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_cohort uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select id into v_cohort from public.cohorts
   where join_code = upper(trim(p_code));
  if v_cohort is null then raise exception 'invalid join code'; end if;
  insert into public.cohort_members (cohort_id, user_id, role, roster_name)
  values (v_cohort, v_user, 'student',
          nullif(trim(coalesce(p_roster_name, '')), ''))
  on conflict (cohort_id, user_id) do update
    set roster_name = coalesce(excluded.roster_name,
                               public.cohort_members.roster_name);
  return v_cohort;
end;
$$;

create function public.set_roster_name(p_cohort uuid, p_name text)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  update public.cohort_members
     set roster_name = nullif(trim(p_name), '')
   where cohort_id = p_cohort and user_id = auth.uid();
  if not found then raise exception 'not a member of this cohort'; end if;
end;
$$;

-- ── 2. verified faculty + invites ───────────────────────────────────────────

create table app.verified_faculty (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id),
  note       text,
  created_at timestamptz not null default now()
);

create table public.faculty_invites (
  code       text primary key default app.gen_join_code(),
  minted_by  uuid not null references public.profiles (id),
  note       text,
  max_uses   int not null default 1 check (max_uses between 1 and 50),
  uses       int not null default 0,
  created_at timestamptz not null default now()
);
-- Codes are secrets handed instructor-to-instructor; clients never list
-- them. RLS on, no select policy, all access through RPCs.
alter table public.faculty_invites enable row level security;

create function app.is_verified_faculty(p_user uuid) returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select exists (select 1 from app.verified_faculty where user_id = p_user);
$$;

create function public.redeem_faculty_invite(p_code text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_row public.faculty_invites%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.faculty_invites
   where code = upper(trim(p_code)) for update;
  if not found or v_row.uses >= v_row.max_uses then
    raise exception 'invalid or exhausted invite code';
  end if;
  update public.faculty_invites set uses = uses + 1 where code = v_row.code;
  insert into app.verified_faculty (user_id, granted_by, note)
  values (v_user, v_row.minted_by, v_row.note)
  on conflict (user_id) do nothing;
end;
$$;

-- Verified faculty invite colleagues; each mint is single-use by default.
create function public.mint_faculty_invite(p_note text default null)
returns text
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_code text;
begin
  if not app.is_verified_faculty(auth.uid()) then
    raise exception 'only verified faculty can mint invites';
  end if;
  insert into public.faculty_invites (minted_by, note)
  values (auth.uid(), nullif(trim(p_note), ''))
  returning code into v_code;
  return v_code;
end;
$$;

create function public.am_verified_faculty() returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select app.is_verified_faculty(auth.uid());
$$;

-- Gate cohort creation on verified-faculty status. Existing cohort
-- creators are grandfathered so live classes keep working.
insert into app.verified_faculty (user_id, note)
select distinct created_by, 'grandfathered: created a cohort before gating'
  from public.cohorts
  on conflict (user_id) do nothing;

create or replace function public.create_cohort(p_name text, p_term text default null)
returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_code text;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if not app.is_verified_faculty(v_user) then
    raise exception 'instructor verification required';
  end if;
  if length(trim(coalesce(p_name, ''))) < 3 then
    raise exception 'class name too short';
  end if;
  insert into public.cohorts (name, term, created_by)
  values (trim(p_name), nullif(trim(coalesce(p_term, '')), ''), v_user)
  returning id, join_code into v_id, v_code;
  return jsonb_build_object('id', v_id, 'join_code', v_code);
end;
$$;

-- ── 3. live-session presence (lobby headcount) ──────────────────────────────

create table public.live_participants (
  session_id uuid not null references public.live_sessions (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (session_id, user_id)
);

alter table public.live_participants enable row level security;

-- Members of the cohort see the participant rows (the app can show "14
-- joined" too); counts only, handles never resolved for students.
create policy live_participants_select_members on public.live_participants
  for select to authenticated
  using (app.is_cohort_member(
    (select s.cohort_id from public.live_sessions s where s.id = session_id)
  ));

grant select on public.live_participants to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.live_participants;
  end if;
end $$;

-- join_live_session now records presence (was stable; becomes volatile).
create or replace function public.join_live_session(p_code text) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare s record;
begin
  select * into s from public.live_sessions
   where join_code = upper(trim(p_code)) and status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'join the class first';
  end if;
  insert into public.live_participants (session_id, user_id)
  values (s.id, auth.uid())
  on conflict do nothing;
  return jsonb_build_object(
    'id', s.id, 'title', s.title, 'status', s.status,
    'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds);
end;
$$;

-- Sessions surfaced by the banner record presence on entry too.
create function public.enter_live_session(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.live_sessions
   where id = p_session and status <> 'ended';
  if not found then raise exception 'no joinable session'; end if;
  if not app.is_cohort_member(v_cohort) then
    raise exception 'join the class first';
  end if;
  insert into public.live_participants (session_id, user_id)
  values (p_session, auth.uid())
  on conflict do nothing;
end;
$$;

-- ── 4. identified faculty reporting ─────────────────────────────────────────

-- Per-student session report: roster name, score, and the per-question
-- correctness matrix. Faculty of the session's cohort only.
create function public.live_session_report(p_session uuid)
returns table (
  user_id uuid,
  roster_name text,
  handle text,
  score bigint,
  correct_count bigint,
  answered bigint,
  per_question jsonb
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select m.user_id,
           coalesce(m.roster_name, p.handle) as roster_name,
           p.handle,
           coalesce(sum(case when a.correct then
             100 + round(50.0 * (1 - a.answer_ms::numeric
                   / (s.question_seconds * 1000)))
           else 0 end), 0)::bigint as score,
           count(*) filter (where a.correct) as correct_count,
           count(a.question_id) as answered,
           coalesce(jsonb_object_agg(a.question_id, a.correct)
                    filter (where a.question_id is not null),
                    '{}'::jsonb) as per_question
      from public.cohort_members m
      join public.profiles p on p.id = m.user_id
      left join public.live_answers a
        on a.session_id = p_session and a.user_id = m.user_id
     where m.cohort_id = s.cohort_id and m.role = 'student'
       and (exists (select 1 from public.live_participants lp
                     where lp.session_id = p_session
                       and lp.user_id = m.user_id)
            or exists (select 1 from public.live_answers a2
                        where a2.session_id = p_session
                          and a2.user_id = m.user_id))
     group by m.user_id, m.roster_name, p.handle
     order by score desc;
end;
$$;

-- Per-student class progress: the "who is lagging" view. Faculty of the
-- cohort only; derived from events and mock attempts already attributed
-- to the cohort.
create function public.cohort_student_progress(p_cohort uuid)
returns table (
  user_id uuid,
  roster_name text,
  handle text,
  last_active timestamptz,
  answers_total bigint,
  accuracy real,
  mocks_completed bigint,
  best_mock_score smallint
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select m.user_id,
           coalesce(m.roster_name, p.handle) as roster_name,
           p.handle,
           max(e.server_ts) as last_active,
           count(e.event_id) filter
             (where e.type = 'answer' and e.correct is not null) as answers_total,
           coalesce(avg(e.correct::int) filter
             (where e.type = 'answer' and e.correct is not null), 0)::real
             as accuracy,
           (select count(*) from public.mock_attempts a
             where a.user_id = m.user_id and a.cohort_id = p_cohort
               and a.completed_at is not null) as mocks_completed,
           (select max(a.score) from public.mock_attempts a
             where a.user_id = m.user_id and a.cohort_id = p_cohort
               and a.completed_at is not null) as best_mock_score
      from public.cohort_members m
      join public.profiles p on p.id = m.user_id
      left join public.events e
        on e.user_id = m.user_id and e.cohort_id = p_cohort
     where m.cohort_id = p_cohort and m.role = 'student'
     group by m.user_id, m.roster_name, p.handle
     order by last_active asc nulls first;
end;
$$;
