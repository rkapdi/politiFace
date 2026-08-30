-- Politiface Phase 0 schema smoke test.
-- Exercises the full student/faculty lifecycle through the RPCs, then the
-- RLS boundaries from each role. Every check raises on failure.
\set ON_ERROR_STOP on
\set QUIET on

-- Fixed identities.
\set f_uid  '''00000000-0000-0000-0000-00000000000f'''
\set s1_uid '''00000000-0000-0000-0000-000000000001'''
\set s2_uid '''00000000-0000-0000-0000-000000000002'''

insert into auth.users (id, email) values
  (:f_uid,  'purcell@example.edu'),
  (:s1_uid, 's1@example.edu'),
  (:s2_uid, 's2@example.edu');

-- ── Seed content (as service/CI: table owner bypasses RLS) ─────────────────
insert into public.content_versions (version, git_sha) values ('test-1', 'deadbeef');

do $$
declare
  d record; i int; qid uuid;
begin
  for d in select id from public.domains loop
    for i in 1..25 loop
      insert into public.questions (domain_id, stem, options, citation, review_status)
      values (d.id,
              format('Domain %s question %s?', d.id, i),
              '[{"key":"a","text":"A"},{"key":"b","text":"B"},{"key":"c","text":"C"},{"key":"d","text":"D"}]',
              'https://constitution.congress.gov/',
              'draft')
      returning id into qid;
      insert into app.question_keys (question_id, answer_key, explanation)
      values (qid, 'b', 'Because b.');
      update public.questions set review_status = 'published' where id = qid;
    end loop;
  end loop;
end $$;

-- ── Faculty creates profile + cohort ────────────────────────────────────────
set role authenticated;
set app.test_uid = :f_uid;

insert into public.profiles (id, handle, school)
values (:f_uid, 'prof_p', 'MDC North');
-- Mirror production grandfathering: the professor is verified faculty.
-- (app schema is owner-only; flip roles for the seed row.)
reset role;
insert into app.verified_faculty (user_id, note)
values (:f_uid, 'smoke seed') on conflict do nothing;
set role authenticated;
set app.test_uid = :f_uid;
insert into public.cohorts (name, term, created_by)
values ('POS2041 Fall', '2026F', :f_uid);

select join_code as code from public.cohorts limit 1 \gset

do $$
begin
  if not exists (select 1 from public.cohort_members
                 where user_id = auth.uid() and role = 'faculty') then
    raise exception 'FAIL: creator did not become faculty';
  end if;
end $$;

-- ── Student 1 joins ─────────────────────────────────────────────────────────
set app.test_uid = :s1_uid;
insert into public.profiles (id, handle) values (:s1_uid, 'student_one');
select public.join_cohort(:'code') as joined \gset

-- ── Practice answers: grading, FSRS, streaks, leaderboard, readiness ────────
do $$
declare
  q1 uuid; q2 uuid; res jsonb; st record;
begin
  select id into q1 from public.questions where stem like 'Domain 1 question 1?%';
  select id into q2 from public.questions where stem like 'Domain 1 question 2?%';

  -- Correct answer.
  res := public.submit_answer(gen_random_uuid(), q1, 'b', now());
  if not (res ->> 'correct')::boolean then raise exception 'FAIL: b should be correct'; end if;
  if res ->> 'explanation' <> 'Because b.' then raise exception 'FAIL: no explanation'; end if;

  -- Wrong answer.
  res := public.submit_answer(gen_random_uuid(), q2, 'a', now());
  if (res ->> 'correct')::boolean then raise exception 'FAIL: a should be wrong'; end if;
  if res ->> 'answer_key' <> 'b' then raise exception 'FAIL: key not returned'; end if;

  -- Read models moved.
  select * into st from public.item_states where question_id = q1 and user_id = auth.uid();
  if st.reps <> 1 or st.stability is null then raise exception 'FAIL: item_states q1'; end if;
  select * into st from public.item_states where question_id = q2 and user_id = auth.uid();
  if st.lapses <> 1 then raise exception 'FAIL: lapse not recorded'; end if;

  if (select current from public.streaks where user_id = auth.uid()) <> 1 then
    raise exception 'FAIL: streak';
  end if;
  if (select score from public.leaderboard where user_id = auth.uid()) <> 1 then
    raise exception 'FAIL: leaderboard should be 1 (one correct)';
  end if;
  if abs((select accuracy from public.user_domain_readiness
          where user_id = auth.uid() and domain_id = 1) - 0.5) > 1e-6 then
    raise exception 'FAIL: readiness accuracy should be 0.5';
  end if;
end $$;

-- Idempotency: same event_id replays, nothing double-counts.
do $$
declare
  q3 uuid; eid uuid := gen_random_uuid(); res jsonb; before int; after int;
begin
  select id into q3 from public.questions where stem like 'Domain 1 question 3?%';
  res := public.submit_answer(eid, q3, 'b', now());
  select score into before from public.leaderboard where user_id = auth.uid();
  res := public.submit_answer(eid, q3, 'b', now());
  if not (res ->> 'replay')::boolean then raise exception 'FAIL: replay flag'; end if;
  select score into after from public.leaderboard where user_id = auth.uid();
  if before <> after then raise exception 'FAIL: replay double-counted'; end if;
end $$;

-- FSRS review path.
do $$
declare
  q1 uuid; res jsonb; st record; s0 real;
begin
  select id into q1 from public.questions where stem like 'Domain 1 question 1?%';
  select stability into s0 from public.item_states
    where question_id = q1 and user_id = auth.uid();
  res := public.submit_review(gen_random_uuid(), q1, 'good', now());
  select * into st from public.item_states where question_id = q1 and user_id = auth.uid();
  if st.reps <> 2 then raise exception 'FAIL: review did not bump reps'; end if;
  if st.stability <= 0 then raise exception 'FAIL: stability broken'; end if;
end $$;

-- ── Mock lifecycle: assemble, answer all 80, finalize ───────────────────────
do $$
declare
  mock jsonb; attempt uuid; q jsonb; i int := 0; res jsonb; fin jsonb;
begin
  mock := public.assemble_mock('baseline');
  attempt := (mock ->> 'attempt_id')::uuid;
  if jsonb_array_length(mock -> 'questions') <> 80 then
    raise exception 'FAIL: mock should have 80 questions, got %',
      jsonb_array_length(mock -> 'questions');
  end if;
  if mock -> 'questions' -> 0 ? 'answer_key' then
    raise exception 'FAIL: mock leaked answer keys';
  end if;

  -- Answer: first 56 correct, rest wrong -> 56/80, pass (needs 48).
  for q in select * from jsonb_array_elements(mock -> 'questions') loop
    i := i + 1;
    res := public.submit_answer(
      gen_random_uuid(), (q ->> 'id')::uuid,
      case when i <= 56 then 'b' else 'a' end, now(), null, attempt);
  end loop;

  fin := public.finalize_mock(attempt);
  if (fin ->> 'score')::int <> 56 then
    raise exception 'FAIL: score should be 56, got %', fin ->> 'score';
  end if;
  if not (fin ->> 'passed')::boolean then raise exception 'FAIL: 56/80 passes'; end if;
  if (fin -> 'per_domain' -> 'american_democracy' ->> 'total')::int <> 20 then
    raise exception 'FAIL: per_domain totals wrong: %', fin -> 'per_domain';
  end if;

  -- Finalize is idempotent.
  fin := public.finalize_mock(attempt);
  if not (fin ->> 'replay')::boolean then raise exception 'FAIL: finalize replay'; end if;

  -- Double-answering a mock question is blocked by the unique index.
  begin
    res := public.submit_answer(
      gen_random_uuid(), (mock -> 'questions' -> 0 ->> 'id')::uuid, 'b',
      now(), null, attempt);
    raise exception 'FAIL: completed attempt accepted another answer';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;  -- expected rejection
  end;
end $$;

-- ── RLS boundaries ──────────────────────────────────────────────────────────
-- Student cannot touch the protected key table.
do $$
begin
  begin
    perform * from app.question_keys limit 1;
    raise exception 'FAIL: student read app.question_keys';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Events are append-only: update is not even granted.
do $$
begin
  begin
    update public.events set correct = true where user_id = auth.uid();
    raise exception 'FAIL: student updated events';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Direct insert of a graded answer event is rejected by policy.
do $$
begin
  begin
    insert into public.events (event_id, user_id, type, question_id, chosen_key,
                               correct, client_ts)
    values (gen_random_uuid(), auth.uid(), 'answer',
            (select id from public.questions limit 1), 'b', true, now());
    raise exception 'FAIL: client forged a graded answer event';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Session boundary events ARE directly insertable.
insert into public.events (event_id, user_id, type, client_ts)
values (gen_random_uuid(), :s1_uid, 'session_start', now());

-- Student 2: outsider sees nothing of the cohort.
set app.test_uid = :s2_uid;
insert into public.profiles (id, handle) values (:s2_uid, 'student_two');
do $$
begin
  if exists (select 1 from public.cohorts) then
    raise exception 'FAIL: outsider sees cohort';
  end if;
  if exists (select 1 from public.events) then
    raise exception 'FAIL: outsider sees other users events';
  end if;
  if exists (select 1 from public.leaderboard) then
    raise exception 'FAIL: outsider sees leaderboard';
  end if;
  if exists (select 1 from public.item_states) then
    raise exception 'FAIL: outsider sees item states';
  end if;
end $$;

-- Student (non-faculty) cannot author questions.
set app.test_uid = :s1_uid;
do $$
declare v uuid;
begin
  begin
    v := public.upsert_faculty_question(
      null, (select cohort_id from public.cohort_members where user_id = auth.uid() limit 1),
      'us_constitution', 'Sneaky?', '[{"key":"a","text":"A"},{"key":"b","text":"B"}]',
      'a', 'No.', 'https://example.gov', 3, null, 'published');
    raise exception 'FAIL: student authored a question';
  exception when others then
    if sqlerrm not like '%not faculty%' then raise; end if;
  end;
end $$;

-- ── Faculty authoring: draft -> published, cohort-scoped visibility ─────────
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid; v_q uuid;
begin
  select cohort_id into v_cohort from public.cohort_members
    where user_id = auth.uid() and role = 'faculty' limit 1;
  v_q := public.upsert_faculty_question(
    null, v_cohort, 'us_constitution',
    'Which article establishes the judiciary?',
    '[{"key":"a","text":"Article I"},{"key":"b","text":"Article III"}]',
    'b', 'Article III vests the judicial power.',
    'https://constitution.congress.gov/constitution/article-3/',
    3, null, 'published');
  if v_q is null then raise exception 'FAIL: faculty upsert'; end if;
end $$;

-- Cohort member sees the faculty question; outsider does not.
set app.test_uid = :s1_uid;
do $$
begin
  if not exists (select 1 from public.questions where author = 'faculty') then
    raise exception 'FAIL: member cannot see faculty question';
  end if;
end $$;
set app.test_uid = :s2_uid;
do $$
begin
  if exists (select 1 from public.questions where author = 'faculty') then
    raise exception 'FAIL: outsider sees cohort question';
  end if;
end $$;

-- ── Redemption code: entitlement + auto-join ────────────────────────────────
reset role;
insert into public.redemption_codes (code, cohort_id, capability, max_uses)
select 'MDCFALL26', id, 'fcle', 100 from public.cohorts limit 1;

set role authenticated;
set app.test_uid = :s2_uid;
do $$
declare res jsonb;
begin
  res := public.redeem_code('MDCFALL26');
  if res ->> 'capability' <> 'fcle' then raise exception 'FAIL: redeem capability'; end if;
  if not exists (select 1 from public.entitlements
                 where user_id = auth.uid() and capability = 'fcle') then
    raise exception 'FAIL: entitlement not granted';
  end if;
  if not exists (select 1 from public.cohort_members where user_id = auth.uid()) then
    raise exception 'FAIL: code did not join cohort';
  end if;
end $$;

-- ── Efficacy rollup: faculty reads aggregate, student reads nothing ─────────
reset role;
select app.compute_cohort_rollup(id) from public.cohorts;

set role authenticated;
set app.test_uid = :f_uid;
do $$
declare r record;
begin
  select * into r from public.cohort_rollups order by computed_at desc limit 1;
  if r.cohort_id is null then raise exception 'FAIL: faculty cannot read rollup'; end if;
  if r.questions_answered < 80 then
    raise exception 'FAIL: rollup undercounts answers: %', r.questions_answered;
  end if;
  if (r.baseline_avg ->> 'score')::numeric <> 56.0 then
    raise exception 'FAIL: baseline avg wrong: %', r.baseline_avg;
  end if;
end $$;
set app.test_uid = :s1_uid;
do $$
begin
  if exists (select 1 from public.cohort_rollups) then
    raise exception 'FAIL: student reads rollups';
  end if;
end $$;

-- ── Anonymous read of published reference content ───────────────────────────
set role anon;
set app.test_uid = '';
do $$
begin
  if (select count(*) from public.questions) <> 100 then
    raise exception 'FAIL: anon should see exactly the 100 published system questions';
  end if;
  if (select count(*) from public.domains) <> 4 then
    raise exception 'FAIL: anon domains';
  end if;
end $$;

-- ── Faculty aggregates: weakness view + min-n floor ─────────────────────────
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid;
  v_created jsonb;
  n int;
begin
  select cohort_id into v_cohort from public.cohort_members
    where user_id = auth.uid() and role = 'faculty'
    order by joined_at asc limit 1;

  -- create_cohort RPC mints a class + join code.
  v_created := public.create_cohort('POS2041 Spring', '2027S');
  if length(v_created ->> 'join_code') <> 6 then
    raise exception 'FAIL: create_cohort join code';
  end if;

  -- Per-student-first (2026-08-26): on the default per_student policy the
  -- faculty already see individuals, so class statistics render at ANY
  -- size. Overview reports real activity even for a tiny class.
  perform 1 from public.cohort_overview(v_cohort)
    where students is not null and answers_total is not null;
  if not found then
    raise exception 'FAIL: per_student overview must report at any size';
  end if;

  -- Domain stats render for a tiny per_student cohort when asked.
  select count(*) into n from public.cohort_domain_stats(v_cohort, 1);
  if n = 0 then
    raise exception 'FAIL: per_student domain stats must render at any size';
  end if;

  -- The floor returns the moment the class goes aggregate_only: that is
  -- the one place where aggregates could be reversed into individuals.
  perform public.set_reporting_policy(v_cohort, 'aggregate_only', 'pseudonym');
  perform 1 from public.cohort_overview(v_cohort)
    where students is not null and answers_total is null
      and active_7d is null and mocks_completed is null;
  if not found then
    raise exception 'FAIL: aggregate_only keeps the small-class floor';
  end if;
  select count(*) into n from public.cohort_domain_stats(v_cohort, 1);
  if n <> 0 then
    raise exception 'FAIL: aggregate_only min_n clamp bypassed, got % rows', n;
  end if;
  select count(*) into n from public.cohort_top_misses(v_cohort, 1, 10);
  if n <> 0 then
    raise exception 'FAIL: aggregate_only top-misses clamp bypassed';
  end if;
  perform public.set_reporting_policy(v_cohort, 'per_student', 'roster');
end $$;

-- Students cannot call the faculty aggregates.
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.cohort_members
    where user_id = auth.uid() limit 1;
  begin
    perform * from public.cohort_domain_stats(v_cohort, 1);
    raise exception 'FAIL: student read cohort stats';
  exception when others then
    if sqlerrm not like '%not faculty%' then raise; end if;
  end;
end $$;

-- ── Cohort attribution is scoped to STUDENT membership (regression) ─────────
-- Guards migration 20260710000100_cohort_attribution_student_scope.sql:
--   1. A student's graded activity is tagged to the cohort they joined as a
--      student (s1 joined exactly one class).
--   2. A faculty member's own practice is NOT attributed to the class they
--      teach -- it stays untagged (cohort_id null) so it can't pollute that
--      class's efficacy rollups.
set app.test_uid = :s1_uid;
do $$
declare v_student_cohort uuid; n_bad int;
begin
  select cohort_id into v_student_cohort from public.cohort_members
    where user_id = auth.uid() and role = 'student';
  -- Every graded answer event s1 produced must carry that student cohort.
  select count(*) into n_bad from public.events
    where user_id = auth.uid() and type = 'answer'
      and cohort_id is distinct from v_student_cohort;
  if n_bad <> 0 then
    raise exception 'FAIL: % student answer events not tagged to the student cohort', n_bad;
  end if;
  -- And the mock attempt itself.
  if exists (select 1 from public.mock_attempts
             where user_id = auth.uid()
               and cohort_id is distinct from v_student_cohort) then
    raise exception 'FAIL: mock_attempt not tagged to the student cohort';
  end if;
end $$;

set app.test_uid = :f_uid;
do $$
declare eid uuid := gen_random_uuid(); qid uuid; c uuid;
begin
  -- Faculty answers a published SYSTEM question (author is not 'faculty').
  select id into qid from public.questions
    where author is distinct from 'faculty' and stem like 'Domain 2 question 7?%';
  perform public.submit_answer(eid, qid, 'b', now());
  select cohort_id into c from public.events where event_id = eid;
  if c is not null then
    raise exception 'FAIL: faculty activity attributed to cohort % (must be null)', c;
  end if;
end $$;

-- ── Objective-level readiness (Tier 2, user_objective_readiness) ────────────
-- A question tagged to an objective feeds a per-objective rolling accuracy,
-- mirroring domain readiness one level deeper. Seed as owner (bypasses RLS),
-- then answer as the student and assert the derived accuracy.
reset role;
do $$
declare v_obj uuid; qa uuid; qb uuid;
begin
  insert into public.objectives (domain_id, code, description)
  values (1, 'test_obj_rolling', 'Objective readiness regression')
  returning id into v_obj;

  insert into public.questions (domain_id, objective_id, stem, options, citation, review_status)
  values (1, v_obj, 'Objective readiness A?',
          '[{"key":"a","text":"A"},{"key":"b","text":"B"}]',
          'https://constitution.congress.gov/', 'draft') returning id into qa;
  insert into app.question_keys (question_id, answer_key, explanation) values (qa, 'b', 'Because b.');
  update public.questions set review_status = 'published' where id = qa;

  insert into public.questions (domain_id, objective_id, stem, options, citation, review_status)
  values (1, v_obj, 'Objective readiness B?',
          '[{"key":"a","text":"A"},{"key":"b","text":"B"}]',
          'https://constitution.congress.gov/', 'draft') returning id into qb;
  insert into app.question_keys (question_id, answer_key, explanation) values (qb, 'b', 'Because b.');
  update public.questions set review_status = 'published' where id = qb;
end $$;

set role authenticated;
set app.test_uid = :s1_uid;
do $$
declare qa uuid; qb uuid; obj uuid; acc real; res jsonb;
begin
  select id, objective_id into qa, obj from public.questions where stem = 'Objective readiness A?';
  select id into qb from public.questions where stem = 'Objective readiness B?';

  res := public.submit_answer(gen_random_uuid(), qa, 'b', now());  -- correct
  res := public.submit_answer(gen_random_uuid(), qb, 'a', now());  -- wrong

  select accuracy into acc from public.user_objective_readiness
    where user_id = auth.uid() and objective_id = obj;
  if acc is null then
    raise exception 'FAIL: objective readiness row not written';
  end if;
  if abs(acc - 0.5) > 1e-6 then
    raise exception 'FAIL: objective accuracy should be 0.5 (1 of 2 correct), got %', acc;
  end if;
end $$;

-- An outsider cannot read another user's objective readiness.
set app.test_uid = :s2_uid;
do $$
begin
  if exists (select 1 from public.user_objective_readiness) then
    raise exception 'FAIL: outsider sees objective readiness';
  end if;
end $$;


-- ── Cross-device state: own-rows only (regression for 20260721000100) ───────
set app.test_uid = :s1_uid;
do $$
begin
  insert into public.card_states (user_id, card_id, stability, difficulty, reps, last_reviewed_at)
  values (auth.uid(), 'us-pres-washington', 3.2, 5.1, 4, now());
  insert into public.card_states (user_id, card_id, stability, difficulty, reps, last_reviewed_at)
  values (auth.uid(), 'us-pres-washington', 4.0, 5.0, 5, now())
  on conflict (user_id, card_id) do update
    set stability = excluded.stability, reps = excluded.reps,
        last_reviewed_at = excluded.last_reviewed_at, updated_at = now();
  if (select reps from public.card_states
      where user_id = auth.uid() and card_id = 'us-pres-washington') <> 5 then
    raise exception 'FAIL: card_states upsert did not apply';
  end if;
  insert into public.user_app_state (user_id, chapter_number, day_in_chapter, xp, deck_subscriptions)
  values (auth.uid(), 3, 2, 480, '{"us-delegation-fl": true}'::jsonb)
  on conflict (user_id) do update set xp = excluded.xp, updated_at = now();
end $$;

set app.test_uid = :s2_uid;
do $$
declare n int;
begin
  select count(*) into n from public.card_states;
  if n <> 0 then raise exception 'FAIL: outsider sees % card_states rows', n; end if;
  select count(*) into n from public.user_app_state;
  if n <> 0 then raise exception 'FAIL: outsider sees % user_app_state rows', n; end if;
  begin
    insert into public.card_states (user_id, card_id) values (gen_random_uuid(), 'evil');
    raise exception 'FAIL: outsider wrote another user''s card state';
  exception when insufficient_privilege or check_violation then null;
  end;
end $$;


-- ── Audit hardening regressions (20260722000100) ────────────────────────────
set app.test_uid = :s1_uid;
do $$
declare q1 uuid; s_before int; s_after int;
begin
  -- Leaderboard first-correct dedupe: re-answering an already-correct
  -- question with a fresh event id must not add another point.
  select id into q1 from public.questions where stem like 'Domain 1 question 1?%';
  select score into s_before from public.leaderboard where user_id = auth.uid();
  perform public.submit_answer(gen_random_uuid(), q1, 'b', now());
  select score into s_after from public.leaderboard where user_id = auth.uid();
  if s_after <> s_before then
    raise exception 'FAIL: repeat correct answer farmed the leaderboard (% -> %)', s_before, s_after;
  end if;
end $$;

-- Forged-cohort session events are rejected: s1 may not tag events with a
-- cohort they are not a student member of. Create the foreign cohort as
-- owner with a fixed id so the student block needs no RLS-blocked lookup.
reset role;
do $$
begin
  insert into public.cohorts (id, org_id, name, join_code)
  select '00000000-0000-4000-8000-00000000f0e1'::uuid, id,
         'Not My Class', 'ZZZZQ1'
  from public.orgs limit 1;
end $$;
set role authenticated;
set app.test_uid = :s1_uid;
do $$
begin
  begin
    insert into public.events (event_id, user_id, cohort_id, type, client_ts)
    values (gen_random_uuid(), auth.uid(),
            '00000000-0000-4000-8000-00000000f0e1'::uuid,
            'session_start', now());
    raise exception 'FAIL: forged-cohort session event accepted';
  exception when insufficient_privilege or check_violation then null;
  end;
end $$;


-- ── Live sessions: full lifecycle (20260723000100) ──────────────────────────
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid; q1 uuid; q2 uuid; qc uuid; v_sess jsonb; v_id uuid;
  v_state jsonb; v_q jsonb; v_rev jsonb;
begin
  select cohort_id into v_cohort from public.cohort_members
   where user_id = auth.uid() and role = 'faculty' limit 1;

  -- Faculty authors a cohort question, immediately session-ready.
  qc := public.create_cohort_question(
    v_cohort, 1::smallint, 'Instructor question: which branch makes laws?',
    '[{"key":"a","text":"Legislative"},{"key":"b","text":"Executive"}]'::jsonb,
    'a', 'Article I.', null);

  select id into q1 from public.questions where stem like 'Domain 1 question 1?%';
  select id into q2 from public.questions where stem like 'Domain 1 question 2?%';

  v_sess := public.create_live_session(
    v_cohort, 'Smoke session',
    jsonb_build_array(q1::text, q2::text, qc::text), 10);
  v_id := (v_sess ->> 'id')::uuid;
  if (v_sess ->> 'question_count')::int <> 3 then
    raise exception 'FAIL: session question count';
  end if;

  -- lobby -> question 0
  v_state := public.advance_live_session(v_id);
  if v_state ->> 'status' <> 'question' or (v_state ->> 'index')::int <> 0 then
    raise exception 'FAIL: advance to first question, got %', v_state;
  end if;
  perform set_config('app.smoke_session', v_id::text, false);
  perform set_config('app.smoke_q1', q1::text, false);
end $$;

-- Student answers while the question is open.
set app.test_uid = :s1_uid;
do $$
declare v_id uuid; q1 uuid; v_q jsonb; v_res jsonb;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  q1 := current_setting('app.smoke_q1')::uuid;
  v_q := public.get_live_question(v_id);
  if v_q ->> 'status' <> 'question' then
    raise exception 'FAIL: student should see an open question';
  end if;
  if (v_q -> 'question') ? 'answer_key' then
    raise exception 'FAIL: live question leaked a key field';
  end if;
  v_res := public.submit_live_answer(v_id, q1, 'b');  -- correct per seed
  if not (v_res ->> 'accepted')::boolean then
    raise exception 'FAIL: answer not accepted';
  end if;
  -- Second answer is silently ignored (first is final). Students no
  -- longer have direct SELECT on live_answers; the dedupe is asserted as
  -- owner just below.
  perform public.submit_live_answer(v_id, q1, 'a');
  -- Students cannot drive the session.
  begin
    perform public.advance_live_session(v_id);
    raise exception 'FAIL: student advanced the session';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  -- Standings are hidden while the question is open.
  begin
    perform * from public.live_scoreboard(v_id);
    raise exception 'FAIL: standings visible mid-question';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Owner-role check: the double-submit stored exactly one answer.
reset role;
do $$
declare v_id uuid; q1 uuid; n int;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  q1 := current_setting('app.smoke_q1')::uuid;
  select count(*) into n from public.live_answers
   where session_id = v_id and question_id = q1;
  if n <> 1 then raise exception 'FAIL: duplicate live answer stored (%)', n; end if;
end $$;
set role authenticated;
set app.test_uid = :s1_uid;

-- Reveal, standings, wrap-up.
set app.test_uid = :f_uid;
do $$
declare
  v_id uuid; v_state jsonb; v_rev jsonb; r record; n int := 0;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  v_state := public.advance_live_session(v_id);  -- question -> reveal
  if v_state ->> 'status' <> 'reveal' then
    raise exception 'FAIL: expected reveal, got %', v_state;
  end if;
  v_rev := public.live_reveal(v_id);
  if v_rev ->> 'correct_key' is null then
    raise exception 'FAIL: reveal missing correct key';
  end if;
  for r in select * from public.live_scoreboard(v_id) loop
    n := n + 1;
    if r.rank = 1 and (r.score < 100 or r.correct_count <> 1) then
      raise exception 'FAIL: leader score wrong: % / %', r.score, r.correct_count;
    end if;
  end loop;
  if n < 1 then raise exception 'FAIL: empty scoreboard after reveal'; end if;

  -- reveal -> q2 -> reveal -> q3 -> reveal -> ended
  perform public.advance_live_session(v_id);
  perform public.advance_live_session(v_id);
  perform public.advance_live_session(v_id);
  perform public.advance_live_session(v_id);
  v_state := public.advance_live_session(v_id);
  if v_state ->> 'status' <> 'ended' then
    raise exception 'FAIL: session should have ended, got %', v_state;
  end if;
  if (select count(*) from public.live_session_stats(v_id)) <> 3 then
    raise exception 'FAIL: wrap-up stats question count';
  end if;
end $$;

-- A true outsider (s2 was auto-joined by the redemption test earlier)
-- can neither see nor join the session.
reset role;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000003', 's3@example.edu')
  on conflict do nothing;
set role authenticated;
set app.test_uid = '00000000-0000-0000-0000-000000000003';
insert into public.profiles (id, handle)
  values ('00000000-0000-0000-0000-000000000003', 'outsider_three')
  on conflict do nothing;
do $$
declare v_id uuid;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  if exists (select 1 from public.live_sessions where id = v_id) then
    raise exception 'FAIL: outsider sees the live session row';
  end if;
  begin
    perform public.get_live_question(v_id);
    raise exception 'FAIL: outsider fetched a live question';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;


-- ── Roster identity + faculty gating + presence (20260723000200) ────────────
-- s1 sets a roster name; only faculty see it in reports.
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.cohort_members
   where user_id = auth.uid() and role = 'student' limit 1;
  perform public.set_roster_name(v_cohort, 'Jordan Alvarez');
end $$;

-- Presence: joining the smoke session recorded participants, and the
-- identified report resolves the roster name for faculty.
set app.test_uid = :f_uid;
do $$
declare v_id uuid; r record; found_name boolean := false;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  perform public.enter_live_session(v_id);
exception when others then
  null; -- session is ended by now; presence came from live answers below
end $$;
do $$
declare v_id uuid; r record; found_name boolean := false;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  for r in select * from public.live_session_report(v_id) loop
    if r.roster_name = 'Jordan Alvarez' then found_name := true; end if;
  end loop;
  if not found_name then
    raise exception 'FAIL: session report missing roster name';
  end if;
  perform 1 from public.cohort_student_progress(
    (select cohort_id from public.live_sessions where id = v_id))
    where roster_name = 'Jordan Alvarez' and answers_total >= 0;
  if not found then
    raise exception 'FAIL: student progress missing roster row';
  end if;
end $$;

-- Students cannot call the identified views.
set app.test_uid = :s1_uid;
do $$
declare v_id uuid;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  begin
    perform * from public.live_session_report(v_id);
    raise exception 'FAIL: student read the identified session report';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform * from public.cohort_student_progress(
      (select cohort_id from public.cohort_members
        where user_id = auth.uid() limit 1));
    raise exception 'FAIL: student read identified progress';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Faculty gating: the fresh outsider cannot create a cohort, then can
-- after redeeming an invite minted by grandfathered faculty.
set app.test_uid = :f_uid;
do $$
begin
  perform set_config('app.smoke_invite', public.mint_faculty_invite('smoke'), false);
end $$;
set app.test_uid = '00000000-0000-0000-0000-000000000003';
do $$
declare res jsonb;
begin
  begin
    res := public.create_cohort('Sneaky Class', null);
    raise exception 'FAIL: unverified user created a cohort';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  perform public.redeem_faculty_invite(current_setting('app.smoke_invite'));
  res := public.create_cohort('New Faculty Class', '2026F');
  if res ->> 'join_code' is null then
    raise exception 'FAIL: verified faculty could not create a cohort';
  end if;
  begin
    perform public.redeem_faculty_invite(current_setting('app.smoke_invite'));
    raise exception 'FAIL: exhausted invite redeemed twice';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;


-- ── Admin, history, rollups, live scoring (20260724000100) ──────────────────
reset role;
insert into app.admins (user_id, note)
values (:f_uid, 'smoke admin') on conflict do nothing;
set role authenticated;

-- Live scoring fold: the smoke session ended earlier (advance now calls the
-- finalizer). s1 answered q1 correctly live, but had ALREADY answered that
-- question correctly in practice, so the fold must create the event and
-- award nothing (first-correct-ever dedupe holds across contexts).
-- Faculty cannot read raw events (FERPA posture), so the existence check
-- runs as the student who owns the event, and counts run as owner.
set app.test_uid = :s1_uid;
do $$
declare v_id uuid; v_q uuid;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  v_q := current_setting('app.smoke_q1')::uuid;
  -- event_id is now random (griefing fix), so match by content: this
  -- student's folded answer for the first live question exists as an event.
  if not exists (
    select 1 from public.events
     where user_id = auth.uid() and question_id = v_q and type = 'answer') then
    raise exception 'FAIL: live answer did not fold into events';
  end if;
end $$;

reset role;
do $$
declare n_before int;
begin
  select count(*) into n_before from public.events;
  perform set_config('app.smoke_evcount', n_before::text, false);
end $$;
set role authenticated;
set app.test_uid = :f_uid;
do $$
begin
  perform public.end_live_session(
    current_setting('app.smoke_session')::uuid);  -- replay: idempotent
end $$;
reset role;
do $$
declare n_after int;
begin
  select count(*) into n_after from public.events;
  if n_after <> current_setting('app.smoke_evcount')::int then
    raise exception 'FAIL: replaying session end duplicated events';
  end if;
end $$;
set role authenticated;
set app.test_uid = :f_uid;

-- Session history lists the ended session with participants + accuracy.
do $$
declare v_id uuid; r record; ok boolean := false;
begin
  v_id := current_setting('app.smoke_session')::uuid;
  for r in select * from public.cohort_live_sessions(
    (select cohort_id from public.live_sessions where id = v_id)) loop
    if r.session_id = v_id and r.status = 'ended' and r.participants >= 1 then
      ok := true;
    end if;
  end loop;
  if not ok then raise exception 'FAIL: session history missing ended session'; end if;
end $$;

-- Cross-class rollup: one row per taught cohort. Per-student-first
-- (2026-08-26): per_student classes report at any size; the floor lives
-- in the aggregate_only path, asserted in its own section below.
do $$
declare n int := 0; r record;
begin
  for r in select * from public.my_faculty_overview() loop
    n := n + 1;
  end loop;
  if n < 1 then raise exception 'FAIL: faculty overview empty'; end if;
end $$;

-- Admin surfaces: work for the admin, rejected for a student.
do $$
declare v jsonb; n int;
begin
  v := public.admin_overview();
  if (v ->> 'users')::int < 3 then
    raise exception 'FAIL: admin overview user count, got %', v;
  end if;
  select count(*) into n from public.admin_list_cohorts();
  if n < 2 then raise exception 'FAIL: admin cohort list, got %', n; end if;
  select count(*) into n from public.admin_search_users('student');
  if n < 1 then raise exception 'FAIL: admin user search'; end if;
  select count(*) into n from public.admin_list_invites();
  if n < 1 then raise exception 'FAIL: admin invite list'; end if;
  select count(*) into n from public.admin_list_live_sessions();
  if n < 1 then raise exception 'FAIL: admin session list'; end if;
end $$;

set app.test_uid = :s1_uid;
do $$
begin
  begin
    perform public.admin_overview();
    raise exception 'FAIL: student read the admin overview';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  if public.am_admin() then
    raise exception 'FAIL: student claims admin';
  end if;
end $$;


-- ── Push tokens (20260724000200) ────────────────────────────────────────────
set app.test_uid = :s1_uid;
do $$
begin
  perform public.register_push_token(repeat('a', 64), 'production');
  if (select count(*) from public.push_tokens where user_id = auth.uid()) <> 1 then
    raise exception 'FAIL: token not registered';
  end if;
  -- re-register updates, does not duplicate
  perform public.register_push_token(repeat('a', 64), 'sandbox');
  if (select count(*) from public.push_tokens where user_id = auth.uid()) <> 1 then
    raise exception 'FAIL: token duplicated on re-register';
  end if;
  if (select environment from public.push_tokens where user_id = auth.uid())
     <> 'sandbox' then
    raise exception 'FAIL: environment not updated';
  end if;
  begin
    perform public.register_push_token('short', 'production');
    raise exception 'FAIL: accepted a too-short token';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

set app.test_uid = :s2_uid;
do $$
begin
  if exists (select 1 from public.push_tokens) then
    raise exception 'FAIL: outsider sees another user token';
  end if;
end $$;


-- ── Class announcements (20260724000300) ────────────────────────────────────
set app.test_uid = :f_uid;
do $$
declare v_cohort uuid; res jsonb; i int;
begin
  select cohort_id into v_cohort from public.cohort_members
   where user_id = auth.uid() and role = 'faculty' limit 1;
  res := public.send_class_announcement(v_cohort, 'Quiz Friday, bring the study guide.');
  if res ->> 'id' is null then raise exception 'FAIL: announcement not created'; end if;
  -- empty body rejected
  begin
    perform public.send_class_announcement(v_cohort, '   ');
    raise exception 'FAIL: empty announcement accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  -- hourly rate limit (5/hour): 4 more ok, 6th fails
  for i in 1..4 loop
    perform public.send_class_announcement(v_cohort, 'note ' || i);
  end loop;
  begin
    perform public.send_class_announcement(v_cohort, 'one too many');
    raise exception 'FAIL: hourly announcement limit not enforced';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- a student cannot send to their own cohort
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.cohort_members
   where user_id = auth.uid() and role = 'student' limit 1;
  begin
    perform public.send_class_announcement(v_cohort, 'i am not the teacher');
    raise exception 'FAIL: student sent a class announcement';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  -- but a member CAN read the class inbox
  if (select count(*) from public.class_announcements where cohort_id = v_cohort) < 1 then
    raise exception 'FAIL: member cannot read class announcements';
  end if;
end $$;


-- ── Audit-2 hardening (20260724000400) ──────────────────────────────────────
-- A student cannot read roster_name off the table directly (column revoke),
-- but can read their own via the RPC.
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid; v_name text;
begin
  select cohort_id into v_cohort from public.cohort_members
   where user_id = auth.uid() and role = 'student' limit 1;
  begin
    perform roster_name from public.cohort_members
     where cohort_id = v_cohort;
    raise exception 'FAIL: student read roster_name column directly';
  exception
    when insufficient_privilege then null;
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  v_name := public.my_roster_name(v_cohort);
  if v_name is null or v_name = '' then
    raise exception 'FAIL: my_roster_name returned nothing for own row';
  end if;
  -- other non-sensitive columns still selectable
  perform user_id, role from public.cohort_members where cohort_id = v_cohort;
end $$;

-- A student has no direct SELECT on live_answers at all now.
do $$
declare n int;
begin
  select count(*) into n from public.live_answers;
  if n <> 0 then
    raise exception 'FAIL: student still reads live_answers rows (got %)', n;
  end if;
end $$;

-- push token cap: registering 7 tokens leaves at most 5.
do $$
declare i int;
begin
  for i in 1..7 loop
    perform public.register_push_token('tok' || i || repeat('x', 40), 'production');
  end loop;
  if (select count(*) from public.push_tokens where user_id = auth.uid()) > 5 then
    raise exception 'FAIL: push token cap not enforced';
  end if;
end $$;


-- ── Account management (20260724000500) ─────────────────────────────────────
set app.test_uid = :s1_uid;
do $$
declare res jsonb;
begin
  res := public.update_my_profile('jordan_a', 'MDC North', 3::smallint);
  if res ->> 'handle' <> 'jordan_a' then raise exception 'FAIL: handle not updated'; end if;
  if (res ->> 'avatar_id')::int <> 3 then raise exception 'FAIL: avatar not set'; end if;
  -- bad handle rejected
  begin
    perform public.update_my_profile('no', null, null);
    raise exception 'FAIL: accepted a too-short handle';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  -- avatar out of range rejected
  begin
    perform public.update_my_profile(null, null, 99::smallint);
    raise exception 'FAIL: accepted an out-of-range avatar';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- handle collision with another user is rejected
set app.test_uid = :s2_uid;
do $$
begin
  begin
    perform public.update_my_profile('jordan_a', null, null);
    raise exception 'FAIL: duplicate handle accepted';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- account deletion cascades: create a throwaway user, give them a token +
-- membership, delete, assert everything is gone.
reset role;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000de', 'delete_me@example.edu')
  on conflict do nothing;
set role authenticated;
set app.test_uid = '00000000-0000-0000-0000-0000000000de';
insert into public.profiles (id, handle) values (auth.uid(), 'delete_me_now')
  on conflict do nothing;
do $$
begin
  perform public.register_push_token(repeat('d', 40), 'production');
  perform public.delete_my_account();
end $$;
reset role;
do $$
begin
  if exists (select 1 from public.profiles
             where id = '00000000-0000-0000-0000-0000000000de') then
    raise exception 'FAIL: profile survived account deletion';
  end if;
  if exists (select 1 from public.push_tokens
             where user_id = '00000000-0000-0000-0000-0000000000de') then
    raise exception 'FAIL: push token survived account deletion';
  end if;
  if exists (select 1 from auth.users
             where id = '00000000-0000-0000-0000-0000000000de') then
    raise exception 'FAIL: auth user survived account deletion';
  end if;
end $$;
set role authenticated;

-- ── TA role (20260821000100) ────────────────────────────────────────────────
\set ta_uid '''00000000-0000-0000-0000-0000000000a1'''
reset role;
insert into auth.users (id, email) values (:ta_uid, 'ta@example.edu');
set role authenticated;
set app.test_uid = :ta_uid;
insert into public.profiles (id, handle) values (:ta_uid, 'ta_person');

-- Faculty adds the TA by email.
set app.test_uid = :f_uid;
select public.add_cohort_ta(
  (select id from public.cohorts where name = 'POS2041 Fall'), 'ta@example.edu');

do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  if (select role from public.cohort_members
       where cohort_id = v_cohort
         and user_id = '00000000-0000-0000-0000-0000000000a1') <> 'ta' then
    raise exception 'FAIL: TA row not created';
  end if;
  if public.my_cohort_role(v_cohort) <> 'faculty' then
    raise exception 'FAIL: my_cohort_role wrong for faculty';
  end if;
end $$;

-- TA can drive a live session and read aggregates.
set app.test_uid = :ta_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  v_session jsonb;
begin
  if public.my_cohort_role(v_cohort) <> 'ta' then
    raise exception 'FAIL: my_cohort_role wrong for TA';
  end if;
  v_session := public.create_live_session(
    v_cohort, 'TA quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published'
       limit 3) q),
    20);
  perform public.advance_live_session((v_session ->> 'id')::uuid);
  perform public.end_live_session((v_session ->> 'id')::uuid);
  perform public.cohort_domain_stats(v_cohort, 1);
  perform public.cohort_overview(v_cohort);
  perform public.cohort_live_sessions(v_cohort);
  if not exists (select 1 from public.my_faculty_overview()) then
    raise exception 'FAIL: TA missing their class in my_faculty_overview';
  end if;
end $$;

-- TA is blocked from per-student surfaces, invites, and authoring.
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform * from public.cohort_student_progress(v_cohort);
    raise exception 'FAIL: TA read per-student progress';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.mint_faculty_invite('nope');
    raise exception 'FAIL: TA minted an invite';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.create_cohort_question(
      v_cohort, (select id from public.domains order by id limit 1),
      'TA question that must fail?',
      '[{"key":"a","text":"A"},{"key":"b","text":"B"}]', 'a');
    raise exception 'FAIL: TA authored a question';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Demote and confirm.
set app.test_uid = :f_uid;
select public.remove_cohort_ta(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  '00000000-0000-0000-0000-0000000000a1');
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  if (select role from public.cohort_members
       where cohort_id = v_cohort
         and user_id = '00000000-0000-0000-0000-0000000000a1') <> 'student' then
    raise exception 'FAIL: removed TA should become a student';
  end if;
end $$;

-- ── Reporting policy chokepoint (20260821000200) ────────────────────────────
set app.test_uid = :f_uid;

-- Default per_student: named rows with student_ref = user_id.
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  r record;
begin
  select * into r from public.cohort_student_progress(v_cohort) limit 1;
  if r.user_id is null or r.student_ref <> r.user_id::text then
    raise exception 'FAIL: per_student rows must carry user_id and matching ref';
  end if;
end $$;

-- Pseudonymous: stable pseudonym, no user_id, no roster name.
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'pseudonymous', 'pseudonym');
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  r record; r2 record;
begin
  select * into r from public.cohort_student_progress(v_cohort)
   order by student_ref limit 1;
  if r.user_id is not null then
    raise exception 'FAIL: pseudonymous rows must not expose user_id';
  end if;
  if r.roster_name not like 'Student %' then
    raise exception 'FAIL: pseudonymous rows must use pseudonyms, got %', r.roster_name;
  end if;
  select * into r2 from public.cohort_student_progress(v_cohort)
   order by student_ref limit 1;
  if r.student_ref <> r2.student_ref then
    raise exception 'FAIL: pseudonyms must be stable across calls';
  end if;
  if (public.get_reporting_policy(v_cohort) ->> 'effective') <> 'pseudonymous' then
    raise exception 'FAIL: get_reporting_policy effective mismatch';
  end if;
end $$;

-- Aggregate only: per-student RPCs refuse.
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'aggregate_only', 'pseudonym');
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform * from public.cohort_student_progress(v_cohort);
    raise exception 'FAIL: aggregate_only cohort returned per-student rows';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Students cannot set policy; exports are logged.
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'per_student', 'roster');
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform public.set_reporting_policy(v_cohort, 'per_student', 'roster');
    raise exception 'FAIL: student set reporting policy';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
set app.test_uid = :f_uid;
select public.log_report_export(
  (select id from public.cohorts where name = 'POS2041 Fall'), 'csv_progress');
reset role;
do $$
begin
  if (select count(*) from app.export_log) < 1 then
    raise exception 'FAIL: export was not logged';
  end if;
end $$;
set role authenticated;

-- ── Analytics RPCs (20260821000300) ─────────────────────────────────────────
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  v_trend int;
  r record;
  v_dd jsonb;
begin
  select count(*) into v_trend
    from public.cohort_engagement_trend(v_cohort, 14);
  if v_trend <> 14 then
    raise exception 'FAIL: trend must return one row per day, got %', v_trend;
  end if;

  -- With threshold 1.01 every student is at risk, so rows must come back
  -- with identity, readiness, and activity fields populated.
  select * into r from public.at_risk_students(v_cohort, 1.01) limit 1;
  if r.student_ref is null or r.display_name is null then
    raise exception 'FAIL: at_risk_students returned incomplete rows';
  end if;

  v_dd := public.student_drilldown(v_cohort, r.student_ref);
  if v_dd -> 'identity' is null or v_dd -> 'domains' is null
     or v_dd -> 'activity' is null or v_dd -> 'suggestions' is null
     or v_dd -> 'weak_objectives' is null or v_dd -> 'live_sessions' is null
     or v_dd -> 'mocks' is null then
    raise exception 'FAIL: student_drilldown missing keys: %', v_dd;
  end if;
end $$;

-- Policy applies: pseudonymous refs resolve, aggregate_only refuses.
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'pseudonymous', 'pseudonym');
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  r record;
  v_dd jsonb;
begin
  select * into r from public.at_risk_students(v_cohort, 1.01) limit 1;
  if r.student_ref not like 'Student %' then
    raise exception 'FAIL: pseudonymous at-risk rows must use pseudonyms';
  end if;
  v_dd := public.student_drilldown(v_cohort, r.student_ref);
  if v_dd -> 'identity' ->> 'display_name' <> r.student_ref then
    raise exception 'FAIL: drilldown must resolve pseudonym refs';
  end if;
end $$;
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'aggregate_only', 'pseudonym');
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform * from public.at_risk_students(v_cohort, 1.01);
    raise exception 'FAIL: aggregate_only cohort listed at-risk students';
  exception when others then if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
select public.set_reporting_policy(
  (select id from public.cohorts where name = 'POS2041 Fall'),
  'per_student', 'roster');

-- ── Guest live join (20260821000400) ────────────────────────────────────────
-- A guest (anonymous auth) joins by code, answers, appears on the
-- scoreboard by display name, and is excluded from cohort analytics.
\set g_uid '''00000000-0000-0000-0000-0000000000b1'''
reset role;
insert into auth.users (id, email) values (:g_uid, null);
set role authenticated;

set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  v_session jsonb;
begin
  v_session := public.create_live_session(
    v_cohort, 'Guest-joinable quiz',
    (select jsonb_agg(id) from (select id from public.questions
       where cohort_id is null and review_status = 'published'
       limit 2) q), 20);
  perform set_config('app.test_session', v_session ->> 'id', false);
  perform set_config('app.test_join_code', v_session ->> 'join_code', false);
  perform public.advance_live_session((v_session ->> 'id')::uuid);
end $$;

set app.test_uid = :g_uid;
do $$
declare
  v_join jsonb;
  v_session uuid := current_setting('app.test_session')::uuid;
  v_q jsonb;
begin
  v_join := public.join_live_session_guest(
    current_setting('app.test_join_code'), 'Alex R');
  if (v_join ->> 'id')::uuid <> v_session then
    raise exception 'FAIL: guest join returned wrong session';
  end if;
  v_q := public.get_live_question(v_session);
  perform public.submit_live_answer(
    v_session, (v_q -> 'question' ->> 'id')::uuid, 'b');
end $$;

-- Guest is on the scoreboard by display name (faculty view during question).
set app.test_uid = :f_uid;
do $$
declare v_session uuid := current_setting('app.test_session')::uuid;
begin
  if not exists (select 1 from public.live_scoreboard(v_session)
                  where handle = 'Alex R') then
    raise exception 'FAIL: guest missing from scoreboard by display name';
  end if;
  perform public.advance_live_session(v_session); -- reveal
  perform public.advance_live_session(v_session); -- question 2
  perform public.advance_live_session(v_session); -- reveal
  perform public.advance_live_session(v_session); -- ended + finalize
end $$;

-- Finalize must NOT have folded the guest into cohort events/leaderboard.
reset role;
do $$
begin
  if exists (select 1 from public.events
              where user_id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'FAIL: guest answers leaked into cohort events';
  end if;
  if exists (select 1 from public.leaderboard
              where user_id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'FAIL: guest leaked into leaderboard';
  end if;
end $$;

-- Purge removes stale guest data.
update public.live_participants set joined_at = now() - interval '60 days'
 where is_guest;
update public.live_answers a set created_at = now() - interval '60 days'
  from public.live_participants lp
 where lp.session_id = a.session_id and lp.user_id = a.user_id and lp.is_guest;
select app.purge_live_guest_data();
do $$
begin
  if exists (select 1 from public.live_participants where is_guest) then
    raise exception 'FAIL: purge left guest participants behind';
  end if;
  if exists (select 1 from public.profiles
              where id = '00000000-0000-0000-0000-0000000000b1') then
    raise exception 'FAIL: purge left the guest profile behind';
  end if;
end $$;
set role authenticated;

-- ── Readiness v2: shrunk, windowed, versioned (20260824000100) ─────────────
reset role;
do $$
declare
  r record;
  v_rows int := 0;
begin
  if length(app.readiness_model_version()) < 3 then
    raise exception 'FAIL: readiness model version missing';
  end if;
  -- s1 has real graded history from earlier sections. Shrinkage bounds:
  -- readiness always in (0,1) and NEVER 1.0 even at perfect raw accuracy.
  for r in select * from app.readiness_v2('00000000-0000-0000-0000-000000000001') loop
    v_rows := v_rows + 1;
    if r.readiness <= 0.0 or r.readiness >= 0.95 then
      raise exception 'FAIL: readiness % out of shrunk bounds', r.readiness;
    end if;
    if r.answers > 0 and r.correct = r.answers and r.readiness >= 1.0 then
      raise exception 'FAIL: perfect raw accuracy must still shrink';
    end if;
  end loop;
  if v_rows <> 4 then
    raise exception 'FAIL: readiness_v2 must return one row per domain, got %', v_rows;
  end if;
  -- A student with no evidence sits at the 0.40 prior exactly.
  if exists (select 1 from app.readiness_v2('00000000-0000-0000-0000-0000000000a1')
              where abs(readiness - 0.40) > 0.01) then
    raise exception 'FAIL: zero-evidence readiness must equal the prior';
  end if;
end $$;

-- The at-risk list reads v2: the evidence-free student shows ~0.40 overall.
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  r record;
begin
  select * into r from public.at_risk_students(v_cohort, 1.01)
   where student_ref = '00000000-0000-0000-0000-0000000000a1';
  if r.student_ref is null then
    raise exception 'FAIL: evidence-free student missing from at-risk list';
  end if;
  if abs(r.overall_readiness - 0.40) > 0.01 then
    raise exception 'FAIL: evidence-free overall readiness was %', r.overall_readiness;
  end if;
  if r.weakest_domain_name is null then
    raise exception 'FAIL: weakest domain must always resolve under v2';
  end if;
end $$;

-- ── Canary, baselines, demo quarantine (20260824000200) ─────────────────────
reset role;

-- Canary passes on a clean database.
do $$
declare v_failures jsonb;
begin
  perform app.run_measurement_canary();
  select failures into v_failures from app.canary_runs
   order by id desc limit 1;
  if (select ok from app.canary_runs order by id desc limit 1) is not true then
    raise exception 'FAIL: canary must pass on a clean db: %', v_failures;
  end if;
end $$;

-- Canary catches a tampered grading row, then passes again after revert.
do $$
declare
  v_event uuid;
begin
  select event_id into v_event from public.events
   where type = 'answer' and correct is not null
   order by server_ts asc limit 1;
  update public.events set correct = not correct where event_id = v_event;
  perform app.run_measurement_canary();
  if (select ok from app.canary_runs order by id desc limit 1) then
    raise exception 'FAIL: canary missed a tampered grading row';
  end if;
  update public.events set correct = not correct where event_id = v_event;
  perform app.run_measurement_canary();
  if not (select ok from app.canary_runs order by id desc limit 1) then
    raise exception 'FAIL: canary must recover after revert';
  end if;
end $$;

-- Baselines refuse below the 5-student floor.
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform app.capture_cohort_baseline(v_cohort);
    raise exception 'FAIL: baseline captured below the 5-student floor';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- With 5 students the baseline captures, aggregate-only.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@example.edu'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@example.edu');
insert into public.profiles (id, handle) values
  ('00000000-0000-0000-0000-0000000000c1', 'extra_one'),
  ('00000000-0000-0000-0000-0000000000c2', 'extra_two');
insert into public.cohort_members (cohort_id, user_id, role)
select c.id, u.uid, 'student'
  from public.cohorts c,
       (values ('00000000-0000-0000-0000-0000000000c1'::uuid),
               ('00000000-0000-0000-0000-0000000000c2'::uuid)) u(uid)
 where c.name = 'POS2041 Fall';
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  b record;
begin
  perform app.capture_cohort_baseline(v_cohort);
  select * into b from app.cohort_baselines where cohort_id = v_cohort;
  if b.cohort_id is null then raise exception 'FAIL: baseline missing'; end if;
  if b.students < 5 then raise exception 'FAIL: baseline student count wrong'; end if;
  if b.distribution::text ~ '[0-9a-f]{8}-[0-9a-f]{4}' then
    raise exception 'FAIL: baseline must not contain student identifiers';
  end if;
  -- Idempotent: a second capture must not overwrite the first.
  perform app.capture_cohort_baseline(v_cohort);
  if (select count(*) from app.cohort_baselines where cohort_id = v_cohort) <> 1 then
    raise exception 'FAIL: baseline must capture exactly once';
  end if;
end $$;

-- Students cannot trigger captures through the RPC.
set role authenticated;
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform public.capture_cohort_baseline(v_cohort);
    raise exception 'FAIL: student captured a baseline';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
reset role;

-- Demo cohorts produce no rollups and no baselines.
do $$
declare
  v_demo uuid;
begin
  insert into public.cohorts (name, term, created_by, is_demo)
  values ('DEMO smoke cohort', 'DEMO', '00000000-0000-0000-0000-00000000000f', true)
  returning id into v_demo;
  perform app.compute_all_cohort_rollups();
  if exists (select 1 from public.cohort_rollups where cohort_id = v_demo) then
    raise exception 'FAIL: demo cohort leaked into rollups';
  end if;
  perform app.capture_due_baselines();
  if exists (select 1 from app.cohort_baselines where cohort_id = v_demo) then
    raise exception 'FAIL: demo cohort leaked into baselines';
  end if;
  begin
    perform app.capture_cohort_baseline(v_demo);
    raise exception 'FAIL: manual baseline captured for a demo cohort';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;
set role authenticated;

-- ── Class pulse + distribution (20260826000100) ─────────────────────────────
-- POS2041 Fall has exactly 5 students by this point (s1, s2, the demoted
-- TA, c1, c2), so it clears the k-anonymity floor.
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  v_pulse jsonb;
  v_dist jsonb;
  v_sum int;
begin
  v_pulse := public.cohort_pulse(v_cohort);
  if coalesce((v_pulse ->> 'below_floor')::boolean, false) then
    raise exception 'FAIL: pulse below floor at 5 students';
  end if;
  if (v_pulse ->> 'students')::int <> 5 then
    raise exception 'FAIL: pulse students wrong: %', v_pulse ->> 'students';
  end if;
  if length(v_pulse ->> 'sentence') < 20 then
    raise exception 'FAIL: pulse sentence missing';
  end if;
  if jsonb_typeof(v_pulse -> 'cards') <> 'array'
     or jsonb_array_length(v_pulse -> 'cards') > 3 then
    raise exception 'FAIL: pulse cards must be an array of at most 3';
  end if;
  if v_pulse ->> 'sentence' like '%—%' then
    raise exception 'FAIL: no em-dashes in pulse copy';
  end if;

  v_dist := public.cohort_distribution(v_cohort);
  if (v_dist ->> 'pass_line')::int <> 48 then
    raise exception 'FAIL: distribution pass line missing';
  end if;
  select coalesce(sum(value::int), 0) into v_sum
    from jsonb_each_text(v_dist -> 'bins');
  if v_sum <> 5 then
    raise exception 'FAIL: distribution bins must sum to students, got %', v_sum;
  end if;
end $$;

-- Students are blocked from both.
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform public.cohort_pulse(v_cohort);
    raise exception 'FAIL: student read the class pulse';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.cohort_distribution(v_cohort);
    raise exception 'FAIL: student read the distribution';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- Below the 5-student floor both answer honestly instead of leaking.
set app.test_uid = :f_uid;
do $$
declare
  v_tiny uuid;
  v_pulse jsonb;
begin
  v_tiny := (public.create_cohort('Tiny pulse class') ->> 'id')::uuid;
  v_pulse := public.cohort_pulse(v_tiny);
  if not (v_pulse ->> 'below_floor')::boolean then
    raise exception 'FAIL: pulse must report below_floor under 5 students';
  end if;
  if length(v_pulse ->> 'sentence') < 10 then
    raise exception 'FAIL: below-floor pulse still needs a sentence';
  end if;
  if not (public.cohort_distribution(v_tiny) ->> 'below_floor')::boolean then
    raise exception 'FAIL: distribution must report below_floor under 5 students';
  end if;
end $$;

-- ── Per-student first: no floors for per_student classes (20260826000200) ───
-- A 2-student class with the default per_student policy gets full
-- statistics; the floor only applies where aggregates are the ONLY view
-- (aggregate_only policy, TAs).
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_tiny uuid;
  v_pulse jsonb;
begin
  v_tiny := (public.create_cohort('Coaching pair') ->> 'id')::uuid;
  perform set_config('app.test_tiny', v_tiny::text, false);
end $$;
reset role;
insert into public.cohort_members (cohort_id, user_id, role)
values (current_setting('app.test_tiny')::uuid,
        '00000000-0000-0000-0000-000000000001', 'student'),
       (current_setting('app.test_tiny')::uuid,
        '00000000-0000-0000-0000-000000000002', 'student');
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_tiny uuid := current_setting('app.test_tiny')::uuid;
  v_pulse jsonb;
begin
  v_pulse := public.cohort_pulse(v_tiny);
  if coalesce((v_pulse ->> 'below_floor')::boolean, false) then
    raise exception 'FAIL: per_student class must get a pulse at any size';
  end if;
  if (v_pulse ->> 'students')::int <> 2 then
    raise exception 'FAIL: tiny pulse students wrong';
  end if;
  if coalesce((public.cohort_distribution(v_tiny) ->> 'below_floor')::boolean, false) then
    raise exception 'FAIL: per_student class must get a distribution at any size';
  end if;
  -- Aggregate RPCs answer too (rows may be empty; they must not refuse).
  perform public.cohort_overview(v_tiny);
  perform public.cohort_domain_stats(v_tiny, 1);
  -- Flip to aggregate_only: the floor comes back, because aggregates are
  -- now the only view and must not leak individuals.
  perform public.set_reporting_policy(v_tiny, 'aggregate_only', 'pseudonym');
  if not (public.cohort_pulse(v_tiny) ->> 'below_floor')::boolean then
    raise exception 'FAIL: aggregate_only keeps the small-class floor';
  end if;
end $$;

-- ── Student trend + one-click assignment (20260826000300) ───────────────────
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
  v_t jsonb;
  v_res jsonb;
  v_input uuid;
begin
  -- Trend: 8 weekly points, each with a projected score; pass line named.
  v_t := public.student_trend(v_cohort, '00000000-0000-0000-0000-000000000001');
  if jsonb_typeof(v_t -> 'weeks') <> 'array'
     or jsonb_array_length(v_t -> 'weeks') <> 8 then
    raise exception 'FAIL: trend must return 8 weekly points, got %', v_t;
  end if;
  if (v_t -> 'weeks' -> 7 ->> 'projected') is null then
    raise exception 'FAIL: latest trend week missing a projection';
  end if;
  if (v_t ->> 'pass_line')::int <> 48 then
    raise exception 'FAIL: trend pass line missing';
  end if;

  -- Assignment: one call creates the measured practice set, opens the
  -- immediate phase as an async assessment TODAY, and announces it.
  v_res := public.assign_domain_practice(
    v_cohort, (select id from public.domains order by id limit 1), 10);
  v_input := (v_res ->> 'input_id')::uuid;
  if v_input is null then
    raise exception 'FAIL: assignment returned no input id';
  end if;
  if (select count(*) from public.assessments where input_id = v_input) <> 3 then
    raise exception 'FAIL: assignment must create all three assessment phases';
  end if;
  perform 1 from public.assessments a
   where a.input_id = v_input and a.phase = 'immediate'
     and a.mode = 'async' and a.opens_at <= now() and a.closes_at > now();
  if not found then
    raise exception 'FAIL: assignment immediate phase must be open async now';
  end if;
  if not exists (select 1 from public.class_announcements
                  where cohort_id = v_cohort
                    and body like 'New practice assigned%') then
    raise exception 'FAIL: assignment must announce itself to the class';
  end if;
end $$;

-- Students are blocked from both.
set app.test_uid = :s1_uid;
do $$
declare v_cohort uuid := (select id from public.cohorts where name = 'POS2041 Fall');
begin
  begin
    perform public.student_trend(v_cohort, '00000000-0000-0000-0000-000000000002');
    raise exception 'FAIL: student read another student trend';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.assign_domain_practice(
      v_cohort, (select id from public.domains order by id limit 1), 10);
    raise exception 'FAIL: student assigned practice';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

-- ── Classes dashboard honors per-student-first too (20260826000400) ─────────
set role authenticated;
set app.test_uid = :f_uid;
do $$
declare
  v_tiny uuid := current_setting('app.test_tiny')::uuid;
  r record;
begin
  perform public.set_reporting_policy(v_tiny, 'per_student', 'roster');
  select * into r from public.my_faculty_overview() o
   where o.cohort_id = v_tiny;
  if r.cohort_id is null then
    raise exception 'FAIL: tiny cohort missing from faculty overview';
  end if;
  if r.answers_total is null then
    raise exception 'FAIL: per_student class card must report stats at any size';
  end if;
  -- aggregate_only flips the card back to withheld.
  perform public.set_reporting_policy(v_tiny, 'aggregate_only', 'pseudonym');
  select * into r from public.my_faculty_overview() o
   where o.cohort_id = v_tiny;
  if r.answers_total is not null then
    raise exception 'FAIL: aggregate_only card must withhold small-class stats';
  end if;
  perform public.set_reporting_policy(v_tiny, 'per_student', 'roster');
end $$;

-- ── Washington watch: watermark RPCs + poller-alive canary (20260829000100) ─
reset role;
do $$
declare r jsonb;
begin
  -- First poll ever baselines silently: no push, watermarks written.
  r := public.washington_advance(
    14420, '2026-08-28', 'HR 1:2026-08-27', 'wh-guid-1', 'First action');
  if not (r ->> 'first_run')::boolean or (r ->> 'changed')::boolean then
    raise exception 'FAIL: first poll must baseline silently: %', r;
  end if;
  if (select last_wh from app.push_signal where id) <> 'wh-guid-1' then
    raise exception 'FAIL: baseline must persist the WH watermark';
  end if;

  -- Same values again: quiet.
  r := public.washington_advance(
    14420, '2026-08-28', 'HR 1:2026-08-27', 'wh-guid-1', 'First action');
  if (r ->> 'changed')::boolean then
    raise exception 'FAIL: unchanged poll must stay quiet: %', r;
  end if;

  -- New White House action: changed AND wh_new.
  r := public.washington_advance(
    14420, '2026-08-28', 'HR 1:2026-08-27', 'wh-guid-2', 'Lake America EO');
  if not (r ->> 'changed')::boolean or not (r ->> 'wh_new')::boolean then
    raise exception 'FAIL: new WH action must flag wh_new: %', r;
  end if;

  -- New EO number only: changed but NOT wh_new.
  r := public.washington_advance(
    14421, '2026-08-28', 'HR 1:2026-08-27', 'wh-guid-2', null);
  if not (r ->> 'changed')::boolean or (r ->> 'wh_new')::boolean then
    raise exception 'FAIL: EO bump must not flag wh_new: %', r;
  end if;

  -- Upstream hiccup (nulls) never regresses watermarks or fires.
  r := public.washington_advance(null, null, null, null, null);
  if (r ->> 'changed')::boolean then
    raise exception 'FAIL: null poll must stay quiet: %', r;
  end if;
  if (select last_eo_number from app.push_signal where id) <> 14421 then
    raise exception 'FAIL: null poll must preserve watermarks';
  end if;

  -- Push log records fan-outs.
  perform public.washington_log_push('washington_alert', 'Lake America EO', 6);
  if not exists (select 1 from app.push_log
                  where category = 'washington_alert'
                    and title = 'Lake America EO' and sent = 6) then
    raise exception 'FAIL: push log row missing';
  end if;
end $$;

-- The canary now watches the poller: a stale heartbeat is an alarm.
do $$
declare v jsonb;
begin
  update app.push_signal set updated_at = now() - interval '3 hours' where id;
  perform app.run_measurement_canary();
  select failures into v from app.canary_runs order by id desc limit 1;
  if (select ok from app.canary_runs order by id desc limit 1)
     or v::text not like '%push_poller_alive%' then
    raise exception 'FAIL: canary must flag a stale push poller: %', v;
  end if;
  update app.push_signal set updated_at = now() where id;
  perform app.run_measurement_canary();
  if not (select ok from app.canary_runs order by id desc limit 1) then
    raise exception 'FAIL: canary must recover once the poller is fresh';
  end if;
end $$;

-- Clients can never touch the watermark machinery.
set role authenticated;
set app.test_uid = :s1_uid;
do $$
begin
  begin
    perform public.washington_advance(null, null, null, null, null);
    raise exception 'FAIL: client called washington_advance';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  begin
    perform public.washington_log_push('washington_alert', 'x', 1);
    raise exception 'FAIL: client wrote the push log';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
end $$;

reset role;
select 'SMOKE TEST PASSED' as result;
