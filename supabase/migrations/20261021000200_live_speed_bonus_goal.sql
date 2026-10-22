-- Live sessions: a per-session speed bonus switch and a class-wide goal.
--
--   speed_bonus  When on, a correct answer scores 100 plus up to 50 for
--                speed (the original rule). When off, every correct
--                answer scores a flat 100, so a careful reader is never
--                outscored by a fast tapper. Existing sessions keep their
--                current behavior (backfilled ON); new sessions default
--                OFF.
--   goal_pct     Optional instructor target for the class percent correct
--                on each question (1 to 100). Shown at every reveal as a
--                meter; hidden when null.
--
-- Scoring stays server-owned. One helper, app.live_answer_points, is the
-- only place the rule lives, and both scoring surfaces (live_scoreboard
-- and live_session_report) call it. Points are never negative.
--
-- Additive only: two columns, one helper, and in-place recreations whose
-- bodies are verbatim from their latest migrations plus the noted deltas.
-- create_live_session keeps its hold-out guard (20260928000100) byte for
-- byte; only the two trailing parameters and the insert columns are new.
-- Callers of the old five-argument shape keep working through defaults,
-- and the old signature is dropped so there is no ambiguous overload.

-- ── columns ─────────────────────────────────────────────────────────────────

-- Adding with DEFAULT true backfills every existing row to the current
-- behavior; the default then flips so new sessions start with it off.
alter table public.live_sessions
  add column speed_bonus boolean not null default true;
alter table public.live_sessions
  alter column speed_bonus set default false;

alter table public.live_sessions
  add column goal_pct smallint
    constraint live_sessions_goal_pct_check
    check (goal_pct between 1 and 100);

-- ── the one scoring rule ────────────────────────────────────────────────────

create function app.live_answer_points(
  p_correct          boolean,
  p_answer_ms        int,
  p_question_seconds int,
  p_speed_bonus      boolean
) returns int
language sql immutable set search_path = pg_temp as $$
  select case
    when not coalesce(p_correct, false) then 0
    when not coalesce(p_speed_bonus, true) then 100
    else 100 + round(50.0 * (1 - p_answer_ms::numeric
                              / (p_question_seconds * 1000)))::int
  end;
$$;

-- ── create_live_session: two trailing options ───────────────────────────────
-- Body verbatim from 20260928000100, plus p_speed_bonus / p_goal_pct.

drop function public.create_live_session(uuid, text, jsonb, int, boolean);
create function public.create_live_session(
  p_cohort uuid,
  p_title text,
  p_question_ids jsonb,
  p_question_seconds int default 20,
  p_allow_guests boolean default false,
  p_speed_bonus boolean default false,
  p_goal_pct int default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_code text;
  v_count int;
  v_valid int;
  v_locked int;
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  v_count := jsonb_array_length(p_question_ids);
  if v_count is null or v_count < 1 or v_count > 50 then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  select count(*) into v_valid
    from jsonb_array_elements_text(p_question_ids) qid
    join public.questions q on q.id = qid::uuid
   where q.review_status = 'published'
     and (q.cohort_id is null or q.cohort_id = p_cohort);
  if v_valid <> v_count then
    raise exception 'question list contains unknown, unpublished, or foreign-cohort questions';
  end if;
  -- No held-out items: a reserved question surfacing in a live session
  -- would contaminate its own 7/21-day check.
  select count(*) into v_locked
    from jsonb_array_elements_text(p_question_ids) qid
   where qid::uuid in (select app.cohort_locked_question_ids(p_cohort));
  if v_locked > 0 then
    raise exception
      'question list contains % item(s) reserved for a scheduled retention check',
      v_locked;
  end if;
  if p_goal_pct is not null and (p_goal_pct < 1 or p_goal_pct > 100) then
    raise exception 'class goal must be between 1 and 100 percent';
  end if;

  insert into public.live_sessions
    (cohort_id, created_by, title, question_ids, question_seconds, allow_guests,
     speed_bonus, goal_pct)
  values
    (p_cohort, auth.uid(), trim(p_title), p_question_ids, p_question_seconds,
     coalesce(p_allow_guests, false), coalesce(p_speed_bonus, false),
     p_goal_pct)
  returning id, join_code into v_id, v_code;

  return jsonb_build_object('id', v_id, 'join_code', v_code,
                            'question_count', v_count);
end;
$$;
revoke all on function public.create_live_session(uuid, text, jsonb, int, boolean, boolean, int) from public, anon;
grant execute on function public.create_live_session(uuid, text, jsonb, int, boolean, boolean, int) to authenticated;

-- ── get_live_question: expose the switch ────────────────────────────────────
-- Body verbatim from 20260821000400, plus 'speed_bonus' so the app can say
-- whether speed matters before anyone answers.

create or replace function public.get_live_question(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  q record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status not in ('question', 'reveal') then
    return jsonb_build_object('status', s.status);
  end if;
  select id, stem, options into q from public.questions
   where id = (s.question_ids ->> s.current_index)::uuid;
  return jsonb_build_object(
    'status', s.status, 'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds,
    'speed_bonus', s.speed_bonus,
    'started_at', s.question_started_at,
    'question', jsonb_build_object(
      'id', q.id, 'stem', q.stem, 'options', q.options));
end;
$$;

-- ── live_reveal: the goal rides along ───────────────────────────────────────
-- Body verbatim from 20260821000400, plus 'goal_pct' (null when unset) and
-- 'speed_bonus'. The class percent is derived from 'counts' client side.

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
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
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
                            'explanation', v_expl, 'counts', v_counts,
                            'goal_pct', s.goal_pct,
                            'speed_bonus', s.speed_bonus);
end;
$$;

-- ── live_scoreboard honors the switch ───────────────────────────────────────
-- Body verbatim from 20260821000400; the inline formula becomes
-- app.live_answer_points.

create or replace function public.live_scoreboard(p_session uuid)
returns table (rank bigint, handle text, score bigint, correct_count bigint, is_me boolean)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status = 'question' and not app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'standings arrive at the reveal';
  end if;
  return query
    select row_number() over (order by t.score desc, t.total_ms asc) as rank,
           coalesce(lp.display_name, p.handle), t.score, t.correct_count,
           (t.user_id = auth.uid()) as is_me
      from (
        select a.user_id,
               sum(app.live_answer_points(a.correct, a.answer_ms,
                                          s.question_seconds,
                                          s.speed_bonus))::bigint as score,
               count(*) filter (where a.correct) as correct_count,
               sum(a.answer_ms)::bigint as total_ms
          from public.live_answers a
         where a.session_id = p_session
         group by a.user_id) t
      join public.profiles p on p.id = t.user_id
      left join public.live_participants lp
        on lp.session_id = p_session and lp.user_id = t.user_id
     order by t.score desc, t.total_ms asc
     limit 50;
end;
$$;

-- ── live_session_report honors the switch ───────────────────────────────────
-- Body verbatim from 20260821000200 (reporting-policy gate included); the
-- inline formula becomes app.live_answer_points. Same return type, so an
-- in-place replace keeps its grants.

create or replace function public.live_session_report(p_session uuid)
returns table (
  user_id uuid,
  roster_name text,
  handle text,
  score bigint,
  correct_count bigint,
  answered bigint,
  per_question jsonb,
  student_ref text
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_res text;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  v_res := app.effective_resolution(s.cohort_id);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;
  return query
    select case when v_res = 'per_student' then m.user_id end,
           case when v_res = 'per_student'
                then app.identity_label(s.cohort_id, m.user_id,
                                        m.roster_name, p.handle)
                else app.pseudonym_for(s.cohort_id, m.user_id) end,
           case when v_res = 'per_student' then p.handle
                else app.pseudonym_for(s.cohort_id, m.user_id) end,
           coalesce(sum(app.live_answer_points(a.correct, a.answer_ms,
                                               s.question_seconds,
                                               s.speed_bonus)), 0)::bigint as score,
           count(*) filter (where a.correct) as correct_count,
           count(a.question_id) as answered,
           coalesce(jsonb_object_agg(a.question_id, a.correct)
                    filter (where a.question_id is not null),
                    '{}'::jsonb) as per_question,
           case when v_res = 'per_student' then m.user_id::text
                else app.pseudonym_for(s.cohort_id, m.user_id) end
      from public.cohort_members m
      join public.profiles p on p.id = m.user_id
      left join public.live_answers a
        on a.session_id = p_session and a.user_id = m.user_id
     where m.cohort_id = s.cohort_id and m.role = 'student'
       and (exists (select 1 from public.live_participants lp
                     where lp.session_id = p_session
                       and lp.user_id = m.user_id)
            or exists (select 1 from public.live_answers a2
                        where a2.session_id = p_session
                          and a2.user_id = m.user_id))
     group by m.user_id, m.roster_name, p.handle
     order by score desc;
end;
$$;
