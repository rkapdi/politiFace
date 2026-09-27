# One console: faculty onboarding, student browser identity, admin console

Date: 2026-09-27. Status: approved by founder in chat, section by section.

## Why

Purcell is onboarding 294 students across 7 sections (six POS 2041, one INR
2002) this semester, with the first live session inside a week. Today:

- Faculty onboarding spans two sites. `politiface.app/faculty` (legacy
  portal) holds the admin tools and the invite-code box; `politiface.app/app`
  (the React console) is where faculty work but has neither. A new professor
  signs in to `/app`, tries to create a class, and hits "requires instructor
  verification" with no way forward on that page.
- Verification is a manual handoff: a founder finds the user in the legacy
  admin tab and clicks Grant faculty. The professor cannot ask for it or see
  it is pending.
- Admin is one flat allowlist (`app.admins`: both founders) over seven
  read-only RPCs. No owner/support split, no account management, no audit.
- Browser live joins sign in anonymously: every join is a new throwaway
  identity, excluded from cohort analytics and purged after 30 days. The
  professor cannot see browser students as the same person across sessions.

## Goal

One site (`politiface.app/app`) with the right door for each role:

- **Professors**: an invite link that verifies them and walks them into a
  first class, with a request-access fallback.
- **Students**: sign in once in the browser with the same email-code account
  the iOS app uses; the session code enrolls them in the class; later
  sessions are one tap.
- **Founder (owner)**: an admin console with full visibility (onboarding
  funnel, live sessions, users, classes), role and account management, an
  audit log, and break-glass impersonation for troubleshooting.
- **Dawood (support)**: the parts of the admin console needed to onboard and
  help professors, without owner-only powers.

Then retire `/faculty`.

## Success measure

Activation for a student = signed in, enrolled, and answered in a live
session. The admin home shows this funnel per class. Target for the first
in-room test section: at least 90% of students present reach "answered in a
live session" within 10 minutes of the QR code going up.

## Phasing (one-week window)

1. **Days 1 to 3, unblock Purcell**: invite links + setup wizard, request
   access, student browser sign-in + session-code enrollment, guests off by
   default, role-based home. In-room test in one of Purcell's sections.
2. **Days 3 to 5, admin console**: staff roles, audit log, funnel home, live
   now, users, classes, invites and requests, account actions.
3. **Days 5 to 7, finish**: owner-only impersonation, `/faculty` redirect,
   full dry run.

Phase 1 is gated on email delivery (see Prerequisites).

## Prerequisites (founder, outside the code)

Email-code sign-in for ~294 students requires, in the Supabase dashboard:

1. **Custom SMTP** (for example Resend) sending from a verified
   `politiface.app` address with SPF and DKIM. The built-in Supabase mailer
   only sends a few emails per hour, and only to project team members.
2. **Rate limits raised** (Authentication, Rate Limits): emails sent per hour
   (for example 500); token verifications per 5 minutes per IP (default
   about 30, and a classroom shares one campus IP, so raise to about 300).
3. **Deliverability check** with a real `@mymdc.net` inbox during the dry
   run: Microsoft school mail can quarantine code emails.
4. Apply `20260927000100_display_names_with_spaces.sql` (committed, not yet
   applied) so professors can use real names.

## Section 1: roles and faculty onboarding

### Staff roles

- New `app.staff (user_id pk -> profiles, role in ('owner','support'),
  granted_by, created_at)`. Partial unique index: at most one `owner`.
- Seed: the founder account (`thedeclanmercer@gmail.com`) as owner, Dawood
  (`shahdawood456@gmail.com`) as support. Seed by email lookup in the
  migration, failing loudly if either is missing.
- `app.is_admin(uid)` is redefined as "is staff" so the seven existing admin
  RPCs keep working for both roles. New `app.is_owner(uid)` guards owner-only
  actions. `app.admins` is dropped after the redefinition.
- `admin_set_staff(p_user, p_role)` (owner only; cannot demote the owner).

### Faculty invite links

- `faculty_invites` gains `expires_at` (default now() + 14 days),
  `recipient_email` (optional hint, not enforced), `revoked_at`.
- `mint_faculty_invite` returns the code; the console renders the link
  `politiface.app/app/#/welcome?invite=CODE`. Staff and verified faculty can
  mint. `revoke_faculty_invite(code)` for the minter or staff.
- `redeem_faculty_invite` additionally refuses expired or revoked codes.
- New public route `#/welcome`: shows "You've been invited to Politiface as an
  instructor" (inviter's display name via `invite_preview(code)`, which
  returns only inviter name and validity), then email-code sign-in, then
  auto-redeem, then a three-step setup: display name, school, first class
  (name + term). Ends on the class page showing the join code and a
  printable QR poster (class join link) for the room.

### Request access

- New `faculty_access_requests (id, user_id, school, courses, note, status in
  ('pending','approved','denied'), decided_by, decided_at, created_at)`, one
  open request per user.
- `request_faculty_access(school, courses, note)`,
  `my_faculty_access_request()`.
- A signed-in user who is not verified faculty, not a student of any class,
  and not staff, landing on `/app`, sees "Are you an instructor? Request
  access" instead of the create-class form. After submitting: "Request sent.
  You'll be able to create classes as soon as it's approved." The page
  subscribes (Realtime) or polls and switches to the setup wizard on approval.
- `admin_decide_faculty_request(id, approve bool)` (staff): approve inserts
  `app.verified_faculty`.
- The create-class error copy stops pointing to "the app or portal".

## Section 2: student browser flow

### Join route `#/join?code=XXXXXX`

- **Signed in (non-anonymous), already a member**: one tap, "Join as
  <roster name or display name>", calls `join_live_session`.
- **Signed in, not a member**: shows "Join <class name> with <professor
  display name>?" and "Your name as your professor knows it" (2 to 60
  chars). Calls new `join_live_session_as_student(p_code, p_roster_name)`,
  which in one transaction enrolls (same insert as `join_cohort`) and adds
  the participant. Refuses if the caller is faculty/TA of that class (they
  run it, not join it).
- **Not signed in**: "Use your MDC email" prompt, email code, then the branch
  above. Same Supabase account as the iOS app.
- "Not you? Sign out" link on every join screen.
- Session preview before sign-in via `live_session_preview(p_code)`: returns
  class name, professor display name, session title, `allow_guests`. No
  member data.

### Guests

- `live_sessions.allow_guests` default flips to `false` for new sessions.
- Session setup gains "Allow guests without sign-in" (off by default). When
  on, the join screen offers "Join without signing in" as a secondary
  action (the existing anonymous path, unchanged).

### Role-based home

- `/app` resolves a home by role (new `my_console_role()` returning
  `staff`, `faculty`, `ta`, `student`, or `none`, highest wins):
  - staff: the faculty console plus the Admin nav item;
  - faculty or TA: the faculty console (as today);
  - student: a student home (their classes, join a class by code, join a
    live session by code, link to the iOS app);
  - none: request access (Section 1).

### Known risk

A student who signs in with a personal email one session and a school
email the next becomes two accounts. Mitigation: "Use your MDC email" copy
on sign-in; the admin console can remove a duplicate enrollment. Account
merge is out of scope.

## Section 3: admin console

### Access model

- Route `#/admin` with nested pages; nav item shown to staff only. Every
  admin RPC checks `app.is_admin` or `app.is_owner` server-side; the page is
  only a view.
- `app.admin_audit (id, actor, action, target_user, target_cohort, details
  jsonb, reason, created_at)`. Every admin RPC that changes anything writes
  one row in the same transaction. Owner reads all; support reads its own.

### Permission matrix

| Capability | Support | Owner |
|---|---|---|
| Funnel home, live now, classes, sessions | yes | yes |
| User directory, user detail | yes, no student emails | yes, all emails |
| Mint or revoke invites, decide requests | yes | yes |
| Grant or revoke faculty | yes | yes |
| Change class role, remove or move member, edit roster name | yes | yes |
| Rename display name, sign out everywhere | yes | yes |
| End a stuck live session | yes | yes |
| Staff roles | no | yes |
| Change a user's email, delete an account | no | yes |
| Impersonation | no | yes |
| Audit log | own actions | all |

### Pages

- **Home**: onboarding funnel per class (expected enrollment, a nullable
  `cohorts.expected_students` set by the professor or staff; signed-in
  members; enrolled students; answered in a live session; practiced in the
  app in the last 7 days); live now (running sessions with class, professor,
  participants, current question index); pending requests count; system
  health (existing `admin_canary_status`).
- **Users**: search by email (owner), display name, or roster name; filters
  faculty, student, staff, unverified, guest. **User detail**: identity (email
  for owner, display name, created, last sign-in), roles (staff, verified
  faculty, per-class role), classes with roster names, live sessions joined,
  last 50 events, push device count, audit rows targeting them, and the
  actions allowed by the matrix.
- **Classes**: all classes with owner, member counts, session count,
  reporting policy, expected students (editable); detail lists members and
  sessions.
- **Live sessions**: running and past, with End for running ones.
- **Invites and requests**: mint (link + copy), revoke, redemption status;
  request queue with approve/deny.
- **Audit log**: filterable by actor, action, target.

### Account actions (server)

- `admin_set_member_role(cohort, user, role)`,
  `admin_remove_member(cohort, user)`,
  `admin_move_member(from_cohort, to_cohort, user)` (keeps roster name; does
  not rewrite history `cohort_id`), `admin_set_roster_name`,
  `admin_set_display_name` (same validation as `update_my_profile`),
  `admin_end_live_session(session)`.
- Edge Function `admin-account` (service role, verifies caller JWT is staff
  or owner as required, then acts, then writes `admin_audit`):
  `sign_out_everywhere` (support+), `change_email` (owner),
  `delete_account` (owner; reuses the blocker rules of `delete_my_account`,
  refusing while the user owns classes with other members).

### Impersonation (owner only, break-glass)

1. Owner clicks "Act as user" on a user detail page and must enter a reason.
2. Edge Function `admin-impersonate` verifies the caller is owner, refuses
   staff targets, calls `auth.admin.generateLink({ type: 'magiclink' })` for
   the target (no email is sent), inserts `app.impersonations (id, owner,
   target, reason, started_at, expires_at = started_at + 30 min,
   session_id null, ended_at)`, writes `admin_audit`, and returns the token
   hash and ticket id.
3. The console opens a new tab at `#/impersonate?ticket=...&th=...`. That tab
   uses a Supabase client whose auth storage is `sessionStorage`, so the
   owner's own session in other tabs is untouched. It verifies the token
   hash to obtain the target's session, then calls
   `bind_impersonation(ticket)`, which stores `auth.jwt() ->> 'session_id'`.
4. The tab shows a red banner ("Acting as <user>. Ends in mm:ss. End now.").
5. `events` gains `acted_by uuid null`. A before-insert trigger sets
   `acted_by` to the owner when the current `session_id` matches an active
   impersonation, and refuses writes when it matches an expired one.
   Rollups, readiness, efficacy, and the funnel exclude `acted_by is not
   null`.
6. A pg_cron job every minute deletes `auth.sessions` rows for expired
   impersonations (refresh revoked) and sets `ended_at`. End now does the
   same immediately. Start and end are audited. Known limit: an access token
   can still read until its own expiry (up to 1 hour); writes are refused.
7. Privacy policy gains: "Politiface staff may access an account to resolve
   a support request you raise. Every access is logged."

### Retiring `/faculty`

After phase 3, and after confirming the React console covers every faculty
feature in the legacy portal (classes, live sessions, questions, co-faculty,
message class, one-pager, reteach), `docs/faculty/index.html` becomes a
redirect to `/app`.

## Data minimization and compliance

- No new student data beyond what the iOS flow already collects (email for
  sign-in, roster name the student types).
- Support never sees student emails.
- Impersonated activity never enters efficacy numbers.
- Audit log retained indefinitely (small, and it is the HECVAT evidence).
- No political affiliation or voting history anywhere (unchanged).

## Testing

- `supabase/tests/smoke.sql`: every new RPC called as anon, student,
  faculty, support, and owner, asserting allowed and refused cases; audit row
  written for each mutation; impersonation stamping and expired-write refusal.
- Web (vitest): welcome flow, request access, join branches (member, non
  member, signed out, guests allowed/not), role-based home, admin pages
  render per role, impersonation banner.
- Manual: in-room test in one of Purcell's sections (phase 1), then a full
  dry run with a test professor, three test students (one `@mymdc.net`),
  support, and owner (phase 3).

## Out of scope

Account merge, SSO/LMS rostering, email notifications beyond auth codes,
Android, multi-owner, org-admin views.
