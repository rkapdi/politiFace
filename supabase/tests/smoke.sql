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

reset role;
select 'SMOKE TEST PASSED' as result;
