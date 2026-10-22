-- Instructors watch their own live sessions; answers are for students.
--
-- A class's faculty or TA answering in its own session (for example the
-- professor joining from the app to try it) landed on the student
-- scoreboard, was averaged into "What to reteach", was left out of the
-- student report, and was folded into the class's events, which skews
-- cohort_domain_stats and cohort_top_misses (neither filters by role).
-- One rule fixes every surface at once: the server refuses their answers.
--
--   1. submit_live_answer refuses the class's faculty and TAs.
--   2. finalize_live_session_scoring never folds a teacher's answer, as a
--      backstop for answers recorded before this migration.
--   3. One-time cleanup of teacher answers already recorded: the live
--      answers, the events folded from them (deterministic ids), and
--      teacher rows on their own classes' leaderboards.

-- ── 1. refuse teacher answers ───────────────────────────────────────────────
-- Body verbatim from 20260821000400, plus the teacher check.
create or replace function public.submit_live_answer(
  p_session uuid,
  p_question uuid,
  p_key text
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
    (session_id, question_id, user_id, chosen_key, correct, answer_ms)
  values
    (p_session, p_question, auth.uid(), p_key, p_key = v_key, v_ms)
  on conflict (session_id, question_id, user_id) do nothing;

  -- Correctness is not returned: nobody learns the answer before reveal.
  return jsonb_build_object('accepted', true);
end;
$$;

-- ── 2. never fold a teacher's answer ────────────────────────────────────────
-- Body verbatim from 20260821000400, plus the teacher exclusion.
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
           q.domain_id,
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

-- ── 3. one-time cleanup ─────────────────────────────────────────────────────
-- Teacher answers already recorded. The fold's events are found by the same
-- deterministic id the fold used, so nothing else in the log is touched.
delete from public.events e
 using public.live_answers a
  join public.live_sessions s on s.id = a.session_id
  join public.cohort_members cm
    on cm.cohort_id = s.cohort_id and cm.user_id = a.user_id
   and cm.role in ('faculty', 'ta')
 where e.event_id = md5('live:' || a.session_id || ':' || a.question_id
                        || ':' || a.user_id)::uuid;

delete from public.live_answers a
 using public.live_sessions s, public.cohort_members cm
 where s.id = a.session_id
   and cm.cohort_id = s.cohort_id and cm.user_id = a.user_id
   and cm.role in ('faculty', 'ta');

delete from public.leaderboard l
 using public.cohort_members cm
 where cm.cohort_id = l.cohort_id and cm.user_id = l.user_id
   and cm.role in ('faculty', 'ta');
