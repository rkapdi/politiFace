# Politiface Architecture

*Draft 2026-07-02. The technical design for V2 (accounts, leaderboards, FCLE exam prep, faculty portals), built to stay cheap, fast, and reliable from one cohort to many. House style: no em-dashes. Companion to `CLAUDE.md` (context) and `NEAR_TERM_EXECUTION_PLAN.md` (sequencing).*

## Design principles
1. **Supabase-centric, no separate app server yet.** Postgres + Auth + RLS + Edge Functions + `pg_cron` + Realtime cover the pilot, the faculty portal, Android, and the web app. No Django/Redis/Railway until a measured need appears (see Deferred).
2. **The append-only event log is the spine.** Answers, reviews, and mock attempts are immutable events. Progress, streaks, XP, leaderboard scores, readiness, and the efficacy report are all *derived* from them. This makes sync conflict-free, integrity structural, and efficacy a query.
3. **The database enforces truth.** Integrity and authorization live in Postgres (RLS + constraints + a small set of `SECURITY DEFINER` RPCs). The client never holds trust-bearing logic; orchestration and external I/O live in Edge Functions.
4. **Local-first clients.** Flutter caches in Drift, plays offline, and syncs an outbox of events on reconnect. Works on spotty campus wifi.
5. **Data-minimal and pseudonymous by schema.** No PII beyond what Supabase Auth needs; no political affiliation or voting history ever; no education records. The safe path is the only path the schema allows.
6. **Multi-tenant from row one.** Every user/event row carries a `cohort_id` (and nullable `org_id`), even with one cohort, so scaling to many cohorts/institutions is free later.
7. **Build for the pilot, design for growth.** Spend care on the schema, trust boundary, and privacy (expensive to change). Do not pre-build scale (cheap to add).

## Component map
| Concern | Owner |
|---|---|
| Identity (pseudonymous, Apple + email) | Supabase Auth |
| System of record | Supabase Postgres (event log + derived read models) |
| Authorization + integrity | RLS + constraints + `SECURITY DEFINER` RPCs |
| External I/O (RevenueCat webhook, efficacy export) | Edge Functions |
| Scheduled rollups / read-model refresh | `pg_cron` |
| Realtime (leaderboards, later live class game) | Supabase Realtime |
| Content pipeline (YAML to Postgres) | CI step on deploy |
| Static media (face images) | CDN |
| Entitlements source of truth | RevenueCat -> webhook -> `entitlements` |
| Clients | Flutter (iOS now, Android later) + web app/faculty portal |

## Work backward from the deliverable: the efficacy one-pager
Everything the schema captures exists to produce the packet Purcell hands the president. That one-pager needs, per cohort:
- **Adoption:** active students, sessions, active days, retention.
- **Baseline:** cohort average diagnostic Mock FCLE (overall + per domain) at cohort start.
- **Final:** cohort average Mock FCLE before the exam (overall + per domain).
- **Lift:** deltas, and the share of students who crossed from below-passing to passing readiness.
- **Engagement:** questions answered, study time, streaks.
- **Outcome (institution-supplied, aggregate):** first-attempt FCLE pass rate for the cohort.

So we must capture, per pseudonymous user tagged to a cohort: every graded answer (domain, correct, time), every mock attempt (kind, score, per-domain), and sessions. All of that is the event log plus `mock_attempts`. Nothing else is required, which keeps the data footprint minimal.

## Schema (draft DDL)
Single source of schema truth: SQL migrations in `supabase/migrations/` in git. No second migration system.

### Identity and tenancy
```sql
-- PII (email) lives only in Supabase auth.users. profiles stays pseudonymous.
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  handle       text unique not null,          -- chosen, moderated, shown on leaderboards
  school       text,                           -- self-selected label, NOT institutional identity
  created_at   timestamptz not null default now()
);

create table orgs (                            -- nullable/future institution grouping
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table cohorts (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid references orgs(id),
  name         text not null,
  term         text,
  exam_window  daterange,                      -- drives the pilot timeline
  join_code    text unique not null,
  created_by   uuid references profiles(id),
  created_at   timestamptz not null default now()
);

create table cohort_members (
  cohort_id  uuid references cohorts(id) on delete cascade,
  user_id    uuid references profiles(id) on delete cascade,
  role       text not null check (role in ('student','faculty')),
  joined_at  timestamptz not null default now(),
  primary key (cohort_id, user_id)
);
```

### Content (canonical from YAML, versioned, read-mostly)
```sql
create table content_versions (
  id           uuid primary key default gen_random_uuid(),
  version      text not null,
  git_sha      text,
  published_at timestamptz not null default now()
);

create table domains (                         -- the four FCLE domains, fixed
  id      smallint primary key,
  code    text unique not null,                -- american_democracy | us_constitution | founding_documents | landmark_impact
  name    text not null,
  ordinal smallint not null
);

create table objectives (
  id         uuid primary key default gen_random_uuid(),
  domain_id  smallint references domains(id),
  code       text not null,
  description text not null
);

-- The Atlas / IMDb-of-power graph. jsonb for per-type fields (person, executive_order, document, case, term, office).
create table entities (
  id                 uuid primary key default gen_random_uuid(),
  type               text not null,
  slug               text not null,
  name               text not null,
  domain_id          smallint references domains(id),
  data               jsonb not null default '{}',
  citations          jsonb not null default '[]',   -- every entity is cited
  content_version_id uuid references content_versions(id),
  unique (type, slug)
);

-- Exam-prep MCQs. Recognition/face cards reuse the same event + FSRS machinery (table omitted here for brevity).
create table questions (
  id                 uuid primary key default gen_random_uuid(),
  domain_id          smallint references domains(id) not null,
  objective_id       uuid references objectives(id),
  difficulty         smallint not null default 3,
  stem               text not null,
  options            jsonb not null,               -- [{key, text}, ...]
  answer_key         text not null,                -- graded SERVER-SIDE only
  explanation        text not null,
  citation           text not null,                -- working source URL, required
  entity_id          uuid references entities(id), -- link to Atlas for "learn more"
  author             text not null default 'system' check (author in ('system','faculty')),
  review_status      text not null default 'draft' check (review_status in ('draft','reviewed','published')),
  cohort_id          uuid references cohorts(id),  -- non-null = faculty-authored, scoped to a cohort
  content_version_id uuid references content_versions(id),
  created_at         timestamptz not null default now()
);
```

### The event log (the spine: append-only, idempotent)
```sql
create table events (
  event_id    uuid primary key,                 -- CLIENT-generated UUID => idempotent retries
  user_id     uuid references profiles(id) not null,
  cohort_id   uuid references cohorts(id),
  type        text not null,                    -- answer | review | mock_start | mock_complete | session_start | session_end
  question_id uuid references questions(id),
  domain_id   smallint references domains(id),
  chosen_key  text,                             -- the answer the user picked; server grades it
  correct     boolean,                          -- WRITTEN BY SERVER after grading, never trusted from client
  payload     jsonb not null default '{}',
  client_ts   timestamptz not null,
  server_ts   timestamptz not null default now(),
  device_id   text
);
create index on events (user_id, server_ts);
create index on events (cohort_id, server_ts);
create index on events (user_id, domain_id);
-- events are INSERT-only: no update/delete grants (enforced by RLS).
```

### Mock attempts (server-assembled, first-class for efficacy)
```sql
create table mock_attempts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid references profiles(id) not null,
  cohort_id          uuid references cohorts(id),
  kind               text not null check (kind in ('baseline','practice','final')),
  question_ids       jsonb not null,            -- the assembled 80 (20/domain), snapshotted
  content_version_id uuid references content_versions(id),
  started_at         timestamptz not null default now(),
  completed_at       timestamptz,
  score              smallint,                  -- computed server-side from graded events
  per_domain         jsonb,                     -- {american_democracy: {correct, total}, ...}
  passed             boolean                    -- score >= 48
);
```

### Derived read models (recomputable from events; refreshed by trigger or pg_cron)
```sql
create table item_states (                      -- FSRS-4.5 state per user/item, server-authoritative
  user_id       uuid references profiles(id),
  question_id   uuid references questions(id),
  stability     real, difficulty real,
  due_at        timestamptz, last_reviewed_at timestamptz,
  reps int default 0, lapses int default 0,
  primary key (user_id, question_id)
);

create table user_domain_readiness (            -- powers the readiness UI + efficacy
  user_id    uuid references profiles(id),
  cohort_id  uuid references cohorts(id),
  domain_id  smallint references domains(id),
  accuracy   real, readiness real, updated_at timestamptz default now(),
  primary key (user_id, domain_id)
);

create table leaderboard (                       -- denormalized; score is server-authoritative
  cohort_id  uuid references cohorts(id),
  user_id    uuid references profiles(id),
  score      integer not null default 0,
  updated_at timestamptz default now(),
  primary key (cohort_id, user_id)
);
create index on leaderboard (cohort_id, score desc);

create table streaks (
  user_id uuid primary key references profiles(id),
  current int default 0, longest int default 0, last_active_date date
);
```

### Efficacy (aggregate only, pseudonymous)
```sql
create table cohort_rollups (                    -- the one-pager, refreshed by pg_cron
  cohort_id        uuid references cohorts(id),
  computed_at      timestamptz not null default now(),
  active_users     int, sessions int, questions_answered int,
  baseline_avg     jsonb, final_avg jsonb, lift jsonb, engagement jsonb,
  primary key (cohort_id, computed_at)
);

create table cohort_outcomes (                   -- institution-supplied, AGGREGATE, never per-student records
  cohort_id               uuid references cohorts(id) primary key,
  first_attempt_pass_rate real,
  source                  text default 'institution',
  recorded_at             timestamptz default now()
);
```

### Entitlements (RevenueCat is source of truth)
```sql
create table entitlements (
  user_id    uuid references profiles(id),
  capability text not null,                      -- full | fcle | plus
  source     text not null,                      -- institutional | purchase | promo
  granted_at timestamptz default now(),
  expires_at timestamptz,
  primary key (user_id, capability)
);
create table redemption_codes (                  -- comps the whole cohort => no paywall for students
  code       text primary key,
  cohort_id  uuid references cohorts(id),
  capability text not null,
  max_uses   int, uses int default 0, expires_at timestamptz
);
```

## The trust boundary (server-authoritative logic)
A small set of `SECURITY DEFINER` RPC functions own everything that must not be client-trusted:
- **`assemble_mock(cohort_id, kind)`**: server selects 20 questions per domain, no in-session repeats, snapshots the set into `mock_attempts`, returns questions **without answer keys**.
- **`submit_answer(event)`**: idempotent insert (dedupe on `event_id`); the server grades `chosen_key` against `answer_key` and writes `correct`. The client never asserts correctness.
- **`finalize_mock(attempt_id)`**: computes score and per-domain from graded events, writes `mock_attempts`, emits `mock_complete`.
- **FSRS + leaderboard + readiness updates**: triggers on graded answer events update `item_states`, `leaderboard`, and `user_domain_readiness`. All recomputable from `events` if a rebuild is ever needed.

**RLS sketch:** a user reads/writes only their own `events`, `item_states`, `mock_attempts` (via `auth.uid()`); `events` grant INSERT only (no update/delete); cohort members can read the cohort `leaderboard` (pseudonymous handles); faculty (`cohort_members.role = 'faculty'`) read `cohort_rollups` for their cohort and author `questions` scoped to their `cohort_id`; published content is world-readable. Faculty never see per-student education records, only aggregates and pseudonymous handles.

## Sync model (local-first, conflict-free)
1. Client records actions as events with **client-generated UUIDs** into a local Drift outbox; plays offline; runs FSRS locally for instant scheduling.
2. On reconnect, the outbox flushes via `submit_answer`. Idempotent upsert means retries on flaky wifi never double-count.
3. Server grades, updates read models, and is the authority for anything shared (score, leaderboard, mock results). The client shows optimistic values, then reconciles to server truth.
4. Because all shared state is server-derived, **cross-device sync is automatic**: a new device just reads the server. There is no bespoke leaderboard-sync to build.

## Content pipeline
YAML in git (MIT, auditable) is canonical. A CI step on deploy validates it (schema, required citations, taxonomy tags) and ingests into the content tables under a new `content_version`. Questions authored by faculty go through `draft -> reviewed -> published` in the portal and are scoped to their cohort. A running mock snapshots its `content_version`, so faculty edits never disturb an in-progress attempt.

## Staying fast under any load (the anti-sluggishness discipline)
Sluggish enterprise tools die from N+1 queries, missing indexes, over-fetching, and synchronous heavy work, not from a lack of servers. The discipline:
- **Per-screen read models** (a table/view shaped like the UI needs), fetched in one round trip. No chatty ORM graphs.
- **Indexes from day one** on every foreign key and every hot filter (see DDL).
- **CDN** for static media (face images) and cacheable content reads.
- **Async heavy work**: rollups and read-model refreshes run in `pg_cron` off the hot path, never in a request.
- **Keep RLS policies simple and indexable** so they do not wreck query plans.
- **Measure before scaling**: add a Redis sorted set for leaderboards, or a dedicated API service, only when a metric says the Postgres path is slow. At sub-10k users it will not be.

## Failure modes and mitigations
| Risk | Mitigation |
|---|---|
| Salesforce/Moodle sluggishness | Read models, indexes, CDN, async rollups, one-round-trip fetches |
| Business-logic sprawl (Django-less risk) | Integrity in Postgres (RLS + RPCs); orchestration in Edge Functions; nothing trust-bearing in the client |
| Double-counted events on retry | Client UUIDs + idempotent upsert |
| Client faking scores/correctness | Server grades and recomputes from events; client numbers are cosmetic |
| Faculty editing live quiz content | Content versioning + attempt snapshots |
| Privacy/FERPA drift | Pseudonymity enforced in schema; aggregates only; no education records |
| Multi-tenant retrofit pain | `cohort_id`/`org_id` on every row from row one |
| Leaderboard hot path | Denormalized `leaderboard` table + index; Redis ZSET later only if measured |
| Vendor lock-in | Logic in portable SQL; Supabase is open-source Postgres underneath; auth is the only sticky piece |

## Deferred (design does not preclude, but do not build now)
- Redis (leaderboard ZSET / cache / queue) until measured.
- A dedicated API service (any language) if server logic outgrows Edge Functions + SQL.
- Live class game realtime (Supabase Realtime + presence; Redis pub/sub if it ever needs thousands concurrent).
- SSO, LTI/LMS integration, instructor dashboards beyond the read-only efficacy view, multi-campus scaling. Build when the deal firms.
