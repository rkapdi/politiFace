-- Wire the per-cohort reporting policy (20260731000100) into every RPC
-- that returns student-level rows. Server-enforced; clients never filter.
-- TAs are always capped at aggregate_only regardless of cohort policy.
-- Exports leave an audit trail in app.export_log.

-- ── chokepoint ──────────────────────────────────────────────────────────────
create function app.effective_resolution(p_cohort uuid) returns text
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  v_role text;
  v_res  text;
begin
  select role into v_role from public.cohort_members
   where cohort_id = p_cohort and user_id = auth.uid();
  if v_role is null and app.is_admin(auth.uid()) then
    v_role := 'faculty';  -- admins audit at the cohort's own policy level
  end if;
  if v_role is null or v_role = 'student' then
    raise exception 'not faculty of this cohort';
  end if;
  if v_role = 'ta' then return 'aggregate_only'; end if;
  select reporting_resolution into v_res from public.cohorts where id = p_cohort;
  return v_res;
end;
$$;

-- Deterministic per cohort and user, so a student keeps one label across
-- every surface, but labels never correlate across cohorts.
create function app.pseudonym_for(p_cohort uuid, p_user uuid) returns text
language sql immutable as $$
  select 'Student ' ||
         upper(substr(md5(p_cohort::text || ':' || p_user::text || ':pf1'), 1, 6));
$$;

create function app.identity_label(
  p_cohort uuid, p_user uuid, p_roster text, p_handle text
) returns text
language sql stable security definer set search_path = public, app, pg_temp as $$
  select case (select identity_display from public.cohorts where id = p_cohort)
           when 'roster'       then coalesce(p_roster, p_handle)
           when 'display_name' then p_handle
           else app.pseudonym_for(p_cohort, p_user)
         end;
$$;

-- ── policy management ───────────────────────────────────────────────────────
create function public.set_reporting_policy(
  p_cohort uuid,
  p_resolution text,
  p_identity_display text,
  p_retention_days int default null
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not exists (
    select 1 from public.cohort_members
     where cohort_id = p_cohort and user_id = auth.uid() and role = 'faculty'
  ) then
    raise exception 'only this class'' faculty can change reporting policy';
  end if;
  update public.cohorts
     set reporting_resolution = p_resolution,
         identity_display     = p_identity_display,
         raw_retention_days   = p_retention_days
   where id = p_cohort;
  -- Column checks from 20260731000100 validate the values.
end;
$$;
revoke all on function public.set_reporting_policy(uuid, text, text, int) from public, anon;
grant execute on function public.set_reporting_policy(uuid, text, text, int) to authenticated;

create function public.get_reporting_policy(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare c record;
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  select reporting_resolution, identity_display, raw_retention_days
    into c from public.cohorts where id = p_cohort;
  return jsonb_build_object(
    'resolution', c.reporting_resolution,
    'identity_display', c.identity_display,
    'raw_retention_days', c.raw_retention_days,
    'effective', app.effective_resolution(p_cohort));
end;
$$;
revoke all on function public.get_reporting_policy(uuid) from public, anon;
grant execute on function public.get_reporting_policy(uuid) to authenticated;

-- ── export audit trail ──────────────────────────────────────────────────────
create table app.export_log (
  id         bigint generated always as identity primary key,
  user_id    uuid not null,
  cohort_id  uuid not null,
  kind       text not null check (kind in
    ('csv_progress', 'csv_at_risk', 'csv_drilldown', 'one_pager', 'session_report')),
  created_at timestamptz not null default now()
);

create function public.log_report_export(p_cohort uuid, p_kind text) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) and not app.is_admin(auth.uid()) then
    raise exception 'not faculty of this cohort';
  end if;
  insert into app.export_log (user_id, cohort_id, kind)
  values (auth.uid(), p_cohort, p_kind);
end;
$$;
revoke all on function public.log_report_export(uuid, text) from public, anon;
grant execute on function public.log_report_export(uuid, text) to authenticated;

-- ── policy-aware recreation: live_session_report ────────────────────────────
-- Base body from 20260723000200:223. Deltas: the gate goes through
-- app.effective_resolution, identity columns follow the resolution, and a
-- student_ref column is appended (the drill-down key the web app passes
-- back). Return type changes, so drop first.
drop function public.live_session_report(uuid);
create function public.live_session_report(p_session uuid)
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
           coalesce(sum(case when a.correct then
             100 + round(50.0 * (1 - a.answer_ms::numeric
                   / (s.question_seconds * 1000)))
           else 0 end), 0)::bigint as score,
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
revoke all on function public.live_session_report(uuid) from public, anon;
grant execute on function public.live_session_report(uuid) to authenticated;

-- ── policy-aware recreation: cohort_student_progress ────────────────────────
-- Base body from 20260723000200:273. Same deltas as above.
drop function public.cohort_student_progress(uuid);
create function public.cohort_student_progress(p_cohort uuid)
returns table (
  user_id uuid,
  roster_name text,
  handle text,
  last_active timestamptz,
  answers_total bigint,
  accuracy real,
  mocks_completed bigint,
  best_mock_score smallint,
  student_ref text
)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare v_res text;
begin
  v_res := app.effective_resolution(p_cohort);
  if v_res = 'aggregate_only' then
    raise exception 'this class reports aggregate data only';
  end if;
  return query
    select case when v_res = 'per_student' then m.user_id end,
           case when v_res = 'per_student'
                then app.identity_label(p_cohort, m.user_id,
                                        m.roster_name, p.handle)
                else app.pseudonym_for(p_cohort, m.user_id) end,
           case when v_res = 'per_student' then p.handle
                else app.pseudonym_for(p_cohort, m.user_id) end,
           max(e.server_ts) as last_active,
           count(e.event_id) filter
             (where e.type = 'answer' and e.correct is not null) as answers_total,
           coalesce(avg(e.correct::int) filter
             (where e.type = 'answer' and e.correct is not null), 0)::real
             as accuracy,
           (select count(*) from public.mock_attempts a
             where a.user_id = m.user_id and a.cohort_id = p_cohort
               and a.completed_at is not null) as mocks_completed,
           (select max(a.score) from public.mock_attempts a
             where a.user_id = m.user_id and a.cohort_id = p_cohort
               and a.completed_at is not null) as best_mock_score,
           case when v_res = 'per_student' then m.user_id::text
                else app.pseudonym_for(p_cohort, m.user_id) end
      from public.cohort_members m
      join public.profiles p on p.id = m.user_id
      left join public.events e
        on e.user_id = m.user_id and e.cohort_id = p_cohort
     where m.cohort_id = p_cohort and m.role = 'student'
     group by m.user_id, m.roster_name, p.handle
     order by last_active asc nulls first;
end;
$$;
revoke all on function public.cohort_student_progress(uuid) from public, anon;
grant execute on function public.cohort_student_progress(uuid) to authenticated;
