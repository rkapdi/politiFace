-- Educator analytics: engagement trend (aggregate, ta-or-above), at-risk
-- list and per-student drill-down (policy-gated via app.effective_resolution).
-- One semantic layer: every surface renders these RPCs, nothing recomputes.

-- ── engagement trend ────────────────────────────────────────────────────────
create function public.cohort_engagement_trend(
  p_cohort uuid, p_days int default 28
) returns table (day date, active_students bigint, answers bigint)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  if p_days not between 7 and 120 then
    raise exception 'days must be between 7 and 120';
  end if;
  return query
    select d::date as day,
           count(distinct e.user_id) as active_students,
           count(e.event_id) as answers
      from generate_series(
             current_date - (p_days - 1), current_date, interval '1 day') d
      left join public.events e
        on e.cohort_id = p_cohort and e.type = 'answer'
       and e.server_ts >= d and e.server_ts < d + interval '1 day'
     group by d::date
     order by d::date;
end;
$$;
revoke all on function public.cohort_engagement_trend(uuid, int) from public, anon;
grant execute on function public.cohort_engagement_trend(uuid, int) to authenticated;

-- ── at-risk list ────────────────────────────────────────────────────────────
-- "Who do I need to talk to": students under the readiness threshold
-- (students with no data count as readiness 0), weakest domain first.
create function public.at_risk_students(
  p_cohort uuid, p_threshold real default 0.6
) returns table (
  student_ref text, display_name text, overall_readiness real,
  weakest_domain_id smallint, weakest_domain_name text,
  weakest_readiness real, last_active timestamptz, answers_14d bigint
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare v_res text;
begin
  v_res := app.effective_resolution(p_cohort);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;
  return query
    with base as (
      select m.user_id, m.roster_name, p.handle,
             coalesce(avg(r.readiness), 0)::real as overall
        from public.cohort_members m
        join public.profiles p on p.id = m.user_id
        left join public.user_domain_readiness r
          on r.user_id = m.user_id
       where m.cohort_id = p_cohort and m.role = 'student'
       group by m.user_id, m.roster_name, p.handle
    ), weakest as (
      select b.user_id, r.domain_id, d.name, r.readiness,
             row_number() over (partition by b.user_id
                                order by r.readiness asc nulls first) as rn
        from base b
        left join public.user_domain_readiness r on r.user_id = b.user_id
        left join public.domains d on d.id = r.domain_id
    ), act as (
      select b.user_id, max(e.server_ts) as last_active,
             count(e.event_id) filter (
               where e.type = 'answer'
                 and e.server_ts > now() - interval '14 days') as a14
        from base b
        left join public.events e
          on e.user_id = b.user_id and e.cohort_id = p_cohort
       group by b.user_id
    )
    select case when v_res = 'per_student' then b.user_id::text
                else app.pseudonym_for(p_cohort, b.user_id) end,
           case when v_res = 'per_student'
                then app.identity_label(p_cohort, b.user_id, b.roster_name, b.handle)
                else app.pseudonym_for(p_cohort, b.user_id) end,
           b.overall,
           w.domain_id, w.name, w.readiness,
           act.last_active, coalesce(act.a14, 0)
      from base b
      left join weakest w on w.user_id = b.user_id and w.rn = 1
      left join act on act.user_id = b.user_id
     where b.overall < p_threshold
     order by b.overall asc, act.last_active asc nulls first;
end;
$$;
revoke all on function public.at_risk_students(uuid, real) from public, anon;
grant execute on function public.at_risk_students(uuid, real) to authenticated;

-- ── per-student drill-down ──────────────────────────────────────────────────
-- The full picture behind an at-risk flag. p_student_ref is whatever the
-- listing RPCs returned under the active policy: a user id (per_student)
-- or a stable pseudonym (pseudonymous). Suggestions are rule-based plain
-- sentences the UI renders or prefills; nothing is generated.
create function public.student_drilldown(p_cohort uuid, p_student_ref text)
returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_res text;
  v_target uuid;
  v_roster text;
  v_handle text;
  v_identity jsonb;
  v_domains jsonb;
  v_objectives jsonb;
  v_activity jsonb;
  v_live jsonb;
  v_mocks jsonb;
  v_suggestions jsonb;
begin
  v_res := app.effective_resolution(p_cohort);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;

  if v_res = 'per_student' then
    begin
      v_target := p_student_ref::uuid;
    exception when others then
      raise exception 'no such student in this class';
    end;
    if not exists (select 1 from public.cohort_members
                    where cohort_id = p_cohort and user_id = v_target
                      and role = 'student') then
      raise exception 'no such student in this class';
    end if;
  else
    select m.user_id into v_target
      from public.cohort_members m
     where m.cohort_id = p_cohort and m.role = 'student'
       and app.pseudonym_for(p_cohort, m.user_id) = p_student_ref;
    if v_target is null then
      raise exception 'no such student in this class';
    end if;
  end if;

  select m.roster_name, p.handle into v_roster, v_handle
    from public.cohort_members m join public.profiles p on p.id = m.user_id
   where m.cohort_id = p_cohort and m.user_id = v_target;

  v_identity := jsonb_build_object(
    'student_ref', p_student_ref,
    'display_name', case when v_res = 'per_student'
      then app.identity_label(p_cohort, v_target, v_roster, v_handle)
      else app.pseudonym_for(p_cohort, v_target) end);

  select coalesce(jsonb_agg(jsonb_build_object(
           'domain_id', d.id, 'name', d.name,
           'readiness', r.readiness, 'accuracy', r.accuracy)
           order by r.readiness asc nulls first), '[]'::jsonb)
    into v_domains
    from public.domains d
    left join public.user_domain_readiness r
      on r.user_id = v_target and r.domain_id = d.id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'objective_id', w.id, 'code', w.code,
           'title', w.description, 'readiness', w.readiness)
           order by w.readiness asc), '[]'::jsonb)
    into v_objectives
    from (
      select o.id, o.code, o.description, r.readiness
        from public.user_objective_readiness r
        join public.objectives o on o.id = r.objective_id
       where r.user_id = v_target and r.readiness < 0.6
       order by r.readiness asc
       limit 5) w;

  select jsonb_build_object(
           'last_active', max(e.server_ts),
           'answers_7d', count(e.event_id) filter (
             where e.type = 'answer'
               and e.server_ts > now() - interval '7 days'),
           'answers_28d', count(e.event_id) filter (
             where e.type = 'answer'
               and e.server_ts > now() - interval '28 days'),
           'answers_total', count(e.event_id) filter (where e.type = 'answer'),
           'accuracy', coalesce(avg(e.correct::int) filter (
             where e.type = 'answer' and e.correct is not null), 0))
    into v_activity
    from public.events e
   where e.user_id = v_target and e.cohort_id = p_cohort;

  select coalesce(jsonb_agg(jsonb_build_object(
           'session_id', s.id, 'title', s.title, 'held_at', s.created_at,
           'correct', t.correct_count, 'answered', t.answered)
           order by s.created_at desc), '[]'::jsonb)
    into v_live
    from (
      select a.session_id,
             count(*) filter (where a.correct) as correct_count,
             count(*) as answered
        from public.live_answers a
        join public.live_sessions ls on ls.id = a.session_id
       where a.user_id = v_target and ls.cohort_id = p_cohort
       group by a.session_id) t
    join public.live_sessions s on s.id = t.session_id;

  select jsonb_build_object(
           'completed', count(*),
           'best_score', max(a.score))
    into v_mocks
    from public.mock_attempts a
   where a.user_id = v_target and a.cohort_id = p_cohort
     and a.completed_at is not null;

  -- Rule-based next steps: the two weakest domains under 0.6, plus an
  -- inactivity nudge.
  select coalesce(jsonb_agg(s.txt), '[]'::jsonb) into v_suggestions
    from (
      select format('Assign weak-area practice on %s (readiness %s%%).',
                    d.name, round(coalesce(r.readiness, 0) * 100)) as txt
        from public.user_domain_readiness r
        join public.domains d on d.id = r.domain_id
       where r.user_id = v_target and coalesce(r.readiness, 0) < 0.6
       order by r.readiness asc nulls first
       limit 2) s;
  if (v_activity ->> 'last_active') is null
     or (v_activity ->> 'last_active')::timestamptz < now() - interval '7 days' then
    v_suggestions := v_suggestions ||
      to_jsonb('Nudge this student: no practice in the last 7 days.'::text);
  end if;

  return jsonb_build_object(
    'identity', v_identity, 'domains', v_domains,
    'weak_objectives', v_objectives, 'activity', v_activity,
    'live_sessions', v_live, 'mocks', v_mocks,
    'suggestions', v_suggestions);
end;
$$;
revoke all on function public.student_drilldown(uuid, text) from public, anon;
grant execute on function public.student_drilldown(uuid, text) to authenticated;
