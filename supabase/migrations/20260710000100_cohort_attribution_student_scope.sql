-- Cohort attribution: scope activity tagging to STUDENT membership.
--
-- Context / the gap
-- -----------------
-- FCLE mock attempts and graded answer/review events are already tagged with a
-- cohort_id, server-side, by the SECURITY DEFINER grading RPCs
-- (assemble_mock -> mock_attempts.cohort_id + mock_start event; submit_answer /
-- submit_review -> events.cohort_id; finalize_mock inherits the attempt's
-- cohort). Every one of those RPCs derives the cohort from app.current_cohort()
-- -- never from client input. So the trust boundary for attribution is already
-- correct.
--
-- What was WRONG: app.current_cohort() picked the caller's most-recently-joined
-- cohort_members row REGARDLESS of role. That means:
--   * A faculty member (creators auto-join their own class as 'faculty') who
--     also does practice or a mock would have that activity attributed to the
--     class they teach -- silently polluting their own efficacy rollups,
--     cohort_overview counts, domain stats, and top-misses.
--   * A user who is a student in one class and faculty in another could have
--     their genuine student activity tagged to the class they merely teach.
--
-- Fix (smallest correct change): scope the lookup to role = 'student'. This is
-- a single create-or-replace of the shared helper, so it corrects mock_attempts
-- AND answer events AND review events in one place, consistently. Signature is
-- unchanged, so all grants and callers are unaffected.
--
-- Trust boundary preserved: still SECURITY DEFINER, still derived server-side
-- with no client input; no RLS changed; no answer keys exposed; events remain
-- append-only (no grant changes).
--
-- ⚠️ UNAPPLIED. This file is a migration for founder review. It has NOT been
--    run against the live database. Apply manually after review.

create or replace function app.current_cohort(p_user uuid) returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  -- Multi-cohort rule: a student may belong to several classes. Attribute
  -- activity to the MOST RECENTLY JOINED cohort in which the caller is a
  -- STUDENT (greatest joined_at, ties broken arbitrarily). Faculty memberships
  -- are excluded, so an instructor's own practice never lands in the efficacy
  -- rollups of the class they teach; an instructor with no student membership
  -- yields NULL (activity stays untagged rather than mis-attributed).
  select cohort_id from public.cohort_members
  where user_id = p_user and role = 'student'
  order by joined_at desc
  limit 1;
$$;

comment on function app.current_cohort(uuid) is
  'Cohort used to tag a caller''s graded activity (mocks + events). Returns the '
  'most-recently-joined STUDENT cohort (by joined_at); NULL if the user is a '
  'student in no cohort. Faculty memberships are deliberately excluded so an '
  'instructor''s own practice never skews the class they teach. Server-only: '
  'invoked from SECURITY DEFINER grading RPCs, never fed from client input.';
