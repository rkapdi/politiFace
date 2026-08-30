-- Per-student coaching, deepened: the weekly trend (is this student
-- improving) and the one-click weak-area assignment (do something about
-- it). Founder directive 2026-08-26: per-student measurement and
-- individual feedback are the product.

-- ── student_trend ───────────────────────────────────────────────────────────
-- Eight weekly points. Each week's projected score applies the SAME
-- readiness model (v2: 45-day window, 50-answer cap, shrunk prior) as of
-- that week's end, so the trend line and today's headline number agree by
-- construction. Weekly answers/accuracy show effort alongside outcome.
create function public.student_trend(p_cohort uuid, p_student_ref text)
returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_res text;
  v_target uuid;
  v_weeks jsonb;
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

  select jsonb_agg(jsonb_build_object(
           'week_start', to_char(w.wk, 'YYYY-MM-DD'),
           'projected', w.projected,
           'answers', w.answers,
           'accuracy', w.accuracy)
           order by w.wk)
    into v_weeks
    from (
      select wk,
             (select round(sum(
                 (dc.correct + 0.40 * 12) / (dc.cnt + 12) * 20))::int
                from public.domains d
                cross join lateral (
                  select count(*) as cnt,
                         count(*) filter (where x.correct) as correct
                    from (
                      select e.correct
                        from public.events e
                       where e.user_id = v_target
                         and e.domain_id = d.id
                         and e.type = 'answer'
                         and e.correct is not null
                         and e.server_ts < wk + interval '7 days'
                         and e.server_ts >= wk + interval '7 days'
                                            - interval '45 days'
                       order by e.server_ts desc
                       limit 50) x
                ) dc
             ) as projected,
             (select count(*) from public.events e
               where e.user_id = v_target and e.cohort_id = p_cohort
                 and e.type = 'answer' and e.correct is not null
                 and e.server_ts >= wk
                 and e.server_ts < wk + interval '7 days') as answers,
             (select avg(e.correct::int)::real from public.events e
               where e.user_id = v_target and e.cohort_id = p_cohort
                 and e.type = 'answer' and e.correct is not null
                 and e.server_ts >= wk
                 and e.server_ts < wk + interval '7 days') as accuracy
        from generate_series(
               date_trunc('week', now()) - interval '7 weeks',
               date_trunc('week', now()),
               interval '1 week') wk
    ) w;

  return jsonb_build_object(
    'pass_line', 48,
    'model_version', app.readiness_model_version(),
    'weeks', coalesce(v_weeks, '[]'::jsonb));
end;
$$;
revoke all on function public.student_trend(uuid, text) from public, anon;
grant execute on function public.student_trend(uuid, text) to authenticated;

-- ── assign_domain_practice ──────────────────────────────────────────────────
-- One click from a weakness to an assignment: picks published questions
-- for the domain, creates the measured teaching input (which brings the
-- 7/21-day retention checks for free), opens the immediate phase as an
-- async assessment students can take THIS week, and announces it to the
-- class through the existing push pipeline.
create function public.assign_domain_practice(
  p_cohort uuid,
  p_domain smallint,
  p_count int default 10
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_ids uuid[];
  v_name text;
  v_res jsonb;
  v_input uuid;
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can assign practice';
  end if;

  select array_agg(id) into v_ids from (
    select id from public.questions
     where review_status = 'published'
       and (cohort_id is null or cohort_id = p_cohort)
       and domain_id = p_domain
     order by random()
     limit greatest(p_count, 6)) q;
  if coalesce(array_length(v_ids, 1), 0) < 6 then
    raise exception 'not enough published questions in this domain';
  end if;

  select name into v_name from public.domains where id = p_domain;

  v_res := public.create_teaching_input(
    p_cohort, 'Weak-area practice: ' || v_name, 'bank_set',
    v_ids, current_date, null);
  v_input := (v_res ->> 'input_id')::uuid;

  -- The immediate phase becomes an open async assessment: assignments are
  -- for this week, not for a live classroom moment.
  update public.assessments
     set mode = 'async'
   where input_id = v_input and phase = 'immediate';

  -- Announce through the push pipeline; if its hourly rate limit is hit,
  -- record the announcement anyway. The assignment must never fail
  -- because the class was messaged a lot this hour.
  begin
    perform public.send_class_announcement(
      p_cohort,
      'New practice assigned: ' || v_name
      || '. Open the FCLE tab and drill this domain this week.');
  exception when others then
    insert into public.class_announcements (cohort_id, author, body)
    values (p_cohort, auth.uid(),
            'New practice assigned: ' || v_name
            || '. Open the FCLE tab and drill this domain this week.');
  end;

  return v_res || jsonb_build_object('domain', v_name);
end;
$$;
revoke all on function public.assign_domain_practice(uuid, smallint, int) from public, anon;
grant execute on function public.assign_domain_practice(uuid, smallint, int) to authenticated;
