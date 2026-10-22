-- Browser guest join for live sessions: a student with no account joins by
-- code from any browser (Supabase anonymous auth supplies auth.uid()).
-- Guests answer through the same server-graded path, appear on the session
-- scoreboard by a self-typed display name, and never enter cohort
-- analytics. Guest rows purge on a schedule (data minimization): the
-- cohort's raw_retention_days when set, otherwise 30 days.

alter table public.profiles
  add column is_guest boolean not null default false;

alter table public.live_sessions
  add column allow_guests boolean not null default true;

alter table public.live_participants
  add column is_guest boolean not null default false,
  add column display_name text
    check (display_name is null or length(trim(display_name)) between 2 and 40);

create function app.is_session_participant(p_session uuid) returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.live_participants
    where session_id = p_session and user_id = auth.uid());
$$;

-- Guests can read their session row (Realtime phase updates).
create policy live_sessions_select_participants on public.live_sessions
  for select to authenticated using (app.is_session_participant(id));

-- ── guest join ──────────────────────────────────────────────────────────────
create function public.join_live_session_guest(
  p_code text, p_display_name text
) returns jsonb
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s record;
  v_user uuid := auth.uid();
  v_name text := nullif(trim(coalesce(p_display_name, '')), '');
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if v_name is null or length(v_name) < 2 then
    raise exception 'enter a display name (2 to 40 characters)';
  end if;
  select * into s from public.live_sessions
   where join_code = upper(trim(p_code)) and status <> 'ended';
  if not found then raise exception 'invalid or ended session code'; end if;
  if not s.allow_guests and not app.is_cohort_member(s.cohort_id) then
    raise exception 'this session is limited to class members';
  end if;

  -- Guests get a minimal profile row (FK target only; not a member of
  -- anything). Handle is derived, unique, and purged with the guest.
  insert into public.profiles (id, handle, is_guest)
  values (v_user, 'g_' || substr(md5(v_user::text), 1, 8), true)
  on conflict (id) do nothing;

  insert into public.live_participants (session_id, user_id, is_guest, display_name)
  values (s.id, v_user, not app.is_cohort_member(s.cohort_id), v_name)
  on conflict (session_id, user_id) do update
    set display_name = excluded.display_name;

  return jsonb_build_object(
    'id', s.id, 'title', s.title, 'status', s.status,
    'index', s.current_index,
    'total', jsonb_array_length(s.question_ids),
    'question_seconds', s.question_seconds);
end;
$$;
revoke all on function public.join_live_session_guest(text, text) from public, anon;
grant execute on function public.join_live_session_guest(text, text) to authenticated;

-- ── participant-aware student RPCs ──────────────────────────────────────────
-- Bodies verbatim from 20260723000100 (with the 20260821000100 ta-or-above
-- edits where present); the membership gate widens to member-or-participant.

-- From 20260723000100:224.
create or replace function public.get_live_question(p_session uuid) returns jsonb
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  q record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
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

-- From 20260723000100:250.
create or replace function public.submit_live_answer(
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
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
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

-- From 20260821000100 (live_reveal); gate widens to member-or-participant.
create or replace function public.live_reveal(p_session uuid) returns jsonb
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
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status <> 'reveal' and not app.is_cohort_ta_or_above(s.cohort_id) then
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

-- From 20260821000100 (live_scoreboard); gate widens to
-- member-or-participant, and guests show by display name.
create or replace function public.live_scoreboard(p_session uuid)
returns table (rank bigint, handle text, score bigint, correct_count bigint, is_me boolean)
language plpgsql stable security definer set search_path = public, app, pg_temp as $$
declare s public.live_sessions%rowtype;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then raise exception 'no such session'; end if;
  if not (app.is_cohort_member(s.cohort_id)
          or app.is_session_participant(p_session)) then
    raise exception 'not a member of this cohort';
  end if;
  if s.status = 'question' and not app.is_cohort_ta_or_above(s.cohort_id) then
    raise exception 'standings arrive at the reveal';
  end if;
  return query
    select row_number() over (order by t.score desc, t.total_ms asc) as rank,
           coalesce(lp.display_name, p.handle), t.score, t.correct_count,
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
      left join public.live_participants lp
        on lp.session_id = p_session and lp.user_id = t.user_id
     order by t.score desc, t.total_ms asc
     limit 50;
end;
$$;

-- ── analytics exclusion at finalize ─────────────────────────────────────────
-- Body verbatim from 20260724000100:256; guests' answers never fold into
-- cohort events or the grading pipeline.
create or replace function app.finalize_live_session_scoring(p_session uuid) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  r record;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then return; end if;
  for r in
    select a.user_id, a.question_id, a.chosen_key, a.correct, a.created_at,
           q.domain_id,
           md5('live:' || a.session_id || ':' || a.question_id || ':'
               || a.user_id)::uuid as det_id
      from public.live_answers a
      join public.questions q on q.id = a.question_id
     where a.session_id = p_session
       and not exists (select 1 from public.live_participants lp
                        where lp.session_id = a.session_id
                          and lp.user_id = a.user_id
                          and lp.is_guest)
  loop
    -- Deterministic id makes the fold idempotent.
    insert into public.events
      (event_id, user_id, cohort_id, type, question_id, domain_id,
       chosen_key, correct, client_ts)
    values
      (r.det_id, r.user_id, s.cohort_id, 'answer', r.question_id,
       r.domain_id, r.chosen_key, r.correct, r.created_at)
    on conflict (event_id) do nothing;
    if found then
      perform app.apply_graded_event(
        r.user_id, s.cohort_id, r.question_id, r.domain_id,
        case when r.correct then 2 else 0 end, r.correct, r.created_at);
    end if;
  end loop;
end;
$$;

-- ── scheduled purge ─────────────────────────────────────────────────────────
create function app.purge_live_guest_data() returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  delete from public.live_answers a
   using public.live_participants lp,
         public.live_sessions s
   where lp.session_id = a.session_id and lp.user_id = a.user_id
     and lp.is_guest and s.id = a.session_id
     and a.created_at < now() - make_interval(days => coalesce(
           (select c.raw_retention_days from public.cohorts c
             where c.id = s.cohort_id), 30));
  delete from public.live_participants lp
   using public.live_sessions s
   where lp.is_guest and s.id = lp.session_id
     and lp.joined_at < now() - make_interval(days => coalesce(
           (select c.raw_retention_days from public.cohorts c
             where c.id = s.cohort_id), 30));
  delete from public.profiles p
   where p.is_guest
     and not exists (select 1 from public.live_participants lp
                      where lp.user_id = p.id);
end;
$$;

-- Daily purge; guarded like 20260726000100 (no pg_cron in the test cluster).
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'purge-live-guests cron: pg_cron not installed; skipping';
    return;
  end if;
  if exists (select 1 from cron.job where jobname = 'purge-live-guests') then
    perform cron.unschedule('purge-live-guests');
  end if;
  perform cron.schedule('purge-live-guests', '17 6 * * *',
    'select app.purge_live_guest_data()');
end $$;
