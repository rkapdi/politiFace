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

  -- Overview: below the 5-student k-anonymity floor, activity stats are
  -- withheld (null) and only the student count reports.
  perform 1 from public.cohort_overview(v_cohort)
    where students is not null and answers_total is null
      and active_7d is null and mocks_completed is null;
  if not found then raise exception 'FAIL: cohort_overview floor not applied'; end if;

  -- With the floor lowered (one student answered), stats appear...
  select count(*) into n from public.cohort_domain_stats(v_cohort, 1);
  -- p_min_n is clamped server-side to 5; a 1-student cohort gets nothing
  -- even when the caller asks for a floor of 1.
  if n <> 0 then
    raise exception 'FAIL: min_n clamp bypassed, got % rows', n;
  end if;

  -- ...but at the default floor of 5 students, NOTHING renders.
  select count(*) into n from public.cohort_domain_stats(v_cohort);
  if n <> 0 then
    raise exception 'FAIL: min-n floor leaked stats for a tiny cohort';
  end if;

  -- Top misses: the clamp holds here too; a 1-student cohort exposes no
  -- per-question rows even when the caller requests a floor of 1.
  select count(*) into n from public.cohort_top_misses(v_cohort, 1, 10);
  if n <> 0 then
    raise exception 'FAIL: top-misses min_n clamp bypassed, got % rows', n;
  end if;
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

-- Cross-class rollup: one row per taught cohort, floored below 5 students.
do $$
declare n int := 0; r record;
begin
  for r in select * from public.my_faculty_overview() loop
    n := n + 1;
    if r.students < 5 and r.answers_total is not null then
      raise exception 'FAIL: rollup leaked stats below the floor';
    end if;
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

reset role;
select 'SMOKE TEST PASSED' as result;
