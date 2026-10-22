-- Audit hardening (2026-07-22 deep audit, verified findings).
--
-- 1. assemble_mock: the row_number() over () ordering did not preserve the
--    random() shuffle, so with exactly 20 published questions per domain
--    every mock was the identical 80 questions in ingest order for every
--    student and retake. jsonb_agg now orders by random() directly.
-- 2. cohort_overview: enforce the k-anonymity floor the migration header
--    and the faculty page always promised. Fewer than 5 students returns
--    the student count and null activity stats.
-- 3. cohort_domain_stats / cohort_top_misses: p_min_n is caller-supplied;
--    clamp to >= 5 server-side so the floor cannot be disabled from the
--    browser console.
-- 4. events insert policy: cohort_id must be null or a cohort the caller
--    is a STUDENT member of, so efficacy aggregates cannot be salted with
--    forged session events.
-- 5. apply_graded_event: leaderboard +1 only for the first correct answer
--    to a question ever (repeat answers of a revealed question scored
--    nothing toward class rank). Verbatim copy of the 20260710000200
--    definition otherwise; run the drift check before applying to prod.

create or replace function public.assemble_mock(p_kind text) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_cohort uuid;
  v_attempt uuid;
  v_ids jsonb := '[]'::jsonb;
  v_questions jsonb := '[]'::jsonb;
  d record;
  picked jsonb;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('baseline', 'practice', 'final') then
    raise exception 'invalid mock kind %', p_kind;
  end if;
  v_cohort := app.current_cohort(v_user);

  for d in select id, code from public.domains order by ordinal loop
    select jsonb_agg(jsonb_build_object(
             'id', q.id, 'domain', d.code, 'stem', q.stem,
             'options', q.options, 'citation', q.citation)
             order by random())
      into picked
      from (
        select *
        from public.questions
        where domain_id = d.id and cohort_id is null
          and review_status = 'published'
        order by random()
        limit 20
      ) q;
    if picked is null or jsonb_array_length(picked) < 20 then
      raise exception 'question bank too small for domain % (need 20)', d.code;
    end if;
    v_questions := v_questions || picked;
    select v_ids || coalesce(jsonb_agg(el -> 'id'), '[]'::jsonb)
      into v_ids from jsonb_array_elements(picked) el;
  end loop;

  insert into public.mock_attempts
    (user_id, cohort_id, kind, question_ids,
     content_version_id)
  values
    (v_user, v_cohort, p_kind, v_ids,
     (select id from public.content_versions order by published_at desc limit 1))
  returning id into v_attempt;

  insert into public.events (event_id, user_id, cohort_id, type, attempt_id, client_ts)
  values (gen_random_uuid(), v_user, v_cohort, 'mock_start', v_attempt, now());

  return jsonb_build_object('attempt_id', v_attempt, 'questions', v_questions);
end;
$$;

create or replace function public.cohort_overview(p_cohort uuid)
returns table (
  students        int,
  active_7d       int,
  answers_total   int,
  mocks_completed int
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_faculty(p_cohort) then
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
  if not app.is_cohort_faculty(p_cohort) then
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
  if not app.is_cohort_faculty(p_cohort) then
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

-- 4. Forged-cohort session events.
drop policy events_insert_session on public.events;
create policy events_insert_session on public.events for insert
  to authenticated with check (
    user_id = auth.uid()
    and type in ('session_start', 'session_end')
    and correct is null
    and chosen_key is null
    and question_id is null
    and (cohort_id is null or exists (
      select 1 from public.cohort_members m
        where m.user_id = auth.uid()
          and m.cohort_id = public.events.cohort_id
          and m.role = 'student'))
  );

create or replace function app.apply_graded_event(
  p_user     uuid,
  p_cohort   uuid,
  p_question uuid,
  p_domain   smallint,
  p_grade    int,          -- FSRS grade; answers map correct->2 (good), wrong->0 (again)
  p_correct  boolean,      -- null for pure FSRS reviews
  p_when     timestamptz
) returns void
language plpgsql as $$
declare
  st public.item_states%rowtype;
  f record;
  elapsed double precision;
  acc real;
  v_obj uuid;             -- ADDED: answered question's objective (may be null)
begin
  -- FSRS state.
  select * into st from public.item_states
    where user_id = p_user and question_id = p_question;
  if found then
    elapsed := greatest(0.0,
      extract(epoch from (p_when - st.last_reviewed_at)) / 86400.0);
    select * into f from app.fsrs_schedule(st.stability, st.difficulty, elapsed, p_grade);
    update public.item_states set
      stability        = f.stability,
      difficulty       = f.difficulty,
      due_at           = p_when + make_interval(days => f.interval_days),
      last_reviewed_at = p_when,
      reps             = st.reps + 1,
      lapses           = st.lapses + (p_grade = 0)::int
    where user_id = p_user and question_id = p_question;
  else
    select * into f from app.fsrs_schedule(null, null, 0, p_grade);
    insert into public.item_states
      (user_id, question_id, stability, difficulty, due_at, last_reviewed_at,
       reps, lapses)
    values
      (p_user, p_question, f.stability, f.difficulty,
       p_when + make_interval(days => f.interval_days), p_when,
       1, (p_grade = 0)::int);
  end if;

  -- Streak (calendar day from the client's clock; lenient by design).
  insert into public.streaks (user_id, current, longest, last_active_date)
  values (p_user, 1, 1, p_when::date)
  on conflict (user_id) do update set
    current = case
      when public.streaks.last_active_date = excluded.last_active_date
        then public.streaks.current
      when public.streaks.last_active_date = excluded.last_active_date - 1
        then public.streaks.current + 1
      else 1
    end,
    longest = greatest(public.streaks.longest, case
      when public.streaks.last_active_date = excluded.last_active_date
        then public.streaks.current
      when public.streaks.last_active_date = excluded.last_active_date - 1
        then public.streaks.current + 1
      else 1
    end),
    last_active_date = excluded.last_active_date;

  if p_correct is not null then
    -- Leaderboard: +1 for the FIRST correct answer to a question, ever.
    -- Repeat-answering an already-revealed question earns nothing, so class
    -- rank measures coverage, not grinding. The current event is already in
    -- public.events when this runs, so first-correct means count = 1.
    if p_cohort is not null and p_correct then
      if (select count(*) from public.events e
            where e.user_id = p_user and e.question_id = p_question
              and e.type = 'answer' and e.correct) = 1 then
        insert into public.leaderboard (cohort_id, user_id, score, updated_at)
        values (p_cohort, p_user, 1, now())
        on conflict (cohort_id, user_id) do update set
          score = public.leaderboard.score + 1, updated_at = now();
      end if;
    end if;

    -- Domain readiness: rolling accuracy over the last 50 graded answers.
    if p_domain is not null then
      select avg(correct::int)::real into acc from (
        select correct from public.events
        where user_id = p_user and domain_id = p_domain
          and type = 'answer' and correct is not null
        order by server_ts desc limit 50
      ) recent;
      insert into public.user_domain_readiness
        (user_id, cohort_id, domain_id, accuracy, readiness, updated_at)
      values (p_user, p_cohort, p_domain, acc, acc, now())
      on conflict (user_id, domain_id) do update set
        cohort_id = excluded.cohort_id,
        accuracy = excluded.accuracy,
        readiness = excluded.readiness,
        updated_at = now();
    end if;

    -- ── ADDED: Objective readiness ──────────────────────────────────────────
    -- Same rolling-50 shape as domain readiness, but scoped to the answered
    -- question's objective. Only fires for questions tagged with an objective;
    -- objective_id is server-derived from public.questions, never client input.
    select q.objective_id into v_obj
      from public.questions q where q.id = p_question;
    if v_obj is not null then
      select avg(correct::int)::real into acc from (
        select e.correct as correct
        from public.events e
        join public.questions q on q.id = e.question_id
        where q.objective_id = v_obj
          and e.user_id = p_user and e.type = 'answer' and e.correct is not null
        order by e.server_ts desc limit 50
      ) recent;
      insert into public.user_objective_readiness
        (user_id, cohort_id, objective_id, accuracy, readiness, updated_at)
      values (p_user, p_cohort, v_obj, acc, acc, now())
      on conflict (user_id, objective_id) do update set
        cohort_id = excluded.cohort_id,
        accuracy = excluded.accuracy,
        readiness = excluded.readiness,
        updated_at = now();
    end if;
  end if;
end;
$$;
