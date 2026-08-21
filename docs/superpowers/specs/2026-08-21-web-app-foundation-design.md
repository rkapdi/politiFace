# Web App Foundation: Roles, Analytics, Live Sessions

Date: 2026-08-21
Status: Approved
Owner: Rissalat

## Goal

Rebuild the faculty web experience on a foundation that scales beyond one campus: a proper role model enforced server side, educator analytics that are intuitive and per-student where policy allows, and live class sessions that students can join from any browser with no app install. Everything rides the existing audited Supabase trust boundary (Auth, Postgres, RLS, SECURITY DEFINER RPCs, Edge Functions). No new server tier.

## Non-goals (this sprint)

- SSO, LTI, SCIM rostering (Epic 8; deferred until an institution requires them)
- Ad monetization plumbing
- Per-student practice assignments (cohort-level assignment only in v1)
- Any Django or dedicated API service
- Decommissioning the existing `docs/faculty/` portal (it stays live until each view has a replacement)

## Architecture

- New top-level `web/` directory: Vite, React, TypeScript, TanStack Router and Query, shadcn/ui, Recharts.
- Types generated from the database (`supabase gen types typescript`), checked in, refreshed by CI when migrations change. Schema drift fails the build, not production.
- One analytics semantic layer: every metric is computed exactly once, in SQL, as an RPC that respects the cohort disclosure policy. The faculty dashboard, admin view, drill-downs, and the efficacy one-pager are thin renderers of the same RPCs.
- Deployment: GitHub Actions builds the Jekyll site and the Vite app into a single Pages artifact; the React app mounts at `/app/`. Static CDN delivery; the only server tier is Supabase.
- Auth: Supabase email OTP with PKCE, as today. SPA route guards are cosmetic; authorization lives in RLS and RPCs. Admin routes are code-split and lazy-loaded so admin UI no longer ships to every visitor (audit F3).

## Role model

Current: `app.admins`, `app.verified_faculty`, and per-cohort `cohort_members.role in ('student','faculty')`.

Changes:

1. Add `'ta'` to `cohort_members.role`. A TA can run live sessions and view cohort-aggregate analytics. A TA cannot view per-student data (regardless of cohort policy), mint invites, or author or publish questions. `add_co_faculty` keeps meaning full faculty; faculty get a separate "add TA" flow.
2. Add `app.org_admins` (org_id, user_id) plus predicate `app.is_org_admin`. No UI this sprint; this is the seam for department-level and multi-institution rollups later.
3. New predicates follow the existing pattern: `app.is_cohort_ta_or_above` alongside `app.is_cohort_faculty`. Every new RPC declares its minimum role through these predicates.

## Disclosure policy enforcement (closes audit F1)

The per-cohort columns already exist (`reporting_resolution`: per_student, pseudonymous, aggregate_only; `identity_display`; `raw_retention_days`) but nothing consults them.

- Add one chokepoint function, `app.apply_reporting_policy(cohort_id, caller)`, consulted by every RPC that returns student-level rows: `live_session_report`, `cohort_student_progress`, and the new analytics RPCs below.
- per_student: named rows per `identity_display`.
- pseudonymous: stable per-cohort pseudonyms (deterministic per cohort and user; students keep the same label across surfaces).
- aggregate_only: student-level RPCs return only aggregate shapes; the UI reads the policy and hides drill-down affordances.
- TAs are always served the aggregate_only shape regardless of policy.
- Fix the portal privacy copy so it states exactly what the active policy exposes.
- Export actions are recorded in an `app.export_log` (who, what cohort, what shape, when) for procurement and FERPA optics.

## Educator analytics surfaces

All computed by policy-aware RPCs on the append-only event log and existing read models.

1. Cohort dashboard: readiness by FCLE domain, most-missed questions and objectives (existing RPCs), plus a new engagement trend (active students and answer volume over time).
2. At-risk list: new RPC ranking students below a readiness threshold, showing the weakest domain and days since last activity. The fastest answer to "who do I need to talk to."
3. Per-student drill-down: new RPC with domain and objective readiness, practice volume and recency, live-session history. Includes rule-based next-step suggestions (weakest domain and lowest-readiness objectives mapped to suggested practice). One-click action in v1: create a cohort-scoped practice assignment via the existing `create_teaching_input`, or prefill a class announcement.
4. Exports: printable class report (existing `efficacy-report` edge function pattern) plus CSV export of the at-risk and drill-down views, gated by the same policy chokepoint and logged.

## Live sessions

- Faculty runner rebuilt in React: lobby with join code and QR, question with countdown, reveal, scoreboard with Realtime auto-refresh (fixes audit F25), end-of-session "what to reteach" and report.
- Student browser join at `/app/join`: enter code and display name, Supabase anonymous sign-in, then the same server-graded RPC path (`join_live_session`, `submit_live_answer`) with Realtime phase sync. No app install, no account, no student PII beyond a self-typed display name.
- Guests (anonymous, not cohort members) participate and appear on the session scoreboard, but are excluded from persistent per-student analytics and from `finalize_live_session_scoring` leaderboard folding. Guest rows purge on a schedule per `raw_retention_days`.
- The Flutter in-app join path continues to work unchanged; cohort members who join from the app keep full attribution.

## Error handling

- TanStack Query handles retries and stale state; error boundaries per route.
- RPC failures surface as plain-language messages, never raw Postgres errors.
- The measurement contract and daily canary over `events` (September sprint, steps 5 and 6) remain the reliability backstop for analytics correctness.

## Testing

- Database: extend `supabase/tests` to cover new predicates, the policy chokepoint (each resolution mode, TA capping, guest exclusion), and run in CI against a shadow database (closes audit F5).
- Web: Vitest for units (policy-shaped rendering, suggestion rules), Playwright smoke for auth, dashboard load, and the live-join flow, axe-core checks in CI for WCAG 2.1 AA regressions.
- Contract: generated types plus a CI step that fails when migrations and checked-in types diverge.

## Accessibility

WCAG 2.1 AA is a procurement deliverable (VPAT). shadcn/ui primitives carry most of it; CI axe checks plus a manual keyboard and screen-reader pass on dashboard, drill-down, and live join before Sept 20. This retires the audit F15 class of issues in the new app by construction.

## Sequencing

- Phase 0 (by Aug 24): verify hosted schema matches the repo (audit F2, three migrations flagged UNAPPLIED), database tests wired into CI.
- Phase 1 (before September cohorts form): spine migrations (TA role, org_admins, policy chokepoint, new analytics RPCs, export log), typed contract generation. Data is policy-clean from the first day of cohort data.
- Phase 2 (by Sept 20): React app shell and auth, cohort dashboard, at-risk, drill-down, exports, live runner, student live-join, accessibility pass. Demo-ready for Constitution Day.

## Backlog (explicitly not this sprint)

- Move the web app from GitHub Pages to politiface.app: custom domain, DNS, Supabase auth redirect URLs and allowed origins, then old-URL redirects. Cheap by construction under this architecture; do after Sept 20.
- Org-admin surfaces (department-level rollups across cohorts).
- Per-student practice assignments and per-student messaging.
- Old portal decommission and redirects once view parity is reached.
- SSO, LTI, rostering (Epic 8).
