-- Tier 2 server-side readiness: per-OBJECTIVE rolling accuracy, one level
-- deeper than public.user_domain_readiness (20260704000400_read_models.sql).
--
-- ⚠️  UNAPPLIED / DRAFT: this migration touches the LIVE production database.
--     It has been validated only against a throwaway local Postgres 17 via
--     supabase/tests/run_local.sh. It must be reviewed by a human and applied
--     MANUALLY. Do not auto-apply.
--
-- Trust boundary preserved: the new table is server-derived, written only from
-- inside the SECURITY DEFINER grading path (app.apply_graded_event, called by
-- submit_answer / submit_review). Clients get SELECT-own via RLS and nothing
-- more. No answer keys are exposed, `events` stays append-only and unwidened,
-- and no existing RLS/grant is weakened. The grading RPC signatures are
-- unchanged, so submit_answer / submit_review keep calling apply_graded_event
-- exactly as before.

-- ── Read model: per-objective rolling accuracy ──────────────────────────────
-- Mirrors public.user_domain_readiness column-for-column, keyed by objective.
create table public.user_objective_readiness (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  objective_id uuid not null references public.objectives (id),
  cohort_id    uuid references public.cohorts (id),
  accuracy     real,             -- rolling accuracy over the last 50 answers
  readiness    real,             -- 0..1; v1: equals accuracy, refine later
  updated_at   timestamptz not null default now(),
  primary key (user_id, objective_id)
);

-- Index note: the join below is driven by public.questions.objective_id, which
-- is already indexed as questions_objective_idx (20260704000200_content.sql),
-- and by events per-user (events_user_ts_idx). No additional index is added:
-- a per-user answer history is small, and widening indexes on the append-only
-- `events` table carries write cost for no measurable read benefit here.

-- ── RLS + grant: mirror user_domain_readiness ───────────────────────────────
alter table public.user_objective_readiness enable row level security;

grant select on public.user_objective_readiness to authenticated;

create policy readiness_obj_select_own on public.user_objective_readiness for select
  to authenticated using (user_id = auth.uid());

-- ── Grading hook: reproduce the current body verbatim, then add the ──────────
-- ── objective-readiness upsert inside the `if p_correct is not null` block. ──
-- Signature is UNCHANGED. The only additions vs. 20260704000400_read_models.sql
-- are the `v_obj uuid;` declaration and the objective section flagged below.
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
    -- Leaderboard: +1 per correct answer.
    if p_cohort is not null and p_correct then
      insert into public.leaderboard (cohort_id, user_id, score, updated_at)
      values (p_cohort, p_user, 1, now())
      on conflict (cohort_id, user_id) do update set
        score = public.leaderboard.score + 1, updated_at = now();
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
