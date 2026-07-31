-- Teaching loop attribution: instructor-selected inputs, measurement
-- assessments at immediate/+7/+21 days, hold-out slices the practice
-- surfaces must not touch, and a per-cohort reporting policy.
--
-- Design doc: docs/superpowers/specs/2026-07-31-teaching-loop-attribution-design.md
-- Additive only: new tables, two nullable FK columns, three cohort columns.
--
-- Measurement honesty invariants encoded here, not in app code:
--   * hold-out slices are assigned server-side, at creation, before any
--     student can see the input (defensible against "you cherry-picked");
--   * students can never read input_items (the hold-out list is secret);
--   * an assessment is invisible to students until it opens;
--   * check answers grade through the same submit_answer path as everything
--     else, so `correct` stays server-authoritative.

-- ── Tables ──────────────────────────────────────────────────────────────────

create table public.teaching_inputs (
  id          uuid primary key default gen_random_uuid(),
  cohort_id   uuid not null references public.cohorts (id) on delete cascade,
  created_by  uuid not null references public.profiles (id),
  title       text not null check (length(trim(title)) between 3 and 120),
  kind        text not null check (kind in ('bank_set', 'custom_quiz', 'mixed')),
  taught_on   date not null,
  created_at  timestamptz not null default now()
);
create index teaching_inputs_cohort_idx
  on public.teaching_inputs (cohort_id, taught_on desc);

create table public.input_items (
  input_id    uuid not null references public.teaching_inputs (id) on delete cascade,
  question_id uuid not null references public.questions (id),
  slice       text not null check (slice in ('session', 'holdout_7', 'holdout_21')),
  primary key (input_id, question_id)
);
create index input_items_question_idx on public.input_items (question_id);

create table public.assessments (
  id              uuid primary key default gen_random_uuid(),
  input_id        uuid not null references public.teaching_inputs (id) on delete cascade,
  cohort_id       uuid not null references public.cohorts (id) on delete cascade,
  phase           text not null check (phase in ('immediate', 'check_7', 'check_21')),
  mode            text not null default 'async' check (mode in ('live', 'async')),
  live_session_id uuid references public.live_sessions (id),
  -- Snapshot of the question ids this assessment delivers (the slice as of
  -- creation). Checks read THIS, not input_items, so a later edit to an
  -- input can never silently change what a check measured.
  question_ids    jsonb not null,
  opens_at        timestamptz not null,
  closes_at       timestamptz not null,
  created_at      timestamptz not null default now(),
  unique (input_id, phase),
  check (closes_at > opens_at)
);
create index assessments_cohort_open_idx
  on public.assessments (cohort_id, opens_at, closes_at);

-- ── Spine changes ───────────────────────────────────────────────────────────

alter table public.events
  add column assessment_id uuid references public.assessments (id);
create index events_assessment_idx
  on public.events (assessment_id) where assessment_id is not null;

alter table public.live_sessions
  add column input_id uuid references public.teaching_inputs (id);

-- ── Reporting policy (per cohort; disclosure, not collection) ──────────────
-- Full-resolution events are always collected; these gate what the faculty
-- report RPCs disclose. Server-enforced: clients never filter.

alter table public.cohorts
  add column reporting_resolution text not null default 'per_student'
    check (reporting_resolution in ('per_student', 'pseudonymous', 'aggregate_only')),
  add column identity_display text not null default 'roster'
    check (identity_display in ('roster', 'display_name', 'pseudonym')),
  add column raw_retention_days int
    check (raw_retention_days is null or raw_retention_days >= 30);

-- ── RLS ─────────────────────────────────────────────────────────────────────

alter table public.teaching_inputs enable row level security;
alter table public.input_items     enable row level security;
alter table public.assessments     enable row level security;

grant select on public.teaching_inputs to authenticated;
grant select on public.input_items     to authenticated;
grant select on public.assessments     to authenticated;

-- Faculty see their cohorts' inputs and item slices. Students see neither:
-- the hold-out list must stay unknowable before its check.
create policy teaching_inputs_faculty_read on public.teaching_inputs
  for select using (app.is_cohort_faculty(cohort_id));

create policy input_items_faculty_read on public.input_items
  for select using (exists (
    select 1 from public.teaching_inputs ti
    where ti.id = input_id and app.is_cohort_faculty(ti.cohort_id)));

-- Faculty always see assessments; students only once open (a future check's
-- question snapshot is invisible until opens_at).
create policy assessments_faculty_read on public.assessments
  for select using (app.is_cohort_faculty(cohort_id));

create policy assessments_student_read_when_open on public.assessments
  for select using (
    app.is_cohort_member(cohort_id) and opens_at <= now());

-- All writes go through security-definer RPCs below; no direct
-- insert/update/delete grants for any client role.

-- ── RPC: create_teaching_input ──────────────────────────────────────────────
-- Faculty-only. Validates the item set, assigns hold-out slices by server-
-- side shuffle, and creates the input, its items, and all three assessments
-- in one transaction. Check windows: opens at the day boundary, stays open
-- four days so a student who misses a class can still complete it.

create function public.create_teaching_input(
  p_cohort_id    uuid,
  p_title        text,
  p_kind         text,
  p_question_ids uuid[],
  p_taught_on    date default current_date,
  p_holdout_each int default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_n int;
  v_holdout int;
  v_input uuid;
  v_shuffled uuid[];
  v_session_ids uuid[];
  v_h7_ids uuid[];
  v_h21_ids uuid[];
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if not app.is_cohort_faculty(p_cohort_id) then
    raise exception 'faculty only';
  end if;
  if p_kind not in ('bank_set', 'custom_quiz', 'mixed') then
    raise exception 'bad kind';
  end if;

  select array_agg(distinct q) into v_shuffled from unnest(p_question_ids) q;
  v_n := coalesce(array_length(v_shuffled, 1), 0);
  if v_n < 6 then
    raise exception 'need at least 6 questions (got %)', v_n;
  end if;

  -- Every id must be a published question this cohort can see.
  if exists (
    select 1 from unnest(v_shuffled) qid
    left join public.questions q on q.id = qid
    where q.id is null or q.review_status <> 'published'
       or (q.cohort_id is not null and q.cohort_id <> p_cohort_id)
  ) then
    raise exception 'question set contains unavailable items';
  end if;

  -- Default hold-out: a fifth of the set per check, at least 2, and the
  -- session slice always keeps at least half.
  v_holdout := coalesce(p_holdout_each, greatest(2, v_n / 5));
  if v_holdout < 1 or (v_n - 2 * v_holdout) < (v_n + 1) / 2 then
    raise exception 'holdout size % does not leave enough session items', v_holdout;
  end if;

  -- Server-side shuffle, then slice. Assigned before any student can see
  -- the input: this is the line that makes the 7/21-day numbers defensible.
  select array_agg(q order by random()) into v_shuffled
    from unnest(v_shuffled) q;
  v_h7_ids      := v_shuffled[1 : v_holdout];
  v_h21_ids     := v_shuffled[v_holdout + 1 : 2 * v_holdout];
  v_session_ids := v_shuffled[2 * v_holdout + 1 : v_n];

  insert into public.teaching_inputs (cohort_id, created_by, title, kind, taught_on)
  values (p_cohort_id, v_user, trim(p_title), p_kind, p_taught_on)
  returning id into v_input;

  insert into public.input_items (input_id, question_id, slice)
  select v_input, q, 'session'   from unnest(v_session_ids) q union all
  select v_input, q, 'holdout_7' from unnest(v_h7_ids) q      union all
  select v_input, q, 'holdout_21' from unnest(v_h21_ids) q;

  insert into public.assessments
    (input_id, cohort_id, phase, mode, question_ids, opens_at, closes_at)
  values
    (v_input, p_cohort_id, 'immediate', 'live',
     to_jsonb(v_session_ids), p_taught_on::timestamptz,
     (p_taught_on + 2)::timestamptz),
    (v_input, p_cohort_id, 'check_7', 'async',
     to_jsonb(v_h7_ids), (p_taught_on + 7)::timestamptz,
     (p_taught_on + 11)::timestamptz),
    (v_input, p_cohort_id, 'check_21', 'async',
     to_jsonb(v_h21_ids), (p_taught_on + 21)::timestamptz,
     (p_taught_on + 25)::timestamptz);

  return jsonb_build_object(
    'input_id', v_input,
    'session_count', coalesce(array_length(v_session_ids, 1), 0),
    'holdout_each', v_holdout);
end;
$$;

revoke execute on function
  public.create_teaching_input(uuid, text, text, uuid[], date, int)
  from public, anon;
grant execute on function
  public.create_teaching_input(uuid, text, text, uuid[], date, int)
  to authenticated;

-- ── RPC: locked_question_ids ────────────────────────────────────────────────
-- The hold-out chokepoint, student side: every question currently reserved
-- from the caller's practice surfaces. An item is locked from input creation
-- until its check CLOSES; while the check is open it is still locked for
-- practice (the check delivery path reads assessments.question_ids directly
-- and is the one legitimate surface).

create function public.locked_question_ids()
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
     and app.is_cohort_member(ti.cohort_id)
     and now() < a.closes_at;
$$;

revoke execute on function public.locked_question_ids() from public, anon;
grant execute on function public.locked_question_ids() to authenticated;

-- ── RPC: get_open_assessments ───────────────────────────────────────────────
-- The caller's currently-open async checks with their own progress, so the
-- client can prompt "your 7-day check is open" and resume partial work.

create function public.get_open_assessments()
returns table (
  assessment_id uuid,
  input_title   text,
  phase         text,
  question_ids  jsonb,
  opens_at      timestamptz,
  closes_at     timestamptz,
  answered      int
)
language sql security definer stable set search_path = public, app, pg_temp as $$
  select a.id, ti.title, a.phase, a.question_ids, a.opens_at, a.closes_at,
         (select count(*)::int from public.events e
           where e.assessment_id = a.id and e.user_id = auth.uid()
             and e.type = 'answer')
    from public.assessments a
    join public.teaching_inputs ti on ti.id = a.input_id
   where a.mode = 'async'
     and app.is_cohort_member(a.cohort_id)
     and a.opens_at <= now() and now() < a.closes_at;
$$;

revoke execute on function public.get_open_assessments() from public, anon;
grant execute on function public.get_open_assessments() to authenticated;

-- ── submit_answer gains an assessment reference ─────────────────────────────
-- Same name, one new trailing default parameter: existing clients calling
-- the 6-argument shape keep working (the default fills in), and there is
-- exactly one grading code path. The old 6-parameter overload is dropped so
-- grading logic cannot fork.

drop function public.submit_answer(uuid, uuid, text, timestamptz, text, uuid);

create function public.submit_answer(
  p_event_id      uuid,
  p_question_id   uuid,
  p_chosen_key    text,
  p_client_ts     timestamptz,
  p_device_id     text default null,
  p_attempt_id    uuid default null,
  p_assessment_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_user uuid := auth.uid();
  v_q record;
  v_key record;
  v_cohort uuid;
  v_correct boolean;
  v_existing record;
  v_assessment record;
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  -- Idempotent replay: return the stored grading.
  select e.correct, e.question_id into v_existing
    from public.events e where e.event_id = p_event_id;
  if found then
    select k.answer_key, k.explanation into v_key
      from app.question_keys k where k.question_id = v_existing.question_id;
    return jsonb_build_object(
      'correct', v_existing.correct,
      'answer_key', v_key.answer_key,
      'explanation', v_key.explanation,
      'replay', true);
  end if;

  select q.id, q.domain_id, q.cohort_id, q.review_status into v_q
    from public.questions q where q.id = p_question_id;
  if v_q.id is null or v_q.review_status <> 'published'
     or (v_q.cohort_id is not null and not app.is_cohort_member(v_q.cohort_id)) then
    raise exception 'question not available';
  end if;

  select k.answer_key, k.explanation into v_key
    from app.question_keys k where k.question_id = p_question_id;
  if v_key.answer_key is null then
    raise exception 'question has no answer key';
  end if;

  if p_assessment_id is not null then
    -- A check answer must land inside an open assessment the caller belongs
    -- to, on a question that assessment actually snapshotted.
    select a.cohort_id, a.opens_at, a.closes_at, a.question_ids
      into v_assessment
      from public.assessments a where a.id = p_assessment_id;
    if v_assessment.cohort_id is null
       or not app.is_cohort_member(v_assessment.cohort_id)
       or now() < v_assessment.opens_at
       or now() >= v_assessment.closes_at
       or not (v_assessment.question_ids @> to_jsonb(p_question_id::text)) then
      raise exception 'assessment not open for this question';
    end if;
    v_cohort := v_assessment.cohort_id;
  elsif p_attempt_id is not null then
    perform 1 from public.mock_attempts a
      where a.id = p_attempt_id and a.user_id = v_user
        and a.completed_at is null
        and a.question_ids @> to_jsonb(p_question_id::text);
    if not found then raise exception 'invalid or completed mock attempt'; end if;
    select a.cohort_id into v_cohort from public.mock_attempts a where a.id = p_attempt_id;
  else
    v_cohort := app.current_cohort(v_user);
  end if;

  v_correct := (p_chosen_key = v_key.answer_key);

  insert into public.events
    (event_id, user_id, cohort_id, type, question_id, attempt_id,
     assessment_id, domain_id, chosen_key, correct, client_ts, device_id)
  values
    (p_event_id, v_user, v_cohort, 'answer', p_question_id, p_attempt_id,
     p_assessment_id, v_q.domain_id, p_chosen_key, v_correct, p_client_ts,
     p_device_id);

  perform app.apply_graded_event(
    v_user, v_cohort, p_question_id, v_q.domain_id,
    case when v_correct then 2 else 0 end, v_correct, now());

  return jsonb_build_object(
    'correct', v_correct,
    'answer_key', v_key.answer_key,
    'explanation', v_key.explanation,
    'replay', false);
end;
$$;

revoke execute on function
  public.submit_answer(uuid, uuid, text, timestamptz, text, uuid, uuid)
  from public, anon;
grant execute on function
  public.submit_answer(uuid, uuid, text, timestamptz, text, uuid, uuid)
  to authenticated;
