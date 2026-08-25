# How Politiface measures learning

The measurement layer exists so that any number an educator or
institution sees can be audited. This page states what is measured, how,
and the invariants that are continuously verified. The implementation is
open source in this repository (`supabase/migrations/`).

## What is measured

- **Answer events.** Every graded answer (practice, mock exam, live
  session) is one append-only row: question, chosen option, correctness,
  timestamps. Correctness is decided server-side against the answer key;
  clients never grade themselves.
- **Readiness.** Per-domain readiness uses a versioned model (current:
  `v2-shrunk-w45d-cap50-p12@0.40`): accuracy over the most recent answers,
  windowed to the last 45 days and capped at 50 per domain, shrunk toward
  a conservative 0.40 prior weighted as 12 pseudo-answers. Thin or stale
  evidence therefore reads as risk, never as mastery. The student app and
  the educator console use the same model.
- **Baselines.** Each class's starting distribution of projected scores
  is captured once (aggregate histogram, average, student count; never
  per-student rows) so improvement is measured from a fixed, defensible
  starting point, with the model version recorded.
- **Positioning.** All projections are practice projections from in-app
  evidence. They are not predictions of official exam results, and
  Politiface is supplemental practice students choose, not official
  preparation.

## Invariants, continuously verified

A daily read-only canary re-checks the contract and records results:

1. Stored correctness matches the answer keys (server grading integrity).
2. No events carry future timestamps.
3. Answer events always carry question, choice, and correctness.
4. Guest (anonymous live-session) answers never enter class analytics.
5. Demo data never enters rollups, baselines, or efficacy surfaces.
6. The per-class disclosure-policy chokepoint is present.

## Privacy posture

- Per-student views are gated server-side by each class's reporting
  policy (per student, pseudonymous, or aggregate only); teaching
  assistants are always capped at aggregates.
- Aggregate statistics require at least 5 students (k-anonymity floor),
  including baselines.
- Exports of student-level reports are logged.
- No political affiliation or voting history is ever collected.
