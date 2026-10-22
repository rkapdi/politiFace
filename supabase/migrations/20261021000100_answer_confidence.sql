-- Answer confidence: how sure the student said they were (Guess, Pretty
-- sure, Certain) on FCLE practice, mock and live answers.
--
-- Why a column and not events.payload: payload is free-form jsonb that no
-- grading RPC writes, and live_answers has no payload at all. A typed,
-- nullable column with a check constraint keeps the event log honest
-- (one allowed vocabulary, queryable without jsonb casts) and costs
-- nothing for the rows that predate it.
--
-- Hard rules this migration keeps:
--   * Confidence is METADATA. It never touches grading, FSRS scheduling
--     (apply_graded_event still receives the correctness-only grade),
--     readiness, mock scoring, or efficacy. Nothing in this file reads it.
--   * App Store builds already in the field (1.3.2) do not send it. Each
--     RPC gains exactly one trailing parameter with a default, and the old
--     signature is dropped first, so there is one function per name (no
--     ambiguous overload) and the old named-argument calls still resolve.
--   * A bad value is dropped to null, never an error: a graded answer must
--     not be lost to a metadata typo sitting in a client outbox.
--
-- Additive only: two nullable columns; no backfill; no data rewritten.

-- ── columns ─────────────────────────────────────────────────────────────────

alter table public.events
  add column confidence text
    constraint events_confidence_check
    check (confidence in ('guess', 'pretty_sure', 'certain')),
  add constraint events_confidence_answer_only
    check (confidence is null or type = 'answer');

alter table public.live_answers
  add column confidence text
    constraint live_answers_confidence_check
    check (confidence in ('guess', 'pretty_sure', 'certain'));

-- One vocabulary, one place. Unknown or empty input becomes null.
create function app.normalize_confidence(p text) returns text
language sql immutable set search_path = pg_temp as $$
  select case when p in ('guess', 'pretty_sure', 'certain') then p end;
$$;

-- ── submit_answer gains a confidence ────────────────────────────────────────
-- Body verbatim from 20260731000100, plus p_confidence (stored, never read).
-- The FSRS grade passed to apply_graded_event is still correctness-only.

drop function public.submit_answer(uuid, uuid, text, timestamptz, text, uuid, uuid);

create function public.submit_answer(
  p_event_id      uuid,
  p_question_id   uuid,
  p_chosen_key    text,
  p_client_ts     timestamptz,
  p_device_id     text default null,
  p_attempt_id    uuid default null,
  p_assessment_id uuid default null,
  p_confidence    text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_q record;
  v_key record;
  v_cohort uuid;
  v_correct boolean;
  v_existing record;
  v_assessment record;
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

  if p_assessment_id is not null then
    -- A check answer must land inside an open assessment the caller belongs
    -- to, on a question that assessment actually snapshotted.
    select a.cohort_id, a.opens_at, a.closes_at, a.question_ids
      into v_assessment
      from public.assessments a where a.id = p_assessment_id;
    if v_assessment.cohort_id is null
       or not app.is_cohort_member(v_assessment.cohort_id)
       or now() < v_assessment.opens_at
       or now() >= v_assessment.closes_at
       or not (v_assessment.question_ids @> to_jsonb(p_question_id::text)) then
      raise exception 'assessment not open for this question';
    end if;
    v_cohort := v_assessment.cohort_id;
  elsif p_attempt_id is not null then
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
    (event_id, user_id, cohort_id, type, question_id, attempt_id,
     assessment_id, domain_id, chosen_key, correct, client_ts, device_id,
     confidence)
  values
    (p_event_id, v_user, v_cohort, 'answer', p_question_id, p_attempt_id,
     p_assessment_id, v_q.domain_id, p_chosen_key, v_correct, p_client_ts,
     p_device_id, app.normalize_confidence(p_confidence));

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

revoke execute on function
  public.submit_answer(uuid, uuid, text, timestamptz, text, uuid, uuid, text)
  from public, anon;
grant execute on function
  public.submit_answer(uuid, uuid, text, timestamptz, text, uuid, uuid, text)
  to authenticated;

-- ── submit_live_answer gains a confidence ───────────────────────────────────
-- Body verbatim from 20260928000200 (teacher refusal included), plus
-- p_confidence. Live scoring never reads it.

drop function public.submit_live_answer(uuid, uuid, text);

create function public.submit_live_answer(
  p_session    uuid,
  p_question   uuid,
  p_key        text,
  p_confidence text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_key text;
  v_ms int;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
    raise exception 'not a member of this cohort';
  end if;
  if app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'instructors watch their own sessions';
  end if;
  if s.status <> 'question'
     or (s.question_ids ->> s.current_index)::uuid <> p_question then
    raise exception 'question is not open';
  end if;
  -- Server-owned latency, with a 2s grace over the countdown.
  v_ms := (extract(epoch from (now() - s.question_started_at)) * 1000)::int;
  if v_ms > (s.question_seconds + 2) * 1000 then
    raise exception 'time is up';
  end if;
  v_ms := least(v_ms, s.question_seconds * 1000);

  select answer_key into v_key from app.question_keys
   where question_id = p_question;
  if v_key is null then raise exception 'question has no key'; end if;

  insert into public.live_answers
    (session_id, question_id, user_id, chosen_key, correct, answer_ms,
     confidence)
  values
    (p_session, p_question, auth.uid(), p_key, p_key = v_key, v_ms,
     app.normalize_confidence(p_confidence))
  on conflict (session_id, question_id, user_id) do nothing;

  -- Correctness is not returned: nobody learns the answer before reveal.
  return jsonb_build_object('accepted', true);
end;
$$;

revoke execute on function public.submit_live_answer(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.submit_live_answer(uuid, uuid, text, text)
  to authenticated;

-- ── the live fold carries confidence into the event log ─────────────────────
-- Body verbatim from 20260928000200 (guest and teacher exclusions
-- included), plus the confidence column. The FSRS grade stays
-- correctness-only.

create or replace function app.finalize_live_session_scoring(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  r record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then return; end if;
  for r in
    select a.user_id, a.question_id, a.chosen_key, a.correct, a.created_at,
           a.confidence, q.domain_id,
           md5('live:' || a.session_id || ':' || a.question_id || ':'
               || a.user_id)::uuid as det_id
      from public.live_answers a
      join public.questions q on q.id = a.question_id
     where a.session_id = p_session
       and not exists (select 1 from public.live_participants lp
                        where lp.session_id = a.session_id
                          and lp.user_id = a.user_id
                          and lp.is_guest)
       and not exists (select 1 from public.cohort_members cm
                        where cm.cohort_id = s.cohort_id
                          and cm.user_id = a.user_id
                          and cm.role in ('faculty', 'ta'))
  loop
    -- Deterministic id makes the fold idempotent.
    insert into public.events
      (event_id, user_id, cohort_id, type, question_id, domain_id,
       chosen_key, correct, client_ts, confidence)
    values
      (r.det_id, r.user_id, s.cohort_id, 'answer', r.question_id,
       r.domain_id, r.chosen_key, r.correct, r.created_at, r.confidence)
    on conflict (event_id) do nothing;
    if found then
      perform app.apply_graded_event(
        r.user_id, s.cohort_id, r.question_id, r.domain_id,
        case when r.correct then 2 else 0 end, r.correct, r.created_at);
    end if;
  end loop;
end;
$$;
