# HECVAT 4.1.5 answer bank

Working notes for the HECVAT (Higher Education Community Vendor Assessment
Toolkit) self-assessment an institution will request during procurement.
The Triage tab routes by data classification, so the load-bearing answer
is the first one: the data footprint is minimal, which lands Politiface in
the lightest assessment tier. Keep every answer here true of the shipped
system; update alongside architecture changes.

## Data classification (Triage)

- **Data collected:** pseudonymous practice activity (generated handle,
  questions answered, correctness, timestamps, mock practice scores,
  self-entered cohort join code). Email exists only inside the managed
  auth provider (Supabase Auth) for sign-in; it is never displayed,
  never joined to activity exports, never shared.
- **Explicitly never collected:** political affiliation, voting history
  (prohibited by policy and by Florida law; there is no schema location
  for them), education records, grades, transcripts, student IDs, names,
  demographics, precise location.
- **Institutional data:** none in the pilot. Faculty views are cohort
  aggregates computed server-side.

## Security posture (summary answers)

- **Hosting:** Supabase (managed Postgres on AWS). Encryption in transit
  (TLS) and at rest (provider-managed).
- **Access control:** Postgres row-level security on every table; students
  read only their own rows; faculty read only cohort aggregates; grading
  and scoring run in SECURITY DEFINER functions so clients hold no
  trust-bearing logic. Service-role credentials exist only in CI and Edge
  Function secrets, never in the client.
- **Application integrity:** the entire client and content pipeline are
  open source (MIT), so the institution can audit exactly what students
  see and what the app does.
- **Event integrity:** the activity log is append-only (no update/delete
  grants); scores are server-computed and recomputable from the log.
- **Authentication:** passwordless email one-time codes via Supabase Auth.
  No passwords stored anywhere.
- **Payments:** Apple In-App Purchase via RevenueCat. No cardholder data
  ever touches Politiface systems (PCI scope: none).
- **Backups / DR:** provider-managed automated backups (document the plan
  tier and retention when the hosted project is provisioned).
- **Incident response:** [fill in: contact, notification window; align
  with the DPA breach clause.]
- **Subprocessors:** Supabase (hosting), Apple (distribution, payments),
  RevenueCat (entitlements), Sentry (crash reports, opt-in only, PII
  stripped), Wikimedia (public reference content fetches that contain no
  user data).

## Accessibility

WCAG 2.1 AA is the build target; the conformance report lives in
`VPAT_SCAFFOLD.md` and ships as a completed VPAT after the audit pass.

## AI governance

See `AI_USAGE.md`: AI drafts content behind a human editorial gate; no
student data ever passes through an AI system; no AI at runtime.

## Not in scope at this stage

SOC 2 (commercial audit, revisit post-deal), GLBA (no financial-aid data),
PCI DSS (no cardholder data), FERPA DPA (pilot architecture avoids
education records; template kept ready in `DPA_TEMPLATE.md`).
