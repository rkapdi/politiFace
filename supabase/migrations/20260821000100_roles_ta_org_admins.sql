-- TA role and org admins.
--
-- TA: a per-cohort helper who can run live sessions and read aggregate
-- analytics, but never per-student data, invites, or question authoring.
-- Org admins: the multi-campus seam (department or institution level
-- rollups later). Table and predicate only for now; no surfaces.
--
-- Gate widenings below recreate existing functions verbatim, changing only
-- app.is_cohort_faculty -> app.is_cohort_ta_or_above where a TA is allowed.
-- Faculty-only stays faculty-only: live_session_report,
-- cohort_student_progress, add_co_faculty, mint_faculty_invite,
-- create_cohort, create_cohort_question, retire_cohort_question,
-- create_teaching_input, send_class_announcement, and every RLS policy.

-- ── role column gains 'ta' ──────────────────────────────────────────────────
alter table public.cohort_members drop constraint cohort_members_role_check;
alter table public.cohort_members add constraint cohort_members_role_check
  check (role in ('student', 'faculty', 'ta'));

-- ── org admins ──────────────────────────────────────────────────────────────
create table app.org_admins (
  org_id     uuid not null references public.orgs (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create function app.is_org_admin(p_org uuid) returns boolean
language sql stable security definer set search_path = public, app, pg_temp as $$
  select exists (select 1 from app.org_admins
    where org_id = p_org and user_id = auth.uid());
$$;

-- ── predicates ──────────────────────────────────────────────────────────────
create function app.is_cohort_ta_or_above(p_cohort uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = p_cohort and user_id = auth.uid()
      and role in ('faculty', 'ta')
  );
$$;

-- The web app asks once per class instead of inferring from errors.
create function public.my_cohort_role(p_cohort uuid) returns text
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.cohort_members
   where cohort_id = p_cohort and user_id = auth.uid();
$$;
revoke all on function public.my_cohort_role(uuid) from public, anon;
grant execute on function public.my_cohort_role(uuid) to authenticated;

-- ── add / remove TA ─────────────────────────────────────────────────────────
-- Mirrors add_co_faculty (20260729000100): caller must be faculty OF THIS
-- cohort; target looked up by exact email. A TA needs no faculty invite.
-- Never demotes an existing faculty member.
create function public.add_cohort_ta(p_cohort uuid, p_email text)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_caller uuid := auth.uid();
  v_target uuid;
begin
  if v_caller is null then raise exception 'not authenticated'; end if;
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = v_caller and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can add TAs';
  end if;
  select u.id into v_target
    from auth.users u
   where lower(u.email) = lower(trim(p_email));
  if v_target is null then
    raise exception 'no Politiface account uses that email';
  end if;
  if not exists (select 1 from public.profiles where id = v_target) then
    raise exception 'that account has not finished setup yet';
  end if;
  insert into public.cohort_members (cohort_id, user_id, role)
  values (p_cohort, v_target, 'ta')
  on conflict (cohort_id, user_id) do update set role = 'ta'
    where public.cohort_members.role = 'student';
end;
$$;
revoke all on function public.add_cohort_ta(uuid, text) from public, anon;
grant execute on function public.add_cohort_ta(uuid, text) to authenticated;

create function public.remove_cohort_ta(p_cohort uuid, p_user uuid)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can remove TAs';
  end if;
  update public.cohort_members set role = 'student'
   where cohort_id = p_cohort and user_id = p_user and role = 'ta';
  if not found then raise exception 'no TA with that id in this class'; end if;
end;
$$;
revoke all on function public.remove_cohort_ta(uuid, uuid) from public, anon;
grant execute on function public.remove_cohort_ta(uuid, uuid) to authenticated;

-- ── gate widenings: session driving ─────────────────────────────────────────

-- From 20260723000100:85; gate only.
create or replace function public.create_live_session(
  p_cohort uuid,
  p_title text,
  p_question_ids jsonb,
  p_question_seconds int default 20
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_code text;
  v_count int;
  v_valid int;
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  v_count := jsonb_array_length(p_question_ids);
  if v_count is null or v_count < 1 or v_count > 50 then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  -- Every question must be published and either from the system bank or
  -- authored for THIS cohort.
  select count(*) into v_valid
    from jsonb_array_elements_text(p_question_ids) qid
    join public.questions q on q.id = qid::uuid
   where q.review_status = 'published'
     and (q.cohort_id is null or q.cohort_id = p_cohort);
  if v_valid <> v_count then
    raise exception 'question list contains unknown, unpublished, or foreign-cohort questions';
  end if;

  insert into public.live_sessions
    (cohort_id, created_by, title, question_ids, question_seconds)
  values
    (p_cohort, auth.uid(), trim(p_title), p_question_ids, p_question_seconds)
  returning id, join_code into v_id, v_code;

  return jsonb_build_object('id', v_id, 'join_code', v_code,
                            'question_count', v_count);
end;
$$;

-- From 20260724000100:291; gate only.
create or replace function public.advance_live_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_total int;
begin
  select * into s from public.live_sessions where id = p_session for update;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_ta_or_above(s.cohort_id) then
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

-- From 20260724000100:331; gate only.
create or replace function public.end_live_session(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_ta_or_above(v_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  update public.live_sessions
     set status = 'ended', ended_at = coalesce(ended_at, now()),
         question_started_at = null
   where id = p_session;
  perform app.finalize_live_session_scoring(p_session);
end;
$$;

-- From 20260723000100:362; gate only.
create or replace function public.live_session_stats(p_session uuid)
returns table (question_id uuid, stem text, answered bigint, correct_rate real)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select q.id, q.stem, count(a.user_id) as answered,
           coalesce(avg(a.correct::int), 0)::real as correct_rate
      from jsonb_array_elements_text(s.question_ids) with ordinality ids(qid, ord)
      join public.questions q on q.id = ids.qid::uuid
      left join public.live_answers a
        on a.session_id = p_session and a.question_id = q.id
     group by q.id, q.stem, ids.ord
     order by coalesce(avg(a.correct::int), 1) asc, ids.ord;
end;
$$;

-- From 20260724000100:171; gate only.
create or replace function public.cohort_live_sessions(p_cohort uuid)
returns table (
  session_id uuid, title text, status text, questions int,
  participants bigint, avg_correct real,
  created_at timestamptz, ended_at timestamptz
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
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

-- From 20260723000100:296; the "faculty may look any time" clause widens.
create or replace function public.live_reveal(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_q uuid;
  v_key text;
  v_counts jsonb;
  v_expl text;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status <> 'reveal' and not app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'not in reveal';
  end if;
  v_q := (s.question_ids ->> s.current_index)::uuid;
  select answer_key, explanation into v_key, v_expl
    from app.question_keys where question_id = v_q;
  select coalesce(jsonb_object_agg(chosen_key, n), '{}'::jsonb) into v_counts
    from (select chosen_key, count(*) as n from public.live_answers
           where session_id = p_session and question_id = v_q
           group by chosen_key) c;
  return jsonb_build_object('question_id', v_q, 'correct_key', v_key,
                            'explanation', v_expl, 'counts', v_counts);
end;
$$;

-- From 20260723000100:327; the faculty-anytime clause widens.
create or replace function public.live_scoreboard(p_session uuid)
returns table (rank bigint, handle text, score bigint, correct_count bigint, is_me boolean)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status = 'question' and not app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'standings arrive at the reveal';
  end if;
  return query
    select row_number() over (order by t.score desc, t.total_ms asc) as rank,
           p.handle, t.score, t.correct_count,
           (t.user_id = auth.uid()) as is_me
      from (
        select a.user_id,
               sum(case when a.correct then
                     100 + round(50.0 * (1 - a.answer_ms::numeric
                           / (s.question_seconds * 1000)))
                   else 0 end)::bigint as score,
               count(*) filter (where a.correct) as correct_count,
               sum(a.answer_ms)::bigint as total_ms
          from public.live_answers a
         where a.session_id = p_session
         group by a.user_id) t
      join public.profiles p on p.id = t.user_id
     order by t.score desc, t.total_ms asc
     limit 50;
end;
$$;

-- ── gate widenings: aggregate analytics ─────────────────────────────────────

-- From 20260722000100:75; gate only.
create or replace function public.cohort_overview(p_cohort uuid)
returns table (
  students        int,
  active_7d       int,
  answers_total   int,
  mocks_completed int
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  -- k-anonymity floor: below 5 students, activity stats do not exist.
  if (select count(*) from public.cohort_members m
        where m.cohort_id = p_cohort and m.role = 'student') < 5 then
    return query select
      (select count(*)::int from public.cohort_members m
        where m.cohort_id = p_cohort and m.role = 'student'),
      null::int, null::int, null::int;
    return;
  end if;
  return query select
    (select count(*)::int from public.cohort_members m
      where m.cohort_id = p_cohort and m.role = 'student'),
    (select count(distinct e.user_id)::int from public.events e
      where e.cohort_id = p_cohort and e.server_ts > now() - interval '7 days'),
    (select count(*)::int from public.events e
      where e.cohort_id = p_cohort and e.type = 'answer'
        and e.correct is not null),
    (select count(*)::int from public.mock_attempts a
      where a.cohort_id = p_cohort and a.completed_at is not null);
end;
$$;

-- From 20260722000100:109; gate only.
create or replace function public.cohort_domain_stats(p_cohort uuid, p_min_n int default 5)
returns table (
  domain_code text,
  domain_name text,
  students    int,
  answers     int,
  accuracy    real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select d.code,
           d.name,
           count(distinct e.user_id)::int,
           count(*)::int,
           avg(e.correct::int)::real
    from public.events e
    join public.domains d on d.id = e.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by d.code, d.name, d.ordinal
    having count(distinct e.user_id) >= greatest(p_min_n, 5)
    order by d.ordinal;
end;
$$;

-- From 20260722000100:139; gate only.
create or replace function public.cohort_top_misses(
  p_cohort uuid,
  p_min_n  int default 5,
  p_limit  int default 10
)
returns table (
  question_id uuid,
  stem        text,
  domain_code text,
  students    int,
  attempts    int,
  miss_rate   real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select q.id,
           q.stem,
           d.code,
           count(distinct e.user_id)::int,
           count(*)::int,
           (1.0 - avg(e.correct::int))::real
    from public.events e
    join public.questions q on q.id = e.question_id
    join public.domains d on d.id = q.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by q.id, q.stem, d.code
    having count(distinct e.user_id) >= greatest(p_min_n, 5)
       and avg(e.correct::int) < 1.0
    order by (1.0 - avg(e.correct::int)) desc, count(*) desc
    limit greatest(p_limit, 1);
end;
$$;

-- From 20260724000100:205; the caller's TA classes are included too.
create or replace function public.my_faculty_overview()
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
     where app.is_cohort_ta_or_above(c.id)
     order by c.created_at desc;
end;
$$;
