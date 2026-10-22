-- Washington watch: fix the dead push poller, add the White House fast
-- tier, and put the whole pipeline under the canary.
--
-- Root cause of the 2026-08-28 incident ("new executive order, no push,
-- nothing in Pulse"): the deployed push-washington function read and
-- wrote its watermarks via PostgREST as admin.schema('app') - but the
-- app schema is deliberately NOT exposed through PostgREST (that is the
-- trust boundary). Every read returned null, every write failed silently,
-- so every poll looked like a "first run" and baselined silently,
-- forever. Five weeks of 15-minute polls, zero pushes, zero errors.
--
-- The fix: watermark logic moves INTO Postgres as service-role-only RPCs
-- in the public schema (reachable by the function, still invisible to
-- clients), gains a White House watermark for same-day presidential
-- actions (the Federal Register publishes 3 to 5 days after signing),
-- and the canary alarms whenever the poller stops writing its heartbeat.

-- ── WH watermark + push audit log ───────────────────────────────────────────
alter table app.push_signal add column last_wh text;

create table app.push_log (
  id         bigint generated always as identity primary key,
  category   text not null,
  title      text,
  sent       int not null default 0,
  created_at timestamptz not null default now()
);

-- ── the watermark state machine, atomic ─────────────────────────────────────
-- Called by push-washington each poll with whatever it observed (nulls on
-- upstream hiccups; a null never regresses a watermark and never fires).
-- First run ever (all watermarks null) baselines silently.
create function public.washington_advance(
  p_eo int default null,
  p_bill date default null,
  p_law text default null,
  p_wh text default null,
  p_wh_title text default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  sig app.push_signal%rowtype;
  v_first boolean;
  v_eo boolean;
  v_bill boolean;
  v_law boolean;
  v_wh boolean;
begin
  select * into sig from app.push_signal where id for update;
  v_first := sig.last_eo_number is null and sig.last_law is null
             and sig.last_bill_date is null and sig.last_wh is null;
  v_eo   := p_eo   is not null and p_eo   is distinct from sig.last_eo_number;
  v_bill := p_bill is not null and p_bill is distinct from sig.last_bill_date;
  v_law  := p_law  is not null and p_law  is distinct from sig.last_law;
  v_wh   := p_wh   is not null and p_wh   is distinct from sig.last_wh;

  update app.push_signal set
    last_eo_number = coalesce(p_eo, last_eo_number),
    last_bill_date = coalesce(p_bill, last_bill_date),
    last_law       = coalesce(p_law, last_law),
    last_wh        = coalesce(p_wh, last_wh),
    updated_at     = now()
  where id;

  return jsonb_build_object(
    'first_run', v_first,
    'changed', (not v_first) and (v_eo or v_bill or v_law or v_wh),
    'wh_new', (not v_first) and v_wh,
    'eo_new', (not v_first) and v_eo,
    'wh_title', p_wh_title);
end;
$$;
revoke all on function public.washington_advance(int, date, text, text, text)
  from public, anon, authenticated;
grant execute on function public.washington_advance(int, date, text, text, text)
  to service_role;

create function public.washington_log_push(
  p_category text, p_title text, p_sent int
) returns void
language sql security definer set search_path = public, app, pg_temp as $$
  insert into app.push_log (category, title, sent)
  values (p_category, p_title, p_sent);
$$;
revoke all on function public.washington_log_push(text, text, int)
  from public, anon, authenticated;
grant execute on function public.washington_log_push(text, text, int)
  to service_role;

-- ── canary: the poller heartbeat is an invariant now ────────────────────────
-- Recreate with two added checks (7: poller heartbeat, 8: bills cache
-- stale-if-present). Body otherwise identical to 20260824000200.
create or replace function app.run_measurement_canary() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_failures jsonb := '[]';
  v_n bigint;
  v_hb timestamptz;
  v_bills timestamptz;
begin
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

  select count(*) into v_n from public.events
   where server_ts > now() + interval '5 minutes';
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'no_future_events', 'violations', v_n);
  end if;

  select count(*) into v_n from public.events
   where type = 'answer'
     and (question_id is null or chosen_key is null or correct is null);
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'answer_shape', 'violations', v_n);
  end if;

  select count(*) into v_n
    from public.events e
    join public.profiles p on p.id = e.user_id
   where p.is_guest;
  if v_n > 0 then
    v_failures := v_failures || jsonb_build_object(
      'check', 'guest_exclusion', 'violations', v_n);
  end if;

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

  if to_regprocedure('app.effective_resolution(uuid)') is null then
    v_failures := v_failures || jsonb_build_object(
      'check', 'policy_chokepoint_present', 'violations', 1);
  end if;

  -- 7. The push poller writes its heartbeat every poll; silence means the
  -- cron, the function, or its database access is broken (the exact
  -- failure mode of the 2026-08 incident).
  select updated_at into v_hb from app.push_signal where id;
  if v_hb is not null and v_hb < now() - interval '1 hour' then
    v_failures := v_failures || jsonb_build_object(
      'check', 'push_poller_alive', 'violations', 1,
      'last_heartbeat', v_hb);
  end if;

  -- 8. The bills cache goes stale only if the poller or upstream is
  -- broken (stale-if-present: a missing row is fine, the next poll
  -- recreates it).
  select fetched_at into v_bills from public.pulse_cache where key = 'bills';
  if v_bills is not null and v_bills < now() - interval '6 hours' then
    v_failures := v_failures || jsonb_build_object(
      'check', 'pulse_bills_fresh', 'violations', 1,
      'fetched_at', v_bills);
  end if;

  insert into app.canary_runs (ok, failures)
  values (jsonb_array_length(v_failures) = 0, v_failures);
end;
$$;
