-- Saved live sessions: an instructor prepares a session in advance (its
-- title, its questions, its timer), saves it, and starts it later.
--
-- Until now create_live_session was the only way in, and it opens the
-- lobby at once: a session could not exist without being live. A saved
-- session lives in its own table instead, so nothing about a running
-- session changes and a student can never see, join or be counted in one
-- that has not started. The table sits in the app schema, which no client
-- role can reach; everything goes through the functions below.
--
-- Starting a saved session calls create_live_session with what was saved.
-- Every rule that guards a live session is therefore applied at START
-- time, with the question bank and the hold-out locks as they are then,
-- not as they were when it was saved. A saved session that can no longer
-- be started says why and stays saved.
--
-- Access: TA or above of the class, the same gate as creating a session,
-- so co-instructors share one list. Students have no access at all.

create table app.live_session_drafts (
  id               uuid primary key default gen_random_uuid(),
  cohort_id        uuid not null references public.cohorts (id) on delete cascade,
  created_by       uuid not null references public.profiles (id),
  title            text not null
                     check (length(trim(title)) between 3 and 80)
                     check (not public.has_course_identifier(title)),
  question_ids     jsonb not null
                     check (jsonb_typeof(question_ids) = 'array'
                            and jsonb_array_length(question_ids) between 1 and 50),
  question_seconds int not null default 20
                     check (question_seconds between 5 and 120),
  allow_guests     boolean not null default false,
  -- When the instructor means to run it. A label for the list; nothing
  -- starts by itself.
  planned_for      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- Set when it is started; the saved copy is kept so the same session
  -- can be found again.
  started_session  uuid references public.live_sessions (id) on delete set null,
  started_at       timestamptz
);
create index live_session_drafts_cohort_idx
  on app.live_session_drafts (cohort_id, started_at, planned_for);
-- Read and written only through the RPCs below.
alter table app.live_session_drafts enable row level security;

-- How many of a saved session's questions are reserved right now for one of
-- the class's scheduled retention checks. Such a session cannot be started
-- until the check closes or the questions are swapped.
create function app.draft_locked_count(p_cohort uuid, p_question_ids jsonb)
returns int
language sql stable security definer set search_path = public, app, pg_temp as $$
  select count(*)::int
    from jsonb_array_elements_text(p_question_ids) qid
   where qid::uuid in (select app.cohort_locked_question_ids(p_cohort));
$$;
revoke all on function app.draft_locked_count(uuid, jsonb)
  from public, anon, authenticated;

-- ── save (create or edit) ───────────────────────────────────────────────────
-- With [p_draft] null a new saved session is created; otherwise that one is
-- replaced with what is passed. Returns
--   {"id", "question_count", "locked_now"}
-- locked_now is how many of its questions are reserved today (see above):
-- the session is saved anyway, since the reservation may have lifted by
-- the time it is run, but the form should say so.
create function public.save_live_session_draft(
  p_cohort uuid,
  p_title text,
  p_question_ids jsonb,
  p_question_seconds int default 20,
  p_allow_guests boolean default false,
  p_planned_for timestamptz default null,
  p_draft uuid default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_count int;
  v_valid int;
  v_id uuid;
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  if length(v_title) < 3 or length(v_title) > 80 then
    raise exception 'the title must be 3 to 80 characters';
  end if;
  if public.has_course_identifier(v_title) then
    raise exception 'the title cannot contain a course number';
  end if;
  if p_question_ids is null or jsonb_typeof(p_question_ids) <> 'array' then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  v_count := jsonb_array_length(p_question_ids);
  if v_count < 1 or v_count > 50 then
    raise exception 'a session needs 1 to 50 questions';
  end if;
  if p_question_seconds is null or p_question_seconds < 5
     or p_question_seconds > 120 then
    raise exception 'the timer must be 5 to 120 seconds';
  end if;
  select count(distinct q.id) into v_valid
    from jsonb_array_elements_text(p_question_ids) qid
    join public.questions q on q.id::text = qid
   where q.review_status = 'published'
     and (q.cohort_id is null or q.cohort_id = p_cohort);
  if v_valid <> v_count then
    raise exception
      'question list contains unknown, unpublished, repeated, or foreign-cohort questions';
  end if;

  if p_draft is null then
    insert into app.live_session_drafts
      (cohort_id, created_by, title, question_ids, question_seconds,
       allow_guests, planned_for)
    values
      (p_cohort, auth.uid(), v_title, p_question_ids, p_question_seconds,
       coalesce(p_allow_guests, false), p_planned_for)
    returning id into v_id;
  else
    update app.live_session_drafts
       set title = v_title,
           question_ids = p_question_ids,
           question_seconds = p_question_seconds,
           allow_guests = coalesce(p_allow_guests, false),
           planned_for = p_planned_for,
           updated_at = now()
     where id = p_draft and cohort_id = p_cohort and started_at is null
    returning id into v_id;
    if v_id is null then
      raise exception 'no such saved session, or it was already started';
    end if;
  end if;

  return jsonb_build_object(
    'id', v_id,
    'question_count', v_count,
    'locked_now', app.draft_locked_count(p_cohort, p_question_ids));
end;
$$;
revoke all on function public.save_live_session_draft(
  uuid, text, jsonb, int, boolean, timestamptz, uuid) from public, anon;
grant execute on function public.save_live_session_draft(
  uuid, text, jsonb, int, boolean, timestamptz, uuid) to authenticated;

-- ── list ────────────────────────────────────────────────────────────────────
-- The class's saved sessions that have not been started, the planned ones
-- first in the order they are planned, then the rest by when they were
-- last edited. With [p_include_started] the started ones follow, newest
-- first. Each row:
--   {"id", "title", "question_ids", "question_count", "question_seconds",
--    "allow_guests", "planned_for", "created_at", "updated_at",
--    "created_by", "locked_now", "started_at", "started_session"}
create function public.live_session_drafts(
  p_cohort uuid,
  p_include_started boolean default false
) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
begin
  if not app.is_cohort_ta_or_above(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id,
             'title', d.title,
             'question_ids', d.question_ids,
             'question_count', jsonb_array_length(d.question_ids),
             'question_seconds', d.question_seconds,
             'allow_guests', d.allow_guests,
             'planned_for', d.planned_for,
             'created_at', d.created_at,
             'updated_at', d.updated_at,
             'created_by', p.handle,
             'locked_now', case when d.started_at is null
                                then app.draft_locked_count(d.cohort_id, d.question_ids)
                                else 0 end,
             'started_at', d.started_at,
             'started_session', d.started_session)
           order by (d.started_at is not null),
                    d.started_at desc,
                    d.planned_for asc nulls last,
                    d.updated_at desc)
      from app.live_session_drafts d
      left join public.profiles p on p.id = d.created_by
     where d.cohort_id = p_cohort
       and (coalesce(p_include_started, false) or d.started_at is null)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.live_session_drafts(uuid, boolean)
  from public, anon;
grant execute on function public.live_session_drafts(uuid, boolean)
  to authenticated;

-- ── delete ──────────────────────────────────────────────────────────────────
-- Removes a saved session. A live session that was started from it is not
-- touched.
create function public.delete_live_session_draft(p_draft uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_cohort uuid;
begin
  select cohort_id into v_cohort
    from app.live_session_drafts where id = p_draft;
  if v_cohort is null then raise exception 'no such saved session'; end if;
  if not app.is_cohort_ta_or_above(v_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  delete from app.live_session_drafts where id = p_draft;
end;
$$;
revoke all on function public.delete_live_session_draft(uuid)
  from public, anon;
grant execute on function public.delete_live_session_draft(uuid)
  to authenticated;

-- ── start ───────────────────────────────────────────────────────────────────
-- Opens the lobby for a saved session. Returns what create_live_session
-- returns, plus the saved session's id:
--   {"id", "join_code", "question_count", "draft_id"}
-- It goes through create_live_session, so a question that has since been
-- unpublished, or reserved for a retention check, stops the start with
-- that function's own message and the session stays saved. The row lock
-- means two instructors pressing Start at the same moment open one lobby,
-- not two; the second is told it was already started.
create function public.start_live_session_draft(p_draft uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  d app.live_session_drafts%rowtype;
  v_session jsonb;
begin
  select * into d from app.live_session_drafts
   where id = p_draft for update;
  if not found then raise exception 'no such saved session'; end if;
  if not app.is_cohort_ta_or_above(d.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  if d.started_at is not null then
    raise exception 'this saved session was already started';
  end if;

  v_session := public.create_live_session(
    d.cohort_id, d.title, d.question_ids, d.question_seconds, d.allow_guests);

  update app.live_session_drafts
     set started_session = (v_session ->> 'id')::uuid,
         started_at = now()
   where id = p_draft;

  return v_session || jsonb_build_object('draft_id', p_draft);
end;
$$;
revoke all on function public.start_live_session_draft(uuid)
  from public, anon;
grant execute on function public.start_live_session_draft(uuid)
  to authenticated;
