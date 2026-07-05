# Politiface backend (Supabase)

The V2 backend: Supabase Auth + Postgres + RLS + Edge Functions + pg_cron.
Design rationale lives in `ARCHITECTURE.md` at the repo root; this directory
is the implementation. SQL migrations in `migrations/` are the single source
of schema truth.

## Layout

- `migrations/` - ordered DDL. Identity/tenancy, content, event log, read
  models, efficacy, entitlements, then the RPC trust boundary.
- `seed.sql` - local dev seed (placeholder question bank; real content comes
  from the YAML -> Postgres CI ingest).
- `tests/` - `run_local.sh` spins up a throwaway plain Postgres 17 cluster
  (no Docker), applies a tiny Supabase auth shim, runs every migration, then
  `smoke.sql`: the full student/faculty lifecycle through the RPCs plus RLS
  negative tests. CI should run this on every PR that touches `supabase/`.

## Load-bearing invariants

1. `public.events` is append-only. No client role holds UPDATE or DELETE, and
   no policy grants them. Every derived table (item_states, streaks,
   leaderboard, readiness, rollups) is recomputable from events.
2. Grading is server-side only. `correct` is written by `submit_answer`, never
   accepted from a client. Answer keys and explanations live in
   `app.question_keys`, a schema clients cannot read, and are returned only
   after an answer is recorded.
3. FSRS-4.5 on the server (`app.fsrs_schedule`) is a 1:1 port of
   `app/lib/features/session/domain/fsrs_algorithm.dart`. If the weights or
   formulas change in one place they must change in the other.
4. Pseudonymous by schema. PII (email) exists only in `auth.users`. Profiles
   carry a handle and an optional self-selected school label. Nothing stores
   political affiliation, voting history, or education records.
5. Faculty see aggregates, never raw student events. `cohort_rollups` is the
   only faculty-readable derived view of student activity.
6. Multi-tenant from row one: `cohort_id` (and nullable `org_id`) ride on
   every relevant row.

## Local development

```sh
# Fast schema validation without Docker:
./supabase/tests/run_local.sh

# Full local stack (requires Docker):
supabase start
supabase db reset   # applies migrations + seed.sql
```

## RPC surface (what the app calls)

| RPC | Purpose |
|---|---|
| `join_cohort(code)` | Join a cohort by class join code |
| `submit_answer(event_id, question_id, chosen_key, client_ts, device_id, attempt_id)` | Idempotent graded answer; returns correct/key/explanation |
| `submit_review(event_id, question_id, grade, client_ts, device_id)` | FSRS 4-button review |
| `assemble_mock(kind)` | Server-assembled 80-question Mock FCLE (4 x 20), keys withheld |
| `finalize_mock(attempt_id)` | Score + per-domain results, idempotent |
| `redeem_code(code)` | Entitlement grant (institutional rail) + cohort auto-join |
| `upsert_faculty_question(...)` | Faculty authoring incl. protected key, draft -> published |
