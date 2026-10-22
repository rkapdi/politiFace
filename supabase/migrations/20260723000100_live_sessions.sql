-- Live class sessions: the in-classroom game.
--
-- A faculty member composes a session from published questions (system
-- bank and their own cohort-scoped questions), starts it, and drives the
-- phase machine: lobby -> question -> reveal -> ... -> ended. Students in
-- the cohort join, answer within the countdown, and see standings at each
-- reveal. Phase changes fan out over Realtime (clients also poll as a
-- fallback); answers grade server-side against app.question_keys, which
-- stays client-unreadable. Timing is server-owned: answer latency is
-- computed from question_started_at, never trusted from the device.
--
-- Scoring: 100 per correct answer plus a speed bonus of up to 50,
-- linear in remaining time. One answer per student per question; the
-- first one is final.

-- ── tables ──────────────────────────────────────────────────────────────────

create table public.live_sessions (
  id                  uuid primary key default gen_random_uuid(),
  cohort_id           uuid not null references public.cohorts (id) on delete cascade,
  created_by          uuid not null references public.profiles (id),
  title               text not null check (length(trim(title)) between 3 and 80),
  question_ids        jsonb not null,
  join_code           text unique not null default app.gen_join_code(),
  status              text not null default 'lobby'
                      check (status in ('lobby', 'question', 'reveal', 'ended')),
  current_index       int not null default -1,
  question_seconds    int not null default 20 check (question_seconds between 5 and 120),
  question_started_at timestamptz,
  created_at          timestamptz not null default now(),
  ended_at            timestamptz
);

create index live_sessions_cohort_idx on public.live_sessions (cohort_id, status);

create table public.live_answers (
  session_id  uuid not null references public.live_sessions (id) on delete cascade,
  question_id uuid not null references public.questions (id),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  chosen_key  text not null,
  correct     boolean not null,
  answer_ms   int not null check (answer_ms >= 0),
  created_at  timestamptz not null default now(),
  primary key (session_id, question_id, user_id)
);

create index live_answers_session_idx on public.live_answers (session_id, question_id);

-- ── RLS ─────────────────────────────────────────────────────────────────────
-- Students read their session row (Realtime phase updates) but never write
-- it; answers are RPC-only. Faculty additionally stream answer inserts for
-- the live counter.

alter table public.live_sessions enable row level security;
alter table public.live_answers enable row level security;

create policy live_sessions_select_members on public.live_sessions
  for select to authenticated
  using (app.is_cohort_member(cohort_id));

create policy live_answers_select_own on public.live_answers
  for select to authenticated using (user_id = auth.uid());

create policy live_answers_select_faculty on public.live_answers
  for select to authenticated
  using (app.is_cohort_faculty(
    (select s.cohort_id from public.live_sessions s where s.id = session_id)
  ));

grant select on public.live_sessions to authenticated;
grant select on public.live_answers to authenticated;

-- Realtime fan-out (guarded: the publication exists on hosted Supabase,
-- not in the throwaway test cluster).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.live_sessions;
    alter publication supabase_realtime add table public.live_answers;
  end if;
end $$;

-- ── faculty: compose and drive ──────────────────────────────────────────────

create function public.create_live_session(
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

  insert into public.live_sessions
    (cohort_id, created_by, title, question_ids, question_seconds)
  values
    (p_cohort, auth.uid(), trim(p_title), p_question_ids, p_question_seconds)
  returning id, join_code into v_id, v_code;

  return jsonb_build_object('id', v_id, 'join_code', v_code,
                            'question_count', v_count);
end;
$$;

-- Drives the phase machine forward one step:
--   lobby -> question(0); question(i) -> reveal(i);
--   reveal(i) -> question(i+1), or ended after the last reveal.
create function public.advance_live_session(p_session uuid) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_total int;
begin
  select * into s from public.live_sessions where id = p_session for update;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  v_total := jsonb_array_length(s.question_ids);

  if s.status = 'ended' then
    raise exception 'session already ended';
  elsif s.status in ('lobby', 'reveal') then
    if s.current_index + 1 >= v_total then
      update public.live_sessions
         set status = 'ended', ended_at = now(), question_started_at = null
       where id = p_session;
      return jsonb_build_object('status', 'ended');
    end if;
    update public.live_sessions
       set status = 'question', current_index = s.current_index + 1,
           question_started_at = now()
     where id = p_session;
    return jsonb_build_object('status', 'question',
                              'index', s.current_index + 1,
                              'total', v_total);
  else -- 'question'
    update public.live_sessions
       set status = 'reveal', question_started_at = null
     where id = p_session;
    return jsonb_build_object('status', 'reveal', 'index', s.current_index,
                              'total', v_total);
  end if;
end;
$$;

create function public.end_live_session(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(v_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  update public.live_sessions
     set status = 'ended', ended_at = coalesce(ended_at, now()),
         question_started_at = null
   where id = p_session;
end;
$$;

-- ── students: join, fetch, answer ───────────────────────────────────────────

-- The CLASS screen banner: the cohort's joinable session, if any.
create function public.active_live_session(p_cohort uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s record;
begin
  if not app.is_cohort_member(p_cohort) then
    raise exception 'not a member of this cohort';
  end if;
  select id, title, status, join_code into s
    from public.live_sessions
   where cohort_id = p_cohort and status <> 'ended'
   order by created_at desc limit 1;
  if not found then return null; end if;
  return jsonb_build_object('id', s.id, 'title', s.title,
                            'status', s.status);
end;
$$;

create function public.join_live_session(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s record;
begin
  select * into s from public.live_sessions
   where join_code = upper(trim(p_code)) and status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'join the class first';
  end if;
  return jsonb_build_object(
    'id', s.id, 'title', s.title, 'status', s.status,
    'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds);
end;
$$;

-- The current question, key-free. Members only; question or reveal phase.
create function public.get_live_question(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  q record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status not in ('question', 'reveal') then
    return jsonb_build_object('status', s.status);
  end if;
  select id, stem, options into q from public.questions
   where id = (s.question_ids ->> s.current_index)::uuid;
  return jsonb_build_object(
    'status', s.status, 'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds,
    'started_at', s.question_started_at,
    'question', jsonb_build_object(
      'id', q.id, 'stem', q.stem, 'options', q.options));
end;
$$;

create function public.submit_live_answer(
  p_session uuid,
  p_question uuid,
  p_key text
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_key text;
  v_ms int;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status <> 'question'
     or (s.question_ids ->> s.current_index)::uuid <> p_question then
    raise exception 'question is not open';
  end if;
  -- Server-owned latency, with a 2s grace over the countdown.
  v_ms := (extract(epoch from (now() - s.question_started_at)) * 1000)::int;
  if v_ms > (s.question_seconds + 2) * 1000 then
    raise exception 'time is up';
  end if;
  v_ms := least(v_ms, s.question_seconds * 1000);

  select answer_key into v_key from app.question_keys
   where question_id = p_question;
  if v_key is null then raise exception 'question has no key'; end if;

  insert into public.live_answers
    (session_id, question_id, user_id, chosen_key, correct, answer_ms)
  values
    (p_session, p_question, auth.uid(), p_key, p_key = v_key, v_ms)
  on conflict (session_id, question_id, user_id) do nothing;

  -- Correctness is not returned: nobody learns the answer before reveal.
  return jsonb_build_object('accepted', true);
end;
$$;

-- ── reveal + standings ──────────────────────────────────────────────────────

-- Correct key and per-option counts for the current question. Members,
-- reveal phase only (faculty may look any time).
create function public.live_reveal(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  v_q uuid;
  v_key text;
  v_counts jsonb;
  v_expl text;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status <> 'reveal' and not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'not in reveal';
  end if;
  v_q := (s.question_ids ->> s.current_index)::uuid;
  select answer_key, explanation into v_key, v_expl
    from app.question_keys where question_id = v_q;
  select coalesce(jsonb_object_agg(chosen_key, n), '{}'::jsonb) into v_counts
    from (select chosen_key, count(*) as n from public.live_answers
           where session_id = p_session and question_id = v_q
           group by chosen_key) c;
  return jsonb_build_object('question_id', v_q, 'correct_key', v_key,
                            'explanation', v_expl, 'counts', v_counts);
end;
$$;

-- Standings: 100 per correct + up to 50 speed bonus, ranked. Members in
-- reveal/ended; faculty any time.
create function public.live_scoreboard(p_session uuid)
returns table (rank bigint, handle text, score bigint, correct_count bigint, is_me boolean)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_member(s.cohort_id) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status = 'question' and not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'standings arrive at the reveal';
  end if;
  return query
    select row_number() over (order by t.score desc, t.total_ms asc) as rank,
           p.handle, t.score, t.correct_count,
           (t.user_id = auth.uid()) as is_me
      from (
        select a.user_id,
               sum(case when a.correct then
                     100 + round(50.0 * (1 - a.answer_ms::numeric
                           / (s.question_seconds * 1000)))
                   else 0 end)::bigint as score,
               count(*) filter (where a.correct) as correct_count,
               sum(a.answer_ms)::bigint as total_ms
          from public.live_answers a
         where a.session_id = p_session
         group by a.user_id) t
      join public.profiles p on p.id = t.user_id
     order by t.score desc, t.total_ms asc
     limit 50;
end;
$$;

-- Faculty wrap-up: per-question correct rates, worst first.
create function public.live_session_stats(p_session uuid)
returns table (question_id uuid, stem text, answered bigint, correct_rate real)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not app.is_cohort_faculty(s.cohort_id) then
    raise exception 'not faculty of this cohort';
  end if;
  return query
    select q.id, q.stem, count(a.user_id) as answered,
           coalesce(avg(a.correct::int), 0)::real as correct_rate
      from jsonb_array_elements_text(s.question_ids) with ordinality ids(qid, ord)
      join public.questions q on q.id = ids.qid::uuid
      left join public.live_answers a
        on a.session_id = p_session and a.question_id = q.id
     group by q.id, q.stem, ids.ord
     order by coalesce(avg(a.correct::int), 1) asc, ids.ord;
end;
$$;

-- ── faculty-authored questions (Epic 7b, session-ready) ─────────────────────

create function public.create_cohort_question(
  p_cohort uuid,
  p_domain smallint,
  p_stem text,
  p_options jsonb,
  p_answer_key text,
  p_explanation text default null,
  p_citation text default null
) returns uuid
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  v_id uuid;
  v_keys text[];
begin
  if not app.is_cohort_faculty(p_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  if length(trim(coalesce(p_stem, ''))) < 10 then
    raise exception 'question stem too short';
  end if;
  if jsonb_array_length(p_options) not between 2 and 6 then
    raise exception 'need 2 to 6 options';
  end if;
  select array_agg(o ->> 'key') into v_keys
    from jsonb_array_elements(p_options) o;
  if array_length(v_keys, 1) <> (select count(distinct k) from unnest(v_keys) k)
     or exists (select 1 from jsonb_array_elements(p_options) o
                 where length(trim(coalesce(o ->> 'key', ''))) = 0
                    or length(trim(coalesce(o ->> 'text', ''))) = 0) then
    raise exception 'options need unique keys and non-empty text';
  end if;
  if not (p_answer_key = any (v_keys)) then
    raise exception 'answer key is not among the options';
  end if;

  -- Key before publish: the content guard refuses a published question
  -- with no answer key, so insert as draft, key it, then flip.
  insert into public.questions
    (domain_id, stem, options, citation, author, review_status,
     cohort_id, created_by)
  values
    (p_domain, trim(p_stem), p_options,
     coalesce(nullif(trim(p_citation), ''), 'instructor-authored'),
     'faculty', 'draft', p_cohort, auth.uid())
  returning id into v_id;

  insert into app.question_keys (question_id, answer_key, explanation)
  values (v_id, p_answer_key,
          coalesce(nullif(trim(p_explanation), ''), 'Reviewed by your instructor.'));

  update public.questions set review_status = 'published' where id = v_id;
  return v_id;
end;
$$;

-- Retire (never hard-delete: sessions may reference it).
create function public.retire_cohort_question(p_question uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare v_cohort uuid;
begin
  select cohort_id into v_cohort from public.questions
   where id = p_question and author = 'faculty';
  if v_cohort is null then raise exception 'not a faculty question'; end if;
  if not app.is_cohort_faculty(v_cohort) then
    raise exception 'not faculty of this cohort';
  end if;
  update public.questions set review_status = 'draft' where id = p_question;
end;
$$;
