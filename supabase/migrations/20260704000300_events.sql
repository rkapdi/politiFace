-- The append-only event log: the spine. Progress, streaks, leaderboard,
-- readiness, and efficacy are all derived from these rows. Events are
-- immutable: INSERT only, no UPDATE or DELETE for any client role.
--
-- Graded events (answers, reviews) are written exclusively by the
-- submit_answer / submit_review RPCs so `correct` and FSRS state are always
-- server-authoritative. Clients may directly insert only ungraded session
-- boundary events.

create table public.mock_attempts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id),
  cohort_id          uuid references public.cohorts (id),
  kind               text not null check (kind in ('baseline', 'practice', 'final')),
  question_ids       jsonb not null,  -- the assembled 80 (20 per domain), snapshotted
  content_version_id uuid references public.content_versions (id),
  started_at         timestamptz not null default now(),
  completed_at       timestamptz,
  score              smallint,
  per_domain         jsonb,           -- {"us_constitution": {"correct": 14, "total": 20}, ...}
  passed             boolean          -- score >= 48 of 80
);
create index mock_attempts_user_idx on public.mock_attempts (user_id, started_at desc);
create index mock_attempts_cohort_idx on public.mock_attempts (cohort_id, kind);

create table public.events (
  event_id    uuid primary key,        -- client-generated: retries are idempotent
  user_id     uuid not null references public.profiles (id),
  cohort_id   uuid references public.cohorts (id),
  type        text not null check (type in
              ('answer', 'review', 'mock_start', 'mock_complete',
               'session_start', 'session_end')),
  question_id uuid references public.questions (id),
  attempt_id  uuid references public.mock_attempts (id),
  domain_id   smallint references public.domains (id),
  chosen_key  text,                    -- what the user picked; the server grades it
  correct     boolean,                 -- written by the server after grading, never by a client
  payload     jsonb not null default '{}',
  client_ts   timestamptz not null,
  server_ts   timestamptz not null default now(),
  device_id   text,
  check (type <> 'answer' or (question_id is not null and chosen_key is not null))
);
create index events_user_ts_idx on public.events (user_id, server_ts);
create index events_cohort_ts_idx on public.events (cohort_id, server_ts);
create index events_user_domain_idx on public.events (user_id, domain_id)
  where type = 'answer';
create index events_attempt_idx on public.events (attempt_id) where attempt_id is not null;

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.events        enable row level security;
alter table public.mock_attempts enable row level security;

-- INSERT + SELECT only. UPDATE/DELETE are not granted to any client role,
-- and no policy allows them either: append-only twice over.
grant select, insert on public.events to authenticated;
grant select on public.mock_attempts to authenticated;

-- Students read their own events. Faculty do NOT read raw events; they get
-- cohort aggregates only (cohort_rollups), which keeps the FERPA posture.
create policy events_select_own on public.events for select
  to authenticated using (user_id = auth.uid());

-- Direct client inserts: ungraded session boundaries only. Answers and
-- reviews must arrive through the grading RPCs (SECURITY DEFINER, bypasses
-- this policy).
create policy events_insert_session on public.events for insert
  to authenticated with check (
    user_id = auth.uid()
    and type in ('session_start', 'session_end')
    and correct is null
    and chosen_key is null
    and question_id is null
  );

-- Mock attempts are created and finalized by RPCs; owners read their own.
create policy mock_attempts_select_own on public.mock_attempts for select
  to authenticated using (user_id = auth.uid());
