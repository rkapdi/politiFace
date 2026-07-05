-- Efficacy: cohort-aggregate only, pseudonymous, no education records.
-- These tables produce the one-pager Purcell carries into the president's
-- office. Faculty read aggregates for their own cohorts; nobody reads
-- another student's rows.

create table public.cohort_rollups (
  cohort_id          uuid not null references public.cohorts (id) on delete cascade,
  computed_at        timestamptz not null default now(),
  active_users       int,
  sessions           int,
  questions_answered int,
  baseline_avg       jsonb,  -- {"score": 41.2, "per_domain": {...}, "n": 27}
  final_avg          jsonb,
  lift               jsonb,  -- {"score_delta": ..., "crossed_to_passing": ...}
  engagement         jsonb,  -- {"study_minutes": ..., "median_streak": ...}
  primary key (cohort_id, computed_at)
);

-- Institution-supplied outcome, aggregate by definition.
create table public.cohort_outcomes (
  cohort_id               uuid primary key references public.cohorts (id) on delete cascade,
  first_attempt_pass_rate real,
  source                  text not null default 'institution',
  recorded_at             timestamptz not null default now()
);

-- Recompute a cohort's rollup from the event log and mock attempts.
-- Scheduled via pg_cron below; also callable ad hoc by the service role.
create function app.compute_cohort_rollup(p_cohort uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_active int;
  v_sessions int;
  v_answers int;
  v_baseline jsonb;
  v_final jsonb;
  v_lift jsonb;
  v_engagement jsonb;
begin
  select count(distinct user_id) into v_active
    from public.events where cohort_id = p_cohort;
  select count(*) into v_sessions
    from public.events where cohort_id = p_cohort and type = 'session_start';
  select count(*) into v_answers
    from public.events
    where cohort_id = p_cohort and type = 'answer' and correct is not null;

  -- Average of each student's FIRST completed baseline mock.
  select jsonb_build_object('score', round(avg(score)::numeric, 1), 'n', count(*))
    into v_baseline
    from (
      select distinct on (user_id) user_id, score
      from public.mock_attempts
      where cohort_id = p_cohort and kind = 'baseline' and completed_at is not null
      order by user_id, completed_at asc
    ) firsts;

  -- Average of each student's LAST completed mock (any kind) as the "final".
  select jsonb_build_object(
           'score', round(avg(score)::numeric, 1),
           'n', count(*),
           'passing_share', round(avg((passed)::int)::numeric, 3))
    into v_final
    from (
      select distinct on (user_id) user_id, score, passed
      from public.mock_attempts
      where cohort_id = p_cohort and completed_at is not null
      order by user_id, completed_at desc
    ) lasts;

  v_lift := jsonb_build_object(
    'score_delta',
    case when (v_baseline ->> 'score') is not null and (v_final ->> 'score') is not null
      then round(((v_final ->> 'score')::numeric - (v_baseline ->> 'score')::numeric), 1)
    end);

  select jsonb_build_object('median_streak',
           percentile_cont(0.5) within group (order by s.current))
    into v_engagement
    from public.streaks s
    join public.cohort_members m on m.user_id = s.user_id
    where m.cohort_id = p_cohort and m.role = 'student';

  insert into public.cohort_rollups
    (cohort_id, active_users, sessions, questions_answered,
     baseline_avg, final_avg, lift, engagement)
  values
    (p_cohort, v_active, v_sessions, v_answers,
     v_baseline, v_final, v_lift, v_engagement);
end;
$$;

create function app.compute_all_cohort_rollups() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare c uuid;
begin
  for c in select id from public.cohorts loop
    perform app.compute_cohort_rollup(c);
  end loop;
end;
$$;

-- Nightly rollup refresh. Guarded so migrations also apply on plain Postgres
-- (local test harnesses) where pg_cron is unavailable.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule(
      'cohort-rollups-nightly', '17 6 * * *',
      $job$ select app.compute_all_cohort_rollups(); $job$);
  end if;
end;
$$;

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.cohort_rollups  enable row level security;
alter table public.cohort_outcomes enable row level security;

grant select on public.cohort_rollups, public.cohort_outcomes to authenticated;

create policy rollups_select_faculty on public.cohort_rollups for select
  to authenticated using (app.is_cohort_faculty(cohort_id));
create policy outcomes_select_faculty on public.cohort_outcomes for select
  to authenticated using (app.is_cohort_faculty(cohort_id));
