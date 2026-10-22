-- Per-student first (founder directive 2026-08-26): for classes on the
-- default per_student policy, faculty already see every individual, so
-- gating CLASS-level statistics behind a 5-student floor is pure
-- friction. The floor now applies only where aggregates are the sole
-- view and could otherwise be reversed into individual facts:
-- aggregate_only classes and TA callers.

create function app.aggregate_floor(p_cohort uuid) returns int
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  return case
    when app.effective_resolution(p_cohort) = 'per_student' then 1
    else 5
  end;
end;
$$;

-- ── cohort_overview (body from 20260821000100; floor becomes dynamic) ───────
create or replace function public.cohort_overview(p_cohort uuid)
returns table (
  students        int,
  active_7d       int,
  answers_total   int,
  mocks_completed int
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  if (select count(*) from public.cohort_members m
        where m.cohort_id = p_cohort and m.role = 'student')
     < app.aggregate_floor(p_cohort) then
    return query select
      (select count(*)::int from public.cohort_members m
        where m.cohort_id = p_cohort and m.role = 'student'),
      null::int, null::int, null::int;
    return;
  end if;
  return query select
    (select count(*)::int from public.cohort_members m
      where m.cohort_id = p_cohort and m.role = 'student'),
    (select count(distinct e.user_id)::int from public.events e
      where e.cohort_id = p_cohort and e.server_ts > now() - interval '7 days'),
    (select count(*)::int from public.events e
      where e.cohort_id = p_cohort and e.type = 'answer'
        and e.correct is not null),
    (select count(*)::int from public.mock_attempts a
      where a.cohort_id = p_cohort and a.completed_at is not null);
end;
$$;

-- ── cohort_domain_stats (floor becomes dynamic) ─────────────────────────────
create or replace function public.cohort_domain_stats(p_cohort uuid, p_min_n int default 5)
returns table (
  domain_code text,
  domain_name text,
  students    int,
  answers     int,
  accuracy    real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select d.code,
           d.name,
           count(distinct e.user_id)::int,
           count(*)::int,
           avg(e.correct::int)::real
    from public.events e
    join public.domains d on d.id = e.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by d.code, d.name, d.ordinal
    having count(distinct e.user_id)
           >= greatest(p_min_n, app.aggregate_floor(p_cohort))
    order by d.ordinal;
end;
$$;

-- ── cohort_top_misses (floor becomes dynamic) ───────────────────────────────
create or replace function public.cohort_top_misses(
  p_cohort uuid,
  p_min_n  int default 1,
  p_limit  int default 10
)
returns table (
  question_id uuid,
  stem        text,
  domain_code text,
  students    int,
  attempts    int,
  miss_rate   real
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select q.id,
           q.stem,
           d.code,
           count(distinct e.user_id)::int,
           count(*)::int,
           (1.0 - avg(e.correct::int))::real
    from public.events e
    join public.questions q on q.id = e.question_id
    join public.domains d on d.id = q.domain_id
    where e.cohort_id = p_cohort
      and e.type = 'answer'
      and e.correct is not null
    group by q.id, q.stem, d.code
    having count(distinct e.user_id)
           >= greatest(p_min_n, app.aggregate_floor(p_cohort))
       and avg(e.correct::int) < 1.0
    order by (1.0 - avg(e.correct::int)) desc, count(*) desc
    limit greatest(p_limit, 1);
end;
$$;

-- ── cohort_pulse (floor becomes dynamic) ────────────────────────────────────
create or replace function public.cohort_pulse(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_students int;
  v_active int;
  v_above int;
  v_at_risk int;
  v_weak record;
  v_cards jsonb := '[]';
  v_sentence text;
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;

  select count(*) into v_students
    from public.cohort_members
   where cohort_id = p_cohort and role = 'student';

  if v_students < app.aggregate_floor(p_cohort) then
    return jsonb_build_object(
      'below_floor', true,
      'students', v_students,
      'sentence',
      'Class statistics appear once 5 students join. '
      || v_students || ' joined so far.',
      'cards', '[]'::jsonb);
  end if;

  with mids as (
    select m.user_id, app.projected_mid(m.user_id) as mid
      from public.cohort_members m
     where m.cohort_id = p_cohort and m.role = 'student'
  )
  select count(*) filter (where mid >= 48),
         count(*) filter (where mid < 48)
    into v_above, v_at_risk
    from mids;

  select count(distinct e.user_id) into v_active
    from public.events e
    join public.cohort_members m
      on m.user_id = e.user_id and m.cohort_id = p_cohort
     and m.role = 'student'
   where e.cohort_id = p_cohort
     and e.server_ts > now() - interval '7 days';

  select d.name, avg(r.readiness) as avg_readiness
    into v_weak
    from public.cohort_members m
    cross join lateral app.readiness_v2(m.user_id) r
    join public.domains d on d.id = r.domain_id
   where m.cohort_id = p_cohort and m.role = 'student'
   group by d.name
   order by avg(r.readiness) asc
   limit 1;

  if v_at_risk > 0 then
    v_cards := v_cards || jsonb_build_object(
      'kind', 'at_risk',
      'headline', v_at_risk || ' student'
        || case when v_at_risk = 1 then ' projects' else 's project' end
        || ' below the pass line',
      'detail', 'The Students tab ranks them lowest readiness first.');
  end if;
  if v_weak.avg_readiness is not null and v_weak.avg_readiness < 0.55 then
    v_cards := v_cards || jsonb_build_object(
      'kind', 'weak_domain',
      'headline', v_weak.name || ' is dragging the class',
      'detail', 'Average readiness '
        || round(v_weak.avg_readiness * 100) || '%. A live reteach session '
        || 'moves this fastest.');
  end if;
  if v_active < (v_students + 1) / 2 then
    v_cards := v_cards || jsonb_build_object(
      'kind', 'participation',
      'headline', 'Only ' || v_active || ' of ' || v_students
        || ' practiced this week',
      'detail', 'A class announcement brings students back.');
  end if;

  v_sentence :=
    v_above || ' of ' || v_students
    || ' students project above the pass line. '
    || coalesce(
         v_weak.name || ' is the weakest domain at '
           || round(v_weak.avg_readiness * 100) || '%. ',
         '')
    || v_active || ' of ' || v_students || ' practiced this week.';

  return jsonb_build_object(
    'students', v_students,
    'active_7d', v_active,
    'above_line', v_above,
    'at_risk', v_at_risk,
    'model_version', app.readiness_model_version(),
    'sentence', v_sentence,
    'cards', v_cards);
end;
$$;

-- ── cohort_distribution (floor becomes dynamic) ─────────────────────────────
create or replace function public.cohort_distribution(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_students int;
  v_bins jsonb;
  v_avg real;
  v_above int;
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;

  select count(*) into v_students
    from public.cohort_members
   where cohort_id = p_cohort and role = 'student';

  if v_students < app.aggregate_floor(p_cohort) then
    return jsonb_build_object(
      'below_floor', true, 'students', v_students, 'pass_line', 48);
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
         (select avg(mid) from mids)::real,
         (select count(*) from mids where mid >= 48)
    into v_bins, v_avg, v_above
    from binned;

  return jsonb_build_object(
    'students', v_students,
    'bins', v_bins,
    'avg', v_avg,
    'above_line', v_above,
    'pass_line', 48,
    'model_version', app.readiness_model_version());
end;
$$;
