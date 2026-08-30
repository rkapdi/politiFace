-- Measurement canary, cohort baselines, and demo-data quarantine.
--
-- The canary turns the measurement contract into continuously-running
-- checks: read-only invariants recorded daily, surfaced to admins.
-- Baselines freeze each cohort's starting distribution (aggregate only,
-- never per-student rows) so September lift is measured from a defensible
-- starting point. Demo cohorts are fenced out of every efficacy surface.
-- Methodology note: docs/compliance/MEASUREMENT.md.

-- ── demo quarantine ─────────────────────────────────────────────────────────
alter table public.cohorts
  add column is_demo boolean not null default false;

-- Rollups skip demo cohorts (recreate from 20260704000500:93; loop filter
-- is the only change).
create or replace function app.compute_all_cohort_rollups() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare c uuid;
begin
  for c in select id from public.cohorts where not is_demo loop
    perform app.compute_cohort_rollup(c);
  end loop;
end;
$$;

-- ── baselines (cohort-aggregate, k-anonymity floor of 5) ────────────────────
create table app.cohort_baselines (
  cohort_id     uuid primary key references public.cohorts (id) on delete cascade,
  captured_at   timestamptz not null default now(),
  model_version text not null,
  students      int not null check (students >= 5),
  avg_projected real not null,
  -- Histogram of projected scores in eight 10-point bins, '0-9' .. '70-80'.
  -- Aggregate only: no per-student rows, ever.
  distribution  jsonb not null
);

create function app.projected_mid(p_user uuid) returns real
language sql stable as $$
  select (sum(r.readiness) * 20)::real from app.readiness_v2(p_user) r
$$;

create function app.capture_cohort_baseline(p_cohort uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_students int;
  v_bins jsonb;
  v_avg real;
begin
  if exists (select 1 from app.cohort_baselines where cohort_id = p_cohort) then
    return; -- baselines capture exactly once
  end if;
  if (select is_demo from public.cohorts where id = p_cohort) then
    raise exception 'demo cohorts have no baselines';
  end if;
  select count(*) into v_students
    from public.cohort_members
   where cohort_id = p_cohort and role = 'student';
  if v_students < 5 then
    raise exception 'baselines need at least 5 students';
  end if;

  with mids as (
    select app.projected_mid(m.user_id) as mid
      from public.cohort_members m
     where m.cohort_id = p_cohort and m.role = 'student'
  ), binned as (
    select least(7, floor(mid / 10))::int as bin, count(*) as n
      from mids group by 1
  )
  select coalesce(jsonb_object_agg(
           format('%s-%s', bin * 10, bin * 10 + 9), n), '{}'::jsonb),
         (select avg(mid) from mids)::real
    into v_bins, v_avg
    from binned;

  insert into app.cohort_baselines
    (cohort_id, model_version, students, avg_projected, distribution)
  values
    (p_cohort, app.readiness_model_version(), v_students, v_avg, v_bins);
end;
$$;

-- Daily sweep: capture any cohort that has earned a baseline. A cohort
-- qualifies when 5+ students each carry real recent evidence, or when it
-- is 14 days old with 5+ students (whichever comes first).
create function app.capture_due_baselines() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare c record;
begin
  for c in
    select co.id
      from public.cohorts co
     where not co.is_demo
       and not exists (select 1 from app.cohort_baselines b
                        where b.cohort_id = co.id)
       and (select count(*) from public.cohort_members m
             where m.cohort_id = co.id and m.role = 'student') >= 5
       and (
         co.created_at < now() - interval '14 days'
         or (select count(*) from public.cohort_members m
              where m.cohort_id = co.id and m.role = 'student'
                and (select sum(r.answers) from app.readiness_v2(m.user_id) r) >= 8
            ) >= 5
       )
  loop
    perform app.capture_cohort_baseline(c.id);
  end loop;
end;
$$;

-- Faculty of the cohort (or admins) may capture manually; the aggregate
-- result is readable by TAs and up for the efficacy surfaces later.
create function public.capture_cohort_baseline(p_cohort uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) and not app.is_admin(auth.uid()) then
    raise exception 'only this class'' faculty can capture a baseline';
  end if;
  perform app.capture_cohort_baseline(p_cohort);
end;
$$;
revoke all on function public.capture_cohort_baseline(uuid) from public, anon;
grant execute on function public.capture_cohort_baseline(uuid) to authenticated;

create function public.get_cohort_baseline(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare b record;
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  select * into b from app.cohort_baselines where cohort_id = p_cohort;
  if b.cohort_id is null then return null; end if;
  return jsonb_build_object(
    'captured_at', b.captured_at,
    'model_version', b.model_version,
    'students', b.students,
    'avg_projected', b.avg_projected,
    'distribution', b.distribution);
end;
$$;
revoke all on function public.get_cohort_baseline(uuid) from public, anon;
grant execute on function public.get_cohort_baseline(uuid) to authenticated;

-- ── measurement canary ──────────────────────────────────────────────────────
create table app.canary_runs (
  id       bigint generated always as identity primary key,
  run_at   timestamptz not null default now(),
  ok       boolean not null,
  failures jsonb not null default '[]'
);

create function app.run_measurement_canary() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_failures jsonb := '[]';
  v_n bigint;
begin
  -- 1. Server grading matches the answer keys (sample: newest 500).
  select count(*) into v_n from (
    select 1
      from public.events e
      join app.question_keys k on k.question_id = e.question_id
     where e.type = 'answer' and e.correct is not null
       and e.chosen_key is not null
       and e.correct <> (e.chosen_key = k.answer_key)
     order by e.server_ts desc
     limit 500) x;
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'grading_integrity', 'violations', v_n);
  end if;

  -- 2. No events from the future.
  select count(*) into v_n from public.events
   where server_ts > now() + interval '5 minutes';
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'no_future_events', 'violations', v_n);
  end if;

  -- 3. Answer events carry their full shape.
  select count(*) into v_n from public.events
   where type = 'answer'
     and (question_id is null or chosen_key is null or correct is null);
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'answer_shape', 'violations', v_n);
  end if;

  -- 4. Guests never enter cohort analytics.
  select count(*) into v_n
    from public.events e
    join public.profiles p on p.id = e.user_id
   where p.is_guest;
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'guest_exclusion', 'violations', v_n);
  end if;

  -- 5. Demo cohorts stay out of efficacy surfaces.
  select count(*) into v_n
    from public.cohort_rollups r
    join public.cohorts c on c.id = r.cohort_id
   where c.is_demo;
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'demo_quarantine_rollups', 'violations', v_n);
  end if;
  select count(*) into v_n
    from app.cohort_baselines b
    join public.cohorts c on c.id = b.cohort_id
   where c.is_demo;
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'demo_quarantine_baselines', 'violations', v_n);
  end if;

  -- 6. The disclosure-policy chokepoint exists.
  if to_regprocedure('app.effective_resolution(uuid)') is null then
    v_failures := v_failures || jsonb_build_object(
      'check', 'policy_chokepoint_present', 'violations', 1);
  end if;

  insert into app.canary_runs (ok, failures)
  values (jsonb_array_length(v_failures) = 0, v_failures);
end;
$$;

create function public.admin_canary_status() returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare r record;
begin
  if not app.is_admin(auth.uid()) then
    raise exception 'admin only';
  end if;
  select * into r from app.canary_runs order by id desc limit 1;
  if r.id is null then return null; end if;
  return jsonb_build_object(
    'run_at', r.run_at, 'ok', r.ok, 'failures', r.failures,
    'model_version', app.readiness_model_version());
end;
$$;
revoke all on function public.admin_canary_status() from public, anon;
grant execute on function public.admin_canary_status() to authenticated;

-- ── daily jobs (guarded: pg_cron is absent in the local test cluster) ───────
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'measurement crons: pg_cron not installed; skipping';
    return;
  end if;
  if exists (select 1 from cron.job where jobname = 'measurement-canary') then
    perform cron.unschedule('measurement-canary');
  end if;
  perform cron.schedule('measurement-canary', '7 6 * * *',
    'select app.run_measurement_canary()');
  if exists (select 1 from cron.job where jobname = 'capture-baselines') then
    perform cron.unschedule('capture-baselines');
  end if;
  perform cron.schedule('capture-baselines', '47 6 * * *',
    'select app.capture_due_baselines()');
end $$;
