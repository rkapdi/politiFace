# Measurement Integrity (Phase 1 of the analytics program)

Date: 2026-08-24
Status: Approved

## Goal

Make every number the educator console shows defensible before September
cohorts form: one readiness definition shared with the app, continuously
verified invariants, defensible baselines, and demo data quarantined from
every real report.

## Scope (this phase)

1. **Server readiness v2.** A versioned SQL function mirrors the app's
   projection model (evidence windowed to 45 days, capped at the 50 most
   recent answers per domain, shrunk toward a 0.40 prior by 12
   pseudo-answers). `at_risk_students` and `student_drilldown` read it
   instead of the legacy raw-accuracy read model. Computed at read time so
   inactivity decays readiness without waiting for a write.
   `app.readiness_model_version()` names the active model.
2. **Measurement canary.** `app.run_measurement_canary()` executes
   read-only invariant checks (server grading matches answer keys, no
   future timestamps, malformed answer events, guest exclusion, demo
   quarantine, policy chokepoint present) and records results in
   `app.canary_runs`. Daily pg_cron job; `admin_canary_status()` exposes
   the latest run to admins.
3. **Baseline snapshots.** `app.cohort_baselines` stores a one-time,
   cohort-aggregate distribution of projected scores (histogram bins, avg,
   n; never per-student rows). Captured automatically by a daily job when
   a cohort has 5+ students with enough evidence (or is 14 days old with
   5+ students), or manually by that cohort's faculty. Requires 5+
   students (k-anonymity floor).
4. **Demo quarantine.** `cohorts.is_demo boolean`; demo cohorts are
   excluded from rollups, baselines, and any efficacy surface, enforced
   server-side and asserted by the canary.
5. **Clean types.** Regenerate the web app's `database.types.ts` from
   hosted once these migrations are applied, removing the hand-merged
   file.

## Out of scope (later phases)

Class Pulse sentence, insight cards, charts, digest email, assignment and
reteach actions, efficacy page. The legacy `user_domain_readiness` table
keeps its current write path (app-facing sync surface) and is documented
as raw accuracy, not the projection model.

## Testing

Every change lands smoke-test-first in `supabase/tests/smoke.sql` (run by
db-ci): shrinkage bounds, zero-evidence students read as 0.40 risk,
canary passes clean and fails on a tampered grading row, baselines refuse
below 5 students and store no student identifiers, demo cohorts produce
no rollups or baselines. Public methodology note:
`docs/compliance/MEASUREMENT.md`.
