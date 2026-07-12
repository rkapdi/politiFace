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

  -- Overview counts the mock activity.
  perform 1 from public.cohort_overview(v_cohort)
    where answers_total >= 80 and mocks_completed >= 1;
  if not found then raise exception 'FAIL: cohort_overview counts'; end if;

  -- With the floor lowered (one student answered), stats appear...
  select count(*) into n from public.cohort_domain_stats(v_cohort, 1);
  if n <> 4 then
    raise exception 'FAIL: domain stats should cover 4 domains, got %', n;
  end if;

  -- ...but at the default floor of 5 students, NOTHING renders.
  select count(*) into n from public.cohort_domain_stats(v_cohort);
  if n <> 0 then
    raise exception 'FAIL: min-n floor leaked stats for a tiny cohort';
  end if;

  -- Top misses: the student answered 24 mock questions wrong.
  select count(*) into n from public.cohort_top_misses(v_cohort, 1, 10);
  if n < 1 then raise exception 'FAIL: no top misses returned'; end if;
  perform 1 from public.cohort_top_misses(v_cohort, 1, 10)
    where miss_rate <= 0 or stem is null;
  if found then raise exception 'FAIL: bad top-miss row'; end if;
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

reset role;
select 'SMOKE TEST PASSED' as result;
