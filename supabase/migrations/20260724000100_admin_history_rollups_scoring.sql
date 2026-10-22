-- Command center + history + rollups + live scoring integration.
--
--   1. app.admins: the god-view allowlist. Admin RPCs expose operational
--      surfaces (counters, cohorts, users incl. email, invites, faculty
--      grants). Seeded from grandfathered verified faculty (the founding
--      team); later admins are added deliberately, never via invites.
--   2. Session history: faculty list their cohort's past sessions; the
--      existing report/stats RPCs already serve ended sessions.
--   3. Cross-class rollups: one row per cohort the caller teaches, with
--      the same k-anonymity floor as cohort_overview.
--   4. Live scoring integration: when a session ends, every live answer
--      is folded into public.events with a deterministic id and pushed
--      through app.apply_graded_event, so leaderboards (first-correct
--      dedupe intact), streaks, readiness, and efficacy all see live
--      play exactly like practice. Idempotent: replaying an end changes
--      nothing.

-- ── 1. admins ───────────────────────────────────────────────────────────────

create table app.admins (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  note       text,
  created_at timestamptz not null default now()
);

insert into app.admins (user_id, note)
select user_id, 'seeded from founding grandfathered faculty'
  from app.verified_faculty
 where note like 'grandfathered%'
  on conflict do nothing;

create function app.is_admin(p_user uuid) returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select exists (select 1 from app.admins where user_id = p_user);
$$;

create function public.am_admin() returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select app.is_admin(auth.uid());
$$;

create function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'verified_faculty', (select count(*) from app.verified_faculty),
    'cohorts', (select count(*) from public.cohorts),
    'memberships', (select count(*) from public.cohort_members
                     where role = 'student'),
    'active_7d', (select count(distinct user_id) from public.events
                   where server_ts > now() - interval '7 days'),
    'answers_7d', (select count(*) from public.events
                    where type = 'answer' and correct is not null
                      and server_ts > now() - interval '7 days'),
    'mocks_completed', (select count(*) from public.mock_attempts
                         where completed_at is not null),
    'live_sessions_run', (select count(*) from public.live_sessions
                           where status = 'ended'));
end;
$$;

create function public.admin_list_cohorts()
returns table (
  cohort_id uuid, name text, term text, join_code text,
  creator_handle text, students bigint, faculty bigint,
  answers_7d bigint, created_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select c.id, c.name, c.term, c.join_code, p.handle,
           count(m.user_id) filter (where m.role = 'student'),
           count(m.user_id) filter (where m.role = 'faculty'),
           (select count(*) from public.events e
             where e.cohort_id = c.id and e.type = 'answer'
               and e.server_ts > now() - interval '7 days'),
           c.created_at
      from public.cohorts c
      join public.profiles p on p.id = c.created_by
      left join public.cohort_members m on m.cohort_id = c.id
     group by c.id, c.name, c.term, c.join_code, p.handle, c.created_at
     order by c.created_at desc;
end;
$$;

create function public.admin_search_users(p_q text)
returns table (
  user_id uuid, handle text, email text, is_faculty boolean,
  is_admin boolean, classes bigint, created_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if length(trim(coalesce(p_q, ''))) < 2 then
    raise exception 'query too short';
  end if;
  return query
    select pr.id, pr.handle, u.email::text,
           app.is_verified_faculty(pr.id),
           app.is_admin(pr.id),
           (select count(*) from public.cohort_members m
             where m.user_id = pr.id),
           pr.created_at
      from public.profiles pr
      join auth.users u on u.id = pr.id
     where pr.handle ilike '%' || trim(p_q) || '%'
        or u.email ilike '%' || trim(p_q) || '%'
     order by pr.created_at desc
     limit 25;
end;
$$;

create function public.admin_set_faculty(p_user uuid, p_verified boolean)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  if p_verified then
    insert into app.verified_faculty (user_id, granted_by, note)
    values (p_user, auth.uid(), 'granted by admin')
    on conflict do nothing;
  else
    delete from app.verified_faculty where user_id = p_user;
  end if;
end;
$$;

create function public.admin_list_invites()
returns table (
  code text, note text, minted_by_handle text,
  max_uses int, uses int, created_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select i.code, i.note, p.handle, i.max_uses, i.uses, i.created_at
      from public.faculty_invites i
      join public.profiles p on p.id = i.minted_by
     order by i.created_at desc;
end;
$$;

create function public.admin_list_live_sessions()
returns table (
  session_id uuid, cohort_name text, title text, status text,
  questions int, participants bigint, created_at timestamptz,
  ended_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_admin(auth.uid()) then raise exception 'admin only'; end if;
  return query
    select s.id, c.name, s.title, s.status,
           jsonb_array_length(s.question_ids),
           (select count(*) from public.live_participants lp
             where lp.session_id = s.id),
           s.created_at, s.ended_at
      from public.live_sessions s
      join public.cohorts c on c.id = s.cohort_id
     order by s.created_at desc
     limit 100;
end;
$$;

-- ── 2. session history ──────────────────────────────────────────────────────

create function public.cohort_live_sessions(p_cohort uuid)
returns table (
  session_id uuid, title text, status text, questions int,
  participants bigint, avg_correct real,
  created_at timestamptz, ended_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select s.id, s.title, s.status,
           jsonb_array_length(s.question_ids),
           (select count(distinct x.user_id) from (
              select lp.user_id from public.live_participants lp
               where lp.session_id = s.id
              union
              select a.user_id from public.live_answers a
               where a.session_id = s.id) x),
           (select coalesce(avg(a.correct::int), 0)::real
              from public.live_answers a where a.session_id = s.id),
           s.created_at, s.ended_at
      from public.live_sessions s
     where s.cohort_id = p_cohort
     order by s.created_at desc
     limit 50;
end;
$$;

-- ── 3. cross-class rollups ──────────────────────────────────────────────────

-- One row per cohort the caller teaches; the same 5-student floor as
-- cohort_overview (below the floor, activity stats are withheld).
create function public.my_faculty_overview()
returns table (
  cohort_id uuid, name text, term text, students bigint,
  active_7d bigint, answers_total bigint, accuracy real,
  mocks_completed bigint, live_sessions bigint
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  return query
    select c.id, c.name, c.term,
           (select count(*) from public.cohort_members m
             where m.cohort_id = c.id and m.role = 'student') as students,
           case when app.cohort_student_count(c.id) >= 5 then
             (select count(distinct e.user_id) from public.events e
               where e.cohort_id = c.id
                 and e.server_ts > now() - interval '7 days')
           end,
           case when app.cohort_student_count(c.id) >= 5 then
             (select count(*) from public.events e
               where e.cohort_id = c.id and e.type = 'answer'
                 and e.correct is not null)
           end,
           case when app.cohort_student_count(c.id) >= 5 then
             (select avg(e.correct::int)::real from public.events e
               where e.cohort_id = c.id and e.type = 'answer'
                 and e.correct is not null)
           end,
           case when app.cohort_student_count(c.id) >= 5 then
             (select count(*) from public.mock_attempts a
               where a.cohort_id = c.id and a.completed_at is not null)
           end,
           (select count(*) from public.live_sessions s
             where s.cohort_id = c.id and s.status = 'ended')
      from public.cohorts c
     where app.is_cohort_faculty(c.id)
     order by c.created_at desc;
end;
$$;

create function app.cohort_student_count(p_cohort uuid) returns bigint
language sql stable security definer set search_path = public, app, pg_temp as $$
  select count(*) from public.cohort_members
   where cohort_id = p_cohort and role = 'student';
$$;

-- ── 4. live answers feed the grading pipeline at session end ────────────────

-- Fold every live answer into public.events (deterministic event ids, so
-- replays are no-ops) and run the standard grading pipeline: leaderboard
-- with the first-correct-ever dedupe, streaks, domain and objective
-- readiness, efficacy. Called from the ended transition.
create function app.finalize_live_session_scoring(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  r record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then return; end if;
  for r in
    select a.user_id, a.question_id, a.chosen_key, a.correct, a.created_at,
           q.domain_id,
           md5('live:' || a.session_id || ':' || a.question_id || ':'
               || a.user_id)::uuid as det_id
      from public.live_answers a
      join public.questions q on q.id = a.question_id
     where a.session_id = p_session
  loop
    -- Deterministic id makes the fold idempotent.
    insert into public.events
      (event_id, user_id, cohort_id, type, question_id, domain_id,
       chosen_key, correct, client_ts)
    values
      (r.det_id, r.user_id, s.cohort_id, 'answer', r.question_id,
       r.domain_id, r.chosen_key, r.correct, r.created_at)
    on conflict (event_id) do nothing;
    if found then
      perform app.apply_graded_event(
        r.user_id, s.cohort_id, r.question_id, r.domain_id,
        case when r.correct then 2 else 0 end, r.correct, r.created_at);
    end if;
  end loop;
end;
$$;

-- Recreate the two enders to invoke scoring on the ended transition.
create or replace function public.advance_live_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_total int;
begin
  select * into s from public.live_sessions where id = p_session for update;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  v_total := jsonb_array_length(s.question_ids);

  if s.status = 'ended' then
    raise exception 'session already ended';
  elsif s.status in ('lobby', 'reveal') then
    if s.current_index + 1 >= v_total then
      update public.live_sessions
         set status = 'ended', ended_at = now(), question_started_at = null
       where id = p_session;
      perform app.finalize_live_session_scoring(p_session);
      return jsonb_build_object('status', 'ended');
    end if;
    update public.live_sessions
       set status = 'question', current_index = s.current_index + 1,
           question_started_at = now()
     where id = p_session;
    return jsonb_build_object('status', 'question',
                              'index', s.current_index + 1,
                              'total', v_total);
  else -- 'question'
    update public.live_sessions
       set status = 'reveal', question_started_at = null
     where id = p_session;
    return jsonb_build_object('status', 'reveal', 'index', s.current_index,
                              'total', v_total);
  end if;
end;
$$;

create or replace function public.end_live_session(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(v_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  update public.live_sessions
     set status = 'ended', ended_at = coalesce(ended_at, now()),
         question_started_at = null
   where id = p_session;
  perform app.finalize_live_session_scoring(p_session);
end;
$$;
