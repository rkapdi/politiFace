-- Second hardening pass (2026-07-24 server audit, confirmed findings).
--
-- 1. roster_name leak (HIGH): roster_name lives on public.cohort_members,
--    which has a table-wide SELECT grant + member-level RLS. RLS is row
--    level, not column level, so any classmate could read every student's
--    real name via PostgREST and deanonymize the leaderboard. Fix: column
--    grant that excludes roster_name; a student reads their OWN name via an
--    RPC, faculty read others via the existing SECURITY DEFINER reports.
-- 2. live answer key/correctness leak (LOW): students could read their own
--    live_answers.correct before the reveal via REST. They never need
--    direct table access (the app uses RPCs), so drop their SELECT policy.
-- 3. predictable fold event_id griefing (HIGH): the live->events fold used a
--    deterministic md5 event_id in the client-insertable events PK space, so
--    a cohort peer could pre-occupy a victim's id and delete their live
--    answer from grading. Fix: fold on an idempotent `folded` flag with a
--    random event_id; also attribute the cohort ONLY for student players so
--    faculty play cannot pollute efficacy aggregates.
-- 4. push token bloat (MEDIUM): register_push_token had no per-user cap.
-- 5. anon EXECUTE default (LOW): re-issue the repo's revoke convention for
--    functions created since the last one.

-- ── 1. roster_name column protection ────────────────────────────────────────

revoke select on public.cohort_members from authenticated;
grant select (cohort_id, user_id, role, joined_at)
  on public.cohort_members to authenticated;

-- A student's own roster name (for the "name for this class" tile).
create function public.my_roster_name(p_cohort uuid) returns text
language sql stable security definer set search_path = public, app, pg_temp as $$
  select roster_name from public.cohort_members
   where cohort_id = p_cohort and user_id = auth.uid();
$$;

-- ── 2. live_answers: students have no direct table read ─────────────────────

drop policy if exists live_answers_select_own on public.live_answers;
-- Faculty keep live_answers_select_faculty for the live counter; students
-- see their result only through live_reveal / live_scoreboard (definer).

-- ── 3. griefing-proof, idempotent, student-scoped live fold ─────────────────

alter table public.live_answers
  add column folded boolean not null default false;

create or replace function app.finalize_live_session_scoring(p_session uuid)
returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
declare
  s public.live_sessions%rowtype;
  r record;
  v_domain smallint;
  v_cohort uuid;
begin
  select * into s from public.live_sessions where id = p_session;
  if not found then return; end if;

  -- Atomically claim unfolded answers: the UPDATE ... RETURNING locks and
  -- flips them in one statement, so a concurrent finalize (cron + manual,
  -- two devices) claims zero and cannot double-count. event_id is random,
  -- so nothing in the client-insertable events space can collide.
  for r in
    update public.live_answers a set folded = true
     where a.session_id = p_session and not a.folded
     returning a.user_id, a.question_id, a.chosen_key, a.correct, a.created_at
  loop
    select domain_id into v_domain from public.questions
     where id = r.question_id;
    -- Attribute to the cohort only when the player is a STUDENT member, so
    -- an instructor playing along never lands in their class's efficacy
    -- rollups (mirrors the app.current_cohort student scoping).
    v_cohort := case when exists (
      select 1 from public.cohort_members m
       where m.user_id = r.user_id and m.cohort_id = s.cohort_id
         and m.role = 'student') then s.cohort_id else null end;

    insert into public.events
      (event_id, user_id, cohort_id, type, question_id, domain_id,
       chosen_key, correct, client_ts)
    values
      (gen_random_uuid(), r.user_id, v_cohort, 'answer', r.question_id,
       v_domain, r.chosen_key, r.correct, r.created_at);

    perform app.apply_graded_event(
      r.user_id, v_cohort, r.question_id, v_domain,
      case when r.correct then 2 else 0 end, r.correct, r.created_at);
  end loop;
end;
$$;

-- ── 4. per-user push token cap ──────────────────────────────────────────────

create or replace function public.register_push_token(
  p_token text,
  p_environment text default 'production'
) returns void
language plpgsql security definer set search_path = public, app, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if length(trim(coalesce(p_token, ''))) < 32 then
    raise exception 'invalid device token';
  end if;
  insert into public.push_tokens (user_id, token, environment, updated_at)
  values (auth.uid(), trim(p_token),
          case when p_environment = 'sandbox' then 'sandbox' else 'production' end,
          now())
  on conflict (user_id, token) do update
    set environment = excluded.environment, updated_at = now();
  -- Keep only the 5 most recent tokens per user: bounds garbage-token
  -- bloat and the fan-out cost, while covering a couple of real devices.
  delete from public.push_tokens
   where user_id = auth.uid()
     and token not in (
       select token from public.push_tokens
        where user_id = auth.uid()
        order by updated_at desc limit 5);
end;
$$;

-- ── 5. re-issue the least-privilege convention for later functions ──────────

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
-- The three anon-invocable Edge-Function-facing RPCs stay reachable via the
-- service key the functions use; nothing here is needed by anon directly.
