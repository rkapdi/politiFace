# Teaching Loop Attribution: Design

Date: 2026-07-31. Status: approved. Scope: database schema + enforcement chokepoints for the educator teaching loop (instructor-selected inputs, immediate/7-day/21-day measurement, hold-out items, policy-gated reporting).

## Problem

Instructors need to know whether what they taught in a specific class session landed, for which students, at which FCLE standards, in time to reteach. An immediate score overstates learning (recency effect); defensible retention numbers need delayed checks at 7 and 21 days measured on items the student has not seen since the session. The existing practice surfaces (FSRS reviews, drill, weak-area practice, mock exams) would contaminate those checks by resurfacing the same items during the interval.

Separately: reporting resolution must be configurable per cohort. Some instructors need per-student, actionable output; some institutions want aggregate-only. One architecture must serve both.

## Principle

Collect once at full resolution; disclosure is policy. Every answer is an event in the existing append-only `events` log (already idempotent via client-generated `event_id`, already server-graded). Attribution objects give events context. Reporting reads are gated server-side by a per-cohort policy. Nothing is pre-aggregated at write time.

## Schema (additive only)

### `teaching_inputs`
One row per instructor-selected body of material. `id, cohort_id, created_by, title, kind ('bank_set' | 'custom_quiz' | 'mixed'), taught_on date, created_at`.

### `input_items`
Which questions belong to an input and their measurement role. `input_id, question_id, slice ('session' | 'holdout_7' | 'holdout_21')`, PK `(input_id, question_id)`. Slices are assigned server-side (shuffled) at input creation, so the hold-out is decided before any student sees anything, which is what makes the methodology defensible. Students can never read this table.

### `assessments`
The measurement moments, all three created upfront when the input is created. `id, input_id, cohort_id, phase ('immediate' | 'check_7' | 'check_21'), mode ('live' | 'async'), live_session_id nullable, question_ids jsonb snapshot, opens_at, closes_at`. Unique `(input_id, phase)`. The immediate assessment carries the `session` slice and links to a live session; checks carry their hold-out slice and run async (students complete on their phones during the open window), so delayed data survives a student missing class. Students can read an assessment only once it opens.

### Spine changes
- `events.assessment_id uuid` nullable FK: check answers flow through the existing `submit_answer` grading path carrying this reference.
- `live_sessions.input_id uuid` nullable FK: a live session can be the immediate assessment of an input.

### Reporting policy (on `cohorts`)
- `reporting_resolution: 'per_student' | 'pseudonymous' | 'aggregate_only'`
- `identity_display: 'roster' | 'display_name' | 'pseudonym'`
- `raw_retention_days int null` (null = retain; otherwise raw responses roll up and purge after N days)

Enforced inside the faculty-facing report RPCs, never client-side.

## Hold-out enforcement: one chokepoint

An item is locked for a student when it belongs to a `holdout_*` slice of an input in one of their cohorts and that slice's assessment has not yet closed. Enforcement is belt and braces:

1. `locked_question_ids()` RPC returns the caller's current locked set. Server-assembled queues (mock assembly, weak-area) exclude it server-side.
2. The client syncs the locked set (existing cross-device state channel) and every locally assembled surface (drill, FSRS queue, practice from the bundled bank) filters through ONE shared function. No practice surface may select items except through that chokepoint.
3. Check delivery reads `assessments.question_ids` directly and bypasses the lock by design (the check is the one place a held-out item appears).

Known residual risk, accepted: a locked set synced to the device reveals question ids to a sufficiently motivated student with a jailbroken workflow; ids are opaque and the pilot cohort threat model does not include reverse engineering. Offline drill on a device that has never synced the lock set can leak; the pilot cohort is online-first and exposure events are logged, so any leakage is detectable and reportable rather than silent.

## Honest-claims constraint

All instructor-facing copy presents results as "response to this session," never "caused by this session." This is a UI-copy rule with the same status as the no-em-dash rule.

## Data flow

Input created (RPC assigns slices, creates 3 assessments) → live session runs the immediate phase (answers graded via existing path, stamped with `assessment_id`) → day 7 window opens, students prompted, async check answers stamped → day 21 same → every report is a read: input → assessments → events joined to `input_items` and `objectives`, gated by the cohort's reporting policy. Longitudinal traces chain inputs by `taught_on`.

## Error handling

- Input creation is transactional: input, items, and all three assessments commit together or not at all.
- `submit_answer` with an `assessment_id` validates: assessment open, caller a cohort member, question in the assessment snapshot. Replays stay idempotent on `event_id`.
- A check that a student never completes is missing data, not zero: report queries count denominators from actual responses per student.

## Testing

- SQL: assertions in the migration validate slice assignment invariants (counts, disjointness) via the RPC on a seeded cohort where local tooling allows; otherwise covered by the existing supabase test harness.
- Dart: the chokepoint filter gets unit tests (locked ids excluded from every queue assembler); orchestrated check flow gets a widget test with a faked clock.
- The contamination invariant gets a dedicated test: no practice surface can emit a locked question id.

## Out of scope (follow-on work)

Interpreted output view (reads over this schema), check reminders, instructor input-builder UI, item analytics instrumentation, multi-campus rollup, retention purge job.
