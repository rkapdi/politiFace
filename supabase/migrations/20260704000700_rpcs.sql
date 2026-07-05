-- The trust boundary: SECURITY DEFINER RPCs own everything a client must not
-- be trusted with. Grading, FSRS state, mock assembly and scoring, cohort
-- joining, code redemption, and faculty question authoring (which touches the
-- protected answer-key table).

-- One graded answer per question per mock attempt.
create unique index events_attempt_question_uidx
  on public.events (attempt_id, question_id)
  where type = 'answer' and attempt_id is not null;

-- ── join_cohort ─────────────────────────────────────────────────────────────
create function public.join_cohort(p_code text) returns uuid
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_cohort uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select id into v_cohort from public.cohorts where join_code = upper(trim(p_code));
  if v_cohort is null then raise exception 'invalid join code'; end if;
  insert into public.cohort_members (cohort_id, user_id, role)
  values (v_cohort, auth.uid(), 'student')
  on conflict (cohort_id, user_id) do nothing;
  return v_cohort;
end;
$$;

-- ── submit_answer ───────────────────────────────────────────────────────────
-- Idempotent on event_id: flaky-wifi retries return the original grading.
create function public.submit_answer(
  p_event_id    uuid,
  p_question_id uuid,
  p_chosen_key  text,
  p_client_ts   timestamptz,
  p_device_id   text default null,
  p_attempt_id  uuid default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_q record;
  v_key record;
  v_cohort uuid;
  v_correct boolean;
  v_existing record;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  -- Idempotent replay: return the stored grading.
  select e.correct, e.question_id into v_existing
    from public.events e where e.event_id = p_event_id;
  if found then
    select k.answer_key, k.explanation into v_key
      from app.question_keys k where k.question_id = v_existing.question_id;
    return jsonb_build_object(
      'correct', v_existing.correct,
      'answer_key', v_key.answer_key,
      'explanation', v_key.explanation,
      'replay', true);
  end if;

  select q.id, q.domain_id, q.cohort_id, q.review_status into v_q
    from public.questions q where q.id = p_question_id;
  if v_q.id is null or v_q.review_status <> 'published'
     or (v_q.cohort_id is not null and not app.is_cohort_member(v_q.cohort_id)) then
    raise exception 'question not available';
  end if;

  select k.answer_key, k.explanation into v_key
    from app.question_keys k where k.question_id = p_question_id;
  if v_key.answer_key is null then
    raise exception 'question has no answer key';
  end if;

  if p_attempt_id is not null then
    perform 1 from public.mock_attempts a
      where a.id = p_attempt_id and a.user_id = v_user
        and a.completed_at is null
        and a.question_ids @> to_jsonb(p_question_id::text);
    if not found then raise exception 'invalid or completed mock attempt'; end if;
    select a.cohort_id into v_cohort from public.mock_attempts a where a.id = p_attempt_id;
  else
    v_cohort := app.current_cohort(v_user);
  end if;

  v_correct := (p_chosen_key = v_key.answer_key);

  insert into public.events
    (event_id, user_id, cohort_id, type, question_id, attempt_id, domain_id,
     chosen_key, correct, client_ts, device_id)
  values
    (p_event_id, v_user, v_cohort, 'answer', p_question_id, p_attempt_id,
     v_q.domain_id, p_chosen_key, v_correct, p_client_ts, p_device_id);

  perform app.apply_graded_event(
    v_user, v_cohort, p_question_id, v_q.domain_id,
    case when v_correct then 2 else 0 end, v_correct, now());

  return jsonb_build_object(
    'correct', v_correct,
    'answer_key', v_key.answer_key,
    'explanation', v_key.explanation,
    'replay', false);
end;
$$;

-- ── submit_review ───────────────────────────────────────────────────────────
-- FSRS spaced-repetition review (the 4-button grade), no correctness claim.
create function public.submit_review(
  p_event_id    uuid,
  p_question_id uuid,
  p_grade       text,  -- again | hard | good | easy
  p_client_ts   timestamptz,
  p_device_id   text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_q record;
  v_grade int;
  v_cohort uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  v_grade := array_position(array['again', 'hard', 'good', 'easy'], p_grade) - 1;
  if v_grade is null then raise exception 'invalid grade %', p_grade; end if;

  if exists (select 1 from public.events where event_id = p_event_id) then
    return jsonb_build_object('replay', true);
  end if;

  select q.id, q.domain_id, q.cohort_id, q.review_status into v_q
    from public.questions q where q.id = p_question_id;
  if v_q.id is null or v_q.review_status <> 'published'
     or (v_q.cohort_id is not null and not app.is_cohort_member(v_q.cohort_id)) then
    raise exception 'question not available';
  end if;

  v_cohort := app.current_cohort(v_user);

  insert into public.events
    (event_id, user_id, cohort_id, type, question_id, domain_id,
     payload, client_ts, device_id)
  values
    (p_event_id, v_user, v_cohort, 'review', p_question_id, v_q.domain_id,
     jsonb_build_object('grade', p_grade), p_client_ts, p_device_id);

  perform app.apply_graded_event(
    v_user, v_cohort, p_question_id, v_q.domain_id, v_grade, null, now());

  return jsonb_build_object('replay', false);
end;
$$;

-- ── assemble_mock ───────────────────────────────────────────────────────────
-- Server selects 20 published system questions per domain (FCLE shape:
-- 80 questions, 4 x 20), snapshots the set, returns questions WITHOUT keys.
create function public.assemble_mock(p_kind text) returns jsonb
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
             order by q.rn)
      into picked
      from (
        select *, row_number() over () as rn
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

-- ── finalize_mock ───────────────────────────────────────────────────────────
create function public.finalize_mock(p_attempt_id uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_a public.mock_attempts%rowtype;
  v_score int;
  v_total int;
  v_per_domain jsonb;
  v_passed boolean;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  select * into v_a from public.mock_attempts
    where id = p_attempt_id and user_id = v_user;
  if v_a.id is null then raise exception 'attempt not found'; end if;

  -- Idempotent: already finalized attempts return their stored result.
  if v_a.completed_at is not null then
    return jsonb_build_object(
      'score', v_a.score, 'per_domain', v_a.per_domain,
      'passed', v_a.passed, 'replay', true);
  end if;

  v_total := jsonb_array_length(v_a.question_ids);

  select jsonb_object_agg(code, counts) into v_per_domain
    from (
      select d.code,
             jsonb_build_object(
               'correct', count(*) filter (where e.correct),
               'total', count(*)) as counts
      from public.events e
      join public.domains d on d.id = e.domain_id
      where e.attempt_id = p_attempt_id and e.type = 'answer'
      group by d.code
    ) per;

  select count(*) into v_score
    from public.events
    where attempt_id = p_attempt_id and type = 'answer' and correct;

  v_passed := v_score >= ceil(0.6 * v_total);

  update public.mock_attempts set
    completed_at = now(), score = v_score,
    per_domain = coalesce(v_per_domain, '{}'::jsonb), passed = v_passed
  where id = p_attempt_id;

  insert into public.events (event_id, user_id, cohort_id, type, attempt_id, client_ts,
                             payload)
  values (gen_random_uuid(), v_user, v_a.cohort_id, 'mock_complete', p_attempt_id,
          now(), jsonb_build_object('score', v_score, 'total', v_total));

  return jsonb_build_object(
    'score', v_score, 'per_domain', coalesce(v_per_domain, '{}'::jsonb),
    'passed', v_passed, 'replay', false);
end;
$$;

-- ── redeem_code ─────────────────────────────────────────────────────────────
create function public.redeem_code(p_code text) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_c public.redemption_codes%rowtype;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  select * into v_c from public.redemption_codes
    where code = upper(trim(p_code)) for update;
  if v_c.code is null then raise exception 'invalid code'; end if;
  if v_c.expires_at is not null and v_c.expires_at < now() then
    raise exception 'code expired';
  end if;
  if v_c.max_uses is not null and v_c.uses >= v_c.max_uses then
    raise exception 'code exhausted';
  end if;

  insert into public.entitlements (user_id, capability, source, expires_at)
  values (v_user, v_c.capability, 'institutional', v_c.expires_at)
  on conflict (user_id, capability) do update set
    expires_at = greatest(coalesce(public.entitlements.expires_at, 'epoch'::timestamptz),
                          coalesce(excluded.expires_at, 'epoch'::timestamptz));

  update public.redemption_codes set uses = uses + 1 where code = v_c.code;

  -- A cohort-tied code also joins the student to the cohort.
  if v_c.cohort_id is not null then
    insert into public.cohort_members (cohort_id, user_id, role)
    values (v_c.cohort_id, v_user, 'student')
    on conflict do nothing;
  end if;

  return jsonb_build_object('capability', v_c.capability, 'cohort_id', v_c.cohort_id);
end;
$$;

-- ── upsert_faculty_question ─────────────────────────────────────────────────
-- Faculty authoring writes both the public question row and the protected
-- key row in one transaction. Draft -> reviewed -> published with provenance.
create function public.upsert_faculty_question(
  p_question_id  uuid,       -- null to create
  p_cohort_id    uuid,
  p_domain_code  text,
  p_stem         text,
  p_options      jsonb,
  p_answer_key   text,
  p_explanation  text,
  p_citation     text,
  p_difficulty   int default 3,
  p_objective_id uuid default null,
  p_review_status text default 'draft'
) returns uuid
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_domain smallint;
  v_id uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if not app.is_cohort_faculty(p_cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  if p_review_status not in ('draft', 'reviewed', 'published') then
    raise exception 'invalid review status';
  end if;
  select id into v_domain from public.domains where code = p_domain_code;
  if v_domain is null then raise exception 'unknown domain %', p_domain_code; end if;
  if jsonb_typeof(p_options) <> 'array' or jsonb_array_length(p_options) < 2 then
    raise exception 'options must be an array of at least 2 choices';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(p_options) o where o ->> 'key' = p_answer_key
  ) then
    raise exception 'answer key must match one of the option keys';
  end if;

  if p_question_id is null then
    insert into public.questions
      (domain_id, objective_id, difficulty, stem, options, citation,
       author, review_status, cohort_id, created_by)
    values
      (v_domain, p_objective_id, p_difficulty, p_stem, p_options, p_citation,
       'faculty', 'draft', p_cohort_id, v_user)
    returning id into v_id;
  else
    select id into v_id from public.questions
      where id = p_question_id and author = 'faculty' and cohort_id = p_cohort_id;
    if v_id is null then raise exception 'question not found in this cohort'; end if;
    update public.questions set
      domain_id = v_domain, objective_id = p_objective_id,
      difficulty = p_difficulty, stem = p_stem, options = p_options,
      citation = p_citation
    where id = v_id;
  end if;

  insert into app.question_keys (question_id, answer_key, explanation)
  values (v_id, p_answer_key, p_explanation)
  on conflict (question_id) do update set
    answer_key = excluded.answer_key, explanation = excluded.explanation;

  -- Status transition last, so publishing sees the key in place.
  update public.questions set review_status = p_review_status where id = v_id;

  return v_id;
end;
$$;

-- ── grants ──────────────────────────────────────────────────────────────────
revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.join_cohort(text),
  public.submit_answer(uuid, uuid, text, timestamptz, text, uuid),
  public.submit_review(uuid, uuid, text, timestamptz, text),
  public.assemble_mock(text),
  public.finalize_mock(uuid),
  public.redeem_code(text),
  public.upsert_faculty_question(uuid, uuid, text, text, jsonb, text, text, text, int, uuid, text)
to authenticated;
