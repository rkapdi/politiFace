# Data Processing Agreement (template)

Skeleton kept ready in case an institution's review requires a DPA under
the FERPA school-official exception. Politiface's pilot architecture is
designed NOT to require one (no education records, cohort aggregates only,
pseudonymous accounts students create themselves), so the first position
in any review is that this agreement is unnecessary. TEMPLATE ONLY;
counsel must review before execution.

---

**Data Processing Agreement** between **[Institution]** ("Institution") and
**[Politiface legal entity]** ("Provider"), effective **[date]**.

## 1. Scope and roles

Provider operates a civic-education practice application that students use
voluntarily. Under this agreement, Provider processes the categories of
data listed in Section 3 on behalf of the Institution solely to provide
the service described in Exhibit A.

## 2. FERPA designation (only if applicable)

If and only if the Institution directs Provider to process education
records, the parties agree Provider acts as a "school official" with a
"legitimate educational interest" under 34 CFR 99.31(a)(1), is under the
direct control of the Institution with respect to those records, and will
not re-disclose or use them for any other purpose.

## 3. Data categories

Provider's standard service processes ONLY:

- Pseudonymous account identifiers (a generated handle; the student's email
  exists solely inside the authentication provider and is never displayed).
- Practice activity (questions answered, correct/incorrect, timestamps,
  mock practice scores), keyed to the pseudonymous identifier.
- Cohort membership via a join code the student enters voluntarily.

Provider does NOT collect: legal name, student ID, political affiliation
or voting history (prohibited and never collected under any configuration),
demographic data, location, grades, transcripts, or any institutional
education record, unless Exhibit A explicitly adds a category.

## 4. Faculty visibility

Faculty see cohort-level aggregates only (domain accuracy, participation
counts, average mock movement). The service exposes no per-student activity
view to faculty.

## 5. Security

[Standard clauses: encryption in transit and at rest, row-level access
controls, least-privilege service credentials, breach notification within
[X] days, subprocessor list in Exhibit B (hosting: Supabase; payments:
Apple/RevenueCat, which never see institutional data).]

## 6. Retention and deletion

Practice data is retained while the account is active. On written request
or contract end, Provider deletes cohort associations and, at the
Institution's election, the underlying pseudonymous activity within
[30] days, subject to legal holds.

## 7. No sale, no advertising, no profiling

Provider does not sell data, serve advertising, or build profiles for any
purpose other than the readiness features the student sees.

## Exhibits

- **A. Service description and any additional data categories.**
- **B. Subprocessors.**
- **C. Security summary (see HECVAT submission).**
