-- Hold-out enforcement for the server-assembled surfaces. The client-side
-- practice chokepoint cannot defend paths where the SERVER picks the
-- questions, so the exclusions live here:
--   * assemble_mock must never deal a held-out item into a mock;
--   * create_live_session must reject a faculty-selected list containing an
--     item reserved for a scheduled check of that same cohort.
-- Companion to 20260731000100_teaching_loop_attribution.sql.

-- ── Cohort-scoped lock set (faculty-side validation helper) ────────────────
-- locked_question_ids() is caller-scoped (a student's own cohorts); session
-- creation needs the same set for an explicit cohort instead.

create function app.cohort_locked_question_ids(p_cohort uuid)
returns setof uuid
language sql security definer stable set search_path = public, app, pg_temp as $$
  select distinct ii.question_id
    from public.input_items ii
    join public.teaching_inputs ti on ti.id = ii.input_id
    join public.assessments a
      on a.input_id = ii.input_id
     and a.phase = case ii.slice
                     when 'holdout_7'  then 'check_7'
                     when 'holdout_21' then 'check_21'
                   end
   where ii.slice <> 'session'
     and ti.cohort_id = p_cohort
     and now() < a.closes_at;
$$;

-- ── assemble_mock: exclude the caller's held-out items ─────────────────────
-- If exclusions push a domain below 20 the existing "bank too small" error
-- fires and the app falls back to the locally assembled mock, which filters
-- through the same lock set client-side. Better a fallback than a
-- contaminated measurement.

create or replace function public.assemble_mock(p_kind text) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_cohort uuid;
  v_attempt uuid;
  v_ids jsonb := '[]'::jsonb;
  v_questions jsonb := '[]'::jsonb;
  d record;
  picked jsonb;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('baseline', 'practice', 'final') then
    raise exception 'invalid mock kind %', p_kind;
  end if;
  v_cohort := app.current_cohort(v_user);

  for d in select id, code from public.domains order by ordinal loop
    select jsonb_agg(jsonb_build_object(
             'id', q.id, 'domain', d.code, 'stem', q.stem,
             'options', q.options, 'citation', q.citation)
             order by random())
      into picked
      from (
        select *
        from public.questions
        where domain_id = d.id and cohort_id is null
          and review_status = 'published'
          and id not in (select public.locked_question_ids())
        order by random()
        limit 20
      ) q;
    if picked is null or jsonb_array_length(picked) < 20 then
      raise exception 'question bank too small for domain % (need 20)', d.code;
    end if;
    v_questions := v_questions || picked;
    select v_ids || coalesce(jsonb_agg(el -> 'id'), '[]'::jsonb)
      into v_ids from jsonb_array_elements(picked) el;
  end loop;

  insert into public.mock_attempts
    (user_id, cohort_id, kind, question_ids,
     content_version_id)
  values
    (v_user, v_cohort, p_kind, v_ids,
     (select id from public.content_versions order by published_at desc limit 1))
  returning id into v_attempt;

  insert into public.events (event_id, user_id, cohort_id, type, attempt_id, client_ts)
  values (gen_random_uuid(), v_user, v_cohort, 'mock_start', v_attempt, now());

  return jsonb_build_object('attempt_id', v_attempt, 'questions', v_questions);
end;
$$;

-- ── create_live_session: reject reserved items ──────────────────────────────

create or replace function public.create_live_session(
  p_cohort uuid,
  p_title text,
  p_question_ids jsonb,
  p_question_seconds int default 20
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_code text;
  v_count int;
  v_valid int;
  v_locked int;
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  v_count := jsonb_array_length(p_question_ids);
  if v_count is null or v_count < 1 or v_count > 50 then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  -- Every question must be published and either from the system bank or
  -- authored for THIS cohort.
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

  insert into public.live_sessions
    (cohort_id, created_by, title, question_ids, question_seconds)
  values
    (p_cohort, auth.uid(), trim(p_title), p_question_ids, p_question_seconds)
  returning id, join_code into v_id, v_code;

  return jsonb_build_object('id', v_id, 'join_code', v_code,
                            'question_count', v_count);
end;
$$;
