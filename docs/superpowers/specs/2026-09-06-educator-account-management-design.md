# Educator account management (web console)

Date: 2026-09-06. Status: approved by founder in chat (scope: core + deletion, block-until-handled).

## Goal

Signed-in educators in the web console (politiface.app/app/) get a first-class
account page: edit their identity, manage their sign-in email, sign out
everywhere, and delete their account. Deletion is a real, working flow that a
HECVAT or institutional security review can point at.

## What ships

1. **Account page** at `/account`, linked from a header item showing the
   signed-in handle. Sections:
   - **Profile**: display name (handle) and school. Saved via the existing
     `update_my_profile` RPC (3-20 chars, unique, server-validated).
   - **Sign-in email**: shows the current email; change flow uses
     `supabase.auth.updateUser({ email })`. UI explains that confirmation
     links go to both the old and the new address.
   - **Sessions**: "Sign out of all devices" via `signOut({ scope: 'global' })`.
   - **Danger zone**: "Delete account" with a type-to-confirm dialog.
2. **Blocked-until-handled deletion.** Deletion is refused while the educator
   still owns classes that have other members. The page lists the blocking
   classes and offers "Transfer ownership" to a co-faculty where one exists;
   otherwise it points at class Settings to add one first.
3. **Repair migration** `20260906000100_web_account_management.sql`:
   - `create or replace delete_my_account()`: the shipped July version
     claimed FK cascades that do not exist (`events.user_id`,
     `mock_attempts.user_id`, `cohorts.created_by` and seven other
     provenance columns have no cascade), so it failed with an FK violation
     for any user with history. The replacement does an explicit ordered
     teardown in one transaction:
     - refuses with a clean error listing owned classes that still have
       other members (client renders the blocked state from
       `account_deletion_blockers()`);
     - deletes leftover solo classes, unlinking (not deleting) other users'
       append-only history (`events`, `mock_attempts`, readiness rows get
       `cohort_id = null`);
     - erases the caller's own history (their events, mock attempts,
       announcements, live sessions, teaching inputs, minted invite codes)
       and nulls nullable provenance (`questions.created_by`, `granted_by`);
     - deletes the auth user, which cascades to the profile and every
       cascade-safe table;
     - converts any residual FK violation into a friendly "contact support"
       error instead of a raw Postgres message.
   - `account_deletion_blockers()`: returns the caller's blocking classes
     (id, name, other-member count) for the UI precheck.
   - `transfer_cohort_ownership(p_cohort, p_new_owner)`: creator hands
     `created_by` to an existing co-faculty member. Unblocks deletion and is
     independently useful (faculty turnover).

## Non-goals (deferred)

- Data export (approved for later, not this slice).
- Notification preferences (ships with the weekly digest).
- Avatar picker (app-side identity, not a console concern).
- MFA (email OTP is already a possession factor).

## Data notes

- Students' own progress data is never deleted by an educator's account
  deletion; class deletion unlinks it from the dead class container.
- Aggregate rollups already computed stay (they contain no per-user rows).
- The caller's own event history is erased on account deletion, which is the
  correct data-minimization outcome and matches the app-side Apple
  5.1.1(v) deletion promise.

## Testing

- Web: unit tests for the account page (profile save, blocked deletion
  render, confirm gate) and an axe pass on the new route.
- SQL: exercised by db-ci (migrations must apply cleanly); hosted apply
  needs founder approval as usual, then regenerate `database.types.ts`.
  The new RPC signatures are hand-added to the types file until then
  (same precedent as the 20260821 sprint).
