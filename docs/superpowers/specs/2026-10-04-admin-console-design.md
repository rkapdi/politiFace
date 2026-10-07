# Admin console (phase 2a: see everything)

Date: 2026-10-04. Status: approved by founder in chat (look, record layout, problem log, screens, failed-sign-in email; this console replaces the legacy `/faculty` admin tab). Supersedes the support-role and per-role email rules in Section 3 of `2026-09-27-onboarding-and-admin-console-design.md`.

## Why

Troubleshooting today means opening the legacy `/faculty` portal's admin tab, which shows flat lists and no history. With 294 students onboarding across Purcell's 7 sections, the founders need one place to answer "what is happening right now" and "what happened to this person", fast, before a student or professor finishes describing the problem.

## Who

Exactly two people: the founder (`thedeclanmercer@gmail.com`) and Dawood (`shahdawood456@gmail.com`). Both see all data, including student emails. The existing `app.admins` table already holds exactly these two accounts and stays the gate. There is no UI to add admins; a third admin requires a migration.

## Look

"Gotham" dark operations console (founder pick A of three): near-black surfaces, dense monospaced data, color only for status (green live/ok, amber attention, red failure, blue info), thin 1px panel borders, a narrow icon rail, a top bar with Cmd-K search and a live indicator. Desktop first (1280px+); readable but not optimized on a phone. WCAG 2.1 AA contrast holds on the dark palette (body text at least 4.5:1).

## Phases

- **2a (this spec):** audit log, problem log, console shell, search, home, three-pane records for people, classes, sessions, an Invites page, and one action (grant or revoke instructor access). Together these cover everything the legacy `/faculty` admin tab does, so 2a replaces that tab. Other action buttons render disabled with "Coming in 2b".
- **2b (separate spec):** remaining actions (class role changes, move/remove members, rename, sign out everywhere, end a stuck session, change email, delete account), the faculty request queue moved into the console, expected enrollment per class.
- **3 (separate spec):** break-glass "act as user", retire `/faculty`.

## Data

### Audit log (new)

`app.admin_audit (id bigserial, actor uuid, action text, target_user uuid null, target_cohort uuid null, target_session uuid null, details jsonb, created_at timestamptz)`. RLS on, no policies; written and read only through admin RPCs. 2a writes `console_open` (once per console load) and `view_person` (each person record opened). Retained indefinitely (small; it is the security-review evidence). Readable in the console under Audit. 2a also writes `faculty_granted`, `faculty_revoked`, `invite_minted`, and `invite_revoked`.

### Problem log (new)

`app.ops_events (id bigserial, user_id uuid null, email text null, kind text, code text null, detail jsonb, client text, app_version text null, created_at timestamptz)`.

- `kind` in: `signin_send_failed`, `signin_verify_failed`, `join_refused`, `client_error`, `app_seen`.
- `email`: only on `signin_*` rows, the address the person typed, lowercased and trimmed. Needed because a failed sign-in has no account yet.
- `detail`: small structured context (error status and code, refusal reason, screen/route, error message truncated to 300 chars). Never answer content, never free text the user typed other than the email above.
- `client` in `web`, `ios`; `app_version` for iOS (from the bundle), web build hash for web.
- `app_seen`: one row per signed-in user per day per client (deduped server-side), so the console can show each person's app version and last-seen time.
- Retention: 90 days, purged daily by pg_cron (`app.purge_ops_events()`).
- Write path: `public.log_ops_event(p_kind, p_code, p_detail, p_client, p_app_version, p_email default null)`, callable by `anon` and `authenticated`. Server sets `user_id` from `auth.uid()` (never trusted from the client), validates `kind`/`client` against the allowed sets, caps `detail` at 2 KB, drops `email` unless `kind` is `signin_*`, and rejects more than 30 rows per minute for the same (`email` or `user_id`, `kind`) to bound abuse. Read path: admin RPCs only.

### Admin read RPCs (new; all `security definer`, `search_path = public, app, pg_temp`, refuse unless `app.is_admin(auth.uid())`)

- `admin_home()` returns jsonb: totals (people, students, faculty, classes, enrolled, answered live in 7 days), `live_now[]` (session id, title, class, professor, status, question index/total, participants, started), `pending_requests` count, `funnel[]` per class (signed in members, enrolled students, answered in a live session, practiced in the last 7 days), `attention[]` (pending instructor requests; classes with fewer than 50% of members active in 7 days; students enrolled twice under the same roster name in one class; more than 10 `signin_*` failures in the last hour), `health` (latest canary result).
- `admin_activity(p_since timestamptz)` returns the merged stream newer than `p_since` (max 100): sign-ups, class joins, live joins, session starts/ends, announcements, faculty requests, problem-log rows. The home polls it every 5 seconds.
- `admin_search(p_q text)` returns up to 25 hits typed `person` (match on email, display name, roster name), `class` (name, join code), `session` (title, join code).
- `admin_person(p_user uuid)` returns identity (email, display name, school, created, last sign-in, verified faculty, admin), memberships (class, role, roster name, joined), devices (from `auth.sessions`: user agent summarized to platform and browser or app, created, last refreshed; never the IP), push devices count, latest app version per client, practice summary (answers and accuracy, last 30 days), and `timeline[]`.
- `admin_class(p_cohort uuid)` returns class facts, members (with roster names and emails), sessions, funnel, and `timeline[]`.
- `admin_session(p_session uuid)` returns session facts, participants (member or guest, answered count), per-question results, and `timeline[]`.

### Admin write RPCs in 2a (admin-checked, audited in the same transaction)

- `admin_set_faculty_audited(p_user uuid, p_verified boolean)`: grants or revokes `app.verified_faculty`, writes `faculty_granted` / `faculty_revoked`. Replaces the console's use of the legacy unaudited `admin_set_faculty` (which stays for the legacy portal until it is retired).
- Invites reuse `mint_faculty_invite` and `revoke_faculty_invite`; a new `admin_list_invites_v2()` adds `expires_at`, `revoked_at`, `recipient_email`, and status (`active`, `used`, `expired`, `revoked`). Minting and revoking from the console go through `admin_mint_invite(p_note, p_recipient_email)` / `admin_revoke_invite(p_code)` wrappers that write `invite_minted` / `invite_revoked`.

**Timeline** entries are `{at, kind, title, detail, severity}` with `severity` in `info|ok|warn|fail`, newest first, capped at 300, merged from: `auth.users` (created, last sign-in), `cohort_members.joined_at`, `live_participants.joined_at`, `live_answers` (per session summary, not per answer), `events` (practice answers summarized per day, `mock_start`, `session_start`), `class_announcements`, `faculty_access_requests`, `app.verified_faculty`, `export_log`, `app.ops_events`, `app.admin_audit` (actions on this record).

## Screens

React, inside the existing web console, under `#/admin/*`, lazy-loaded so non-admin browsers never download the code. A "Console" link in the header shows only when `am_admin()` is true; the routes also render a "Not available" screen for anyone else (the server refuses regardless).

- **Shell:** icon rail (Home, Search, Live, Invites, Audit), top bar with Cmd-K / Ctrl-K palette and live indicator (count of running sessions).
- **Home** (`#/admin`): stat strip; Live now; onboarding funnel by class (bars, click a class to open it); Needs attention; activity stream (5 s poll, newest on top, failures in red).
- **Search** (`#/admin/search?q=`): grouped results; the palette shows the same top 8 inline and Enter opens the first.
- **Person** (`#/admin/people/$userId`): three panes. Left: linked records (classes with roster names, sessions joined, devices). Center: timeline with failures highlighted. Right: properties, then actions (disabled, "Coming in 2b").
- **Class** (`#/admin/classes/$cohortId`): left: members and sessions; center: timeline; right: facts (join code, term, policy, funnel numbers).
- **Session** (`#/admin/sessions/$sessionId`): left: participants; center: timeline; right: facts and per-question results.
- **Invites** (`#/admin/invites`): every faculty invite with status, inviter, recipient hint, created and expiry; create a link (copy to clipboard), revoke an active one.
- **Audit** (`#/admin/audit`): newest admin actions, filter by actor and action.
- **Person record action live in 2a:** "Grant instructor access" / "Revoke instructor access" (confirm dialog, audited). All other actions disabled until 2b.

### Replacing the legacy admin tab

When 2a ships, the Admin tab in `docs/faculty/index.html` is replaced by a single notice linking to `politiface.app/app/#/admin` ("The admin console moved"). The legacy admin markup and its scripts are removed. The professor-facing parts of `/faculty` stay until phase 3.

## Client instrumentation (problem log)

- **Web:** `EmailCodeForm` logs `signin_send_failed` / `signin_verify_failed` with status/code and the typed email; `JoinPage` logs `join_refused` with the friendly reason; the route error boundary logs `client_error` with the route; `app_seen` once per day per signed-in browser.
- **iOS:** `SignInSheet` logs the two sign-in failures; live-session join failures log `join_refused`; the Flutter error handler logs `client_error` (route, truncated message) alongside Sentry; `app_seen` once per day with the bundle version.
- Logging is fire-and-forget and never blocks or breaks the user flow; failures to log are swallowed.

## Privacy and compliance

- Admin-only reads; emails visible to both admins by founder decision.
- Problem log keeps typed emails on failed sign-ins only, 90 days, then purged.
- No answer content, no IP addresses, no political affiliation or voting history anywhere.
- Audit log records console opens and person views, which is the evidence an institution's security review will ask for.

## Testing

- `supabase/tests/smoke.sql`: every admin RPC refused for anon, student, faculty; allowed for an admin; grant/revoke and invite mint/revoke write audit rows; `log_ops_event` validation (kind/client allow-lists, email dropped on non-sign-in kinds, user_id from the session, rate cap, detail size cap); purge removes rows older than 90 days; audit rows written on `admin_person`.
- Web (vitest): console link hidden for non-admins; each screen renders from mocked RPC data; palette keyboard flow; failures highlighted; axe checks on the dark theme.
- iOS: unit tests that `SignInSheet` failures call the logger; existing suite stays green.
- Manual: one live session with a test class while watching the console home.

## Out of scope for 2a

Write actions other than instructor access and invites, the faculty request queue in the console (it stays on the classes page for now), expected enrollment, impersonation, mobile layout polish, exporting from the console.
