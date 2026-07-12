# Compliance track

The cheap, foundational documents that gate higher-ed procurement (see
`NEAR_TERM_EXECUTION_PLAN.md`, Phase 0). Everything here is a working draft
prepared by the team, not legal advice; have counsel review before signing
anything.

| Doc | Purpose | Status |
|---|---|---|
| `AI_USAGE.md` | AI governance note (HECVAT 4 AI section) | Draft, review quarterly |
| `DPA_TEMPLATE.md` | Data processing agreement skeleton, ready if an institution requires one | Template, needs counsel pass |
| `VPAT_SCAFFOLD.md` | Accessibility conformance report scaffold (WCAG 2.1 AA) | Scaffold, fill after audit |
| `HECVAT_NOTES.md` | Answer bank for the HECVAT 4.1.5 self-assessment | Draft |

Design position that makes all four documents short: the app is data-minimal
and pseudonymous by schema. No student education records, no political
affiliation, no voting history, no PII outside Supabase Auth (email only).
Faculty see cohort aggregates, never per-student rows.
