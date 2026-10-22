-- Glanceable intelligence, layer 1: the class pulse and the score
-- distribution. Rule-based and deterministic: every clause of the pulse
-- sentence traces to a query over the same readiness_v2 model the rest of
-- the platform uses. No generated text anywhere.
--
-- Both are cohort-aggregate (counts and bins only), so TAs may read them;
-- both respect the 5-student k-anonymity floor by answering honestly with
-- below_floor instead of leaking small-class statistics.

-- ── the pulse ───────────────────────────────────────────────────────────────
create function public.cohort_pulse(p_cohort uuid) returns jsonb
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

  if v_students < 5 then
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

  -- Cards, priority order, at most three, each one action.
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
revoke all on function public.cohort_pulse(uuid) from public, anon;
grant execute on function public.cohort_pulse(uuid) to authenticated;

-- ── the distribution ────────────────────────────────────────────────────────
-- Projected-score histogram in the same eight 10-point bins as
-- app.cohort_baselines, so current-vs-baseline overlays line up.
create function public.cohort_distribution(p_cohort uuid) returns jsonb
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

  if v_students < 5 then
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
revoke all on function public.cohort_distribution(uuid) from public, anon;
grant execute on function public.cohort_distribution(uuid) to authenticated;
