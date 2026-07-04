# Politiface Context Packet

Single source of truth for Politiface's product, architecture, and strategic context. Written to bring a coding agent (Claude Code) fully up to speed with zero prior context.

State reflects July 2026. House style rule for all Politiface written content: no em-dashes (use commas, periods, semicolons, colons, or parentheses).

Companion docs at repo root: `NEAR_TERM_EXECUTION_PLAN.md` (the current build plan), `POLITIFACE_GAME_VISION.md` (deferred long-term "as a game" north star), `V2_MONETIZATION.md` (monetization research + model), `CODEBASE_BRIEF.md` (v1 recon).

---

## TL;DR

Politiface is a live civic-education iOS app pivoting from a broad "global political literacy" concept into a focused wedge: FCLE prep for Florida college students. The broad vision (a comprehensive civic reference platform called Atlas) is the long game the wedge funds. A professor at Miami Dade College (Purcell) is championing it, wants specific features built, and intends to take it to the department president for a possible institution-wide license. The near-term engineering priorities are all downstream of that: build the FCLE prep system and a richer Atlas, keep the data footprint minimal, make it accessible (WCAG 2.1 AA), and stand up the plumbing to measure whether the app actually raises pass rates.

## What Politiface is

- Civic-education iOS app. Live on the App Store. Open-sourced under MIT (deliberate trust mechanism, the content is auditable).
- Product thesis: FCLE prep is the beachhead; Atlas (a comprehensive, cited civic reference layer) is the platform. They are two layers over one taxonomy, not two products.
- Status: V1 shipped (FSRS spaced repetition over a government-as-node-graph content model; decks now span executive, legislative, judicial). V2 in active development.

## Team

- Rissalat (real name; publishes under it): technical lead. Toronto / Mississauga, Canada. BSc Computer Science, CAPM.
- Dawood Shah (persona/pen name "Bashir"): content, community, marketing. Fort Lauderdale. Studies International Relations at Miami Dade College. On F-1 student status (constrains how he can be publicly named commercially, see Standing Rules).

## Tech stack

- Frontend: Flutter (iOS now; Android and a web app/faculty portal later)
- Backend / data: **Supabase-centric** (Auth + Postgres + RLS + Edge Functions + pg_cron + Realtime). **Django/Redis/Railway dropped for now** (revised 2026-07-02): not needed at this scale and they add cost/ops/failure surface. Add a dedicated API service and/or Redis only when a measured need appears. See `ARCHITECTURE.md`.
- IAP / entitlements: RevenueCat (payment-agnostic entitlement layer; do not hand-roll StoreKit)
- Learning engine: FSRS-4.5 spaced repetition
- Content model: government-as-node-graph; YAML files as canonical source of truth (ingested to Postgres via CI). **Append-only event log is the spine**: progress, streaks, leaderboard, readiness, and efficacy are all derived from it.

## Architecture: the seven V2 epics

Organized around the FCLE structure (80 questions, four domains, 60% to pass) as the shared spine. Prioritized with WSJF.

1. Identity and Accounts (the unblocker): Supabase Auth, profiles, progress persistence. Unblocks epics 3, 4, 6, 7.
2. Atlas Reference Engine: entity schema, executive orders (via Federal Register API), vocabulary, cabinet, structure, citations.
3. FCLE Prep System: four-domain taxonomy, tagged question bank, Mock FCLE, readiness indicator, weak-area practice.
4. Monetization and Entitlements: RevenueCat layer supporting three models held open.
5. Competition: school-scoped leaderboards.
6. Content Production Program: the pipeline feeding the app and the social channel.
7. Educator Tools: (a) domain-level weakness feedback so professors see what their cohort gets wrong (which of the four FCLE domains is weakest, highest-miss objectives), derived from the same append-only event log that feeds efficacy; (b) custom question sets educators build and scope to their own cohorts via a draft -> review -> publish authoring pipeline. Both deepen institutional stickiness and give the professor first-class value beyond the student experience. Cohort-aggregate only (no education records) to stay FERPA-light. The lightweight version ships early; full instructor dashboards are the institutional-infrastructure epic (deferred until the deal firms).

Load-bearing insight: Atlas and the quiz engine sit on one taxonomy. Build the taxonomy once.

## The strategic situation

The play. Adapted from Nikita Bier's tbh/Gas playbook: dominate one dense node rather than spreading thin. The node is the required American Government course cohort at Miami Dade College North (not a whole campus), reached through Professor Purcell. Launch at peak exam attention, open straight into value with no signup wall, saturate that one node across every channel at once, and engineer a share mechanic (the score-challenge "I got X, beat me" is the candidate).

Current traction. A dozen-plus organic downloads at Miami Dade College. Social content on Instagram and TikTok (@playpolitiface) is gaining traction.

The champion: Professor Purcell. Teaches many politics courses across several Miami Dade College campuses. Advised concretely to: (1) build the FCLE curriculum into the app, (2) add executive orders, (3) make Atlas a richer, expansive, comprehensive general political reference usable beyond FCLE. Once these are integrated he will have all his students use it and take it to the department/program president.

The buyer: the department/program president. Motivated by recognition and clout. Architected so the president is the hero and the founders are near-invisible: he "champions an innovation" and gets credit upward. The asset that makes his clout real is efficacy data. "I brought in a tool that moved our FCLE pass rates" is the career story. This is why efficacy measurement is a first-class engineering priority.

Amplifiers. Campus newspaper (front-page possible; angle is students/civic-education or faculty-innovating, not a startup profile; keep the commercial license lane separate; F-1 caution on naming Dawood). Paid priming (modest, student-native, mere-exposure before decision-maker meetings; do not overspend).

Credibility partnerships. Endorsements and content collaborations with established nonpartisan civic organizations: the National Constitution Center, iCivics, public libraries, and immigrant-services / naturalization nonprofits. Two kinds of value. (1) Credibility that de-risks institutional adoption: the president approves a tool that recognized civic bodies already trust, and the co-sign reinforces (never dilutes) the nonpartisan-trust moat. (2) Distribution into an adjacent market: libraries and naturalization nonprofits reach USCIS citizenship-test prep audiences beyond the FCLE wedge, and iCivics also ties into civic-ed grant funding (see `V2_MONETIZATION.md` Rails 3 and 5). Pursue these as logos/endorsements/bundles, not revenue dependencies, and vet each partner for strict nonpartisanship before associating the brand.

Goal. An institutional license covering the whole institution or multiple branches.

On the "vision divergence" worry: the professor is asking us to build Atlas. The rich comprehensive reference layer IS the platform vision. Only the monetization model and sequencing shift (institutional license + faculty-led distribution now, consumer viral later), not the product.

## Compliance and constraints that shape the build

Engineering-critical, not legal footnotes.

- Data minimization is the master constraint. Store as little student data as possible. No sensitive PII beyond strictly needed, no synced student education records if avoidable, lean progress data, ideally not tied to institutional identity in the early pilot.
- Florida student data privacy (hard rule). Never collect political affiliation or voting history. Prohibited under Florida law and especially sensitive here. No exceptions.
- FERPA. Only triggers if the app touches student education records under the school-official exception (then requires a DPA). Prefer an architecture that avoids this in the pilot. Have a DPA template ready.
- Accessibility (WCAG 2.1 AA). Live legal obligation for public institutions (DOJ 2024 ADA Title II rule, phasing 2026-2027). Build accessible from now. Procurement deliverable is a VPAT.
- HECVAT 4.1.5 (Feb 2025). The de facto higher-ed vendor security self-assessment. A Triage tab routes by data classification, so a data-minimal design lands in the lightest tier. Covers security, privacy, IT accessibility (WCAG 2.1 AA), FERPA, GLBA, AI governance.
- AI governance. HECVAT 4 has an AI section. Document what any LLM does and does not touch (Atlas generation, question authoring, Claude-assisted pipelines).
- NOT needed now: SOC 2 (five-figure audit, commercial not legal, later), PCI DSS (payments run through Apple IAP / RevenueCat), GLBA (no financial-aid data).

## What needs building now (prioritized by leverage toward the deal)

1. Data-minimal architecture. Foundational; do first, it constrains everything.
2. Efficacy measurement plumbing. The spine of the sale. Baseline + first-attempt pass-rate lift for a cohort: usage, mock performance, domain readiness, engagement. Output an exportable one-pager Purcell can carry into the president's office.
3. FCLE Prep System. Four-domain taxonomy, tagged question bank, Mock FCLE, readiness indicator, weak-area practice.
4. Educator tools (lightweight, Purcell-facing). Domain-level weakness feedback: a per-cohort view of which domains and objectives students miss most, derived from the same event log that feeds efficacy (cohort-aggregate, no education records). Plus custom question sets educators author and scope to their own cohorts (draft -> review -> publish with provenance). High stickiness, directly aligned to what Purcell asked for, light data footprint. Full instructor dashboards are item 8.
5. Executive orders + richer Atlas. Cited civic reference (executive orders via Federal Register API, vocabulary, cabinet, structure, citations). Evergreen, multi-course, justifies a recurring license.
6. Accessibility to WCAG 2.1 AA. Start early. Output a VPAT.
7. Adoption and virality. School-scoped leaderboards (server-validated scoring), score-challenge share, no-signup-wall onboarding into "can you actually pass?".
8. Institutional infrastructure (when the deal firms, not before). SSO, LMS/LTI (Canvas/Blackboard/D2L), rostering, full instructor dashboards (extending the item-4 domain-weakness feedback), multi-section/campus scaling.
9. Monetization plumbing. RevenueCat entitlement layer supporting three models held open: institutional B2B2C (durable engine), one-time FCLE Pass (cram-pass-leave lifecycle), optional subscription (only if Atlas becomes a lasting habit).

## Reference: FCLE facts

- Exam: Florida Civic Literacy Examination. 80 questions, four domains, passing 48/80 (60%).
- Status: state graduation requirement (Florida Statute 1007.25) for undergraduate degree-seeking students at Florida public colleges and universities.
- Oversight: FLDOE governs it for the Florida College System via Rule 6A-10.02413; Board of Governors governs it for the 12 public universities via Regulation 8.006.
- Administration: state-owned, administered on campus via Cambium Assessment, free to enrolled students, unlimited retakes (7-day wait, no fee cap).
- Performance (bifurcated): high schoolers ~47% statewide pass rate; college students ~80% first attempt (Polk State, one clean data point). Wedge is first-attempt friction, testing-center inconvenience, graduation-timeline anxiety, and the institution's aggregate-metrics pressure. Free retakes cap individual willingness to pay, which is why the durable business is institutional (B2B2C).

## Standing rules and gotchas

- Neutrality and citations are adoption prerequisites, not just pedagogy. In a Florida political context, anything partisan or unsourced is unadoptable. Content stays recognition-based, factual, citation-backed.
- MIT open source is a trust lever: the institution can audit exactly what students see. Preserve it.
- Never collect political affiliation or voting history. Non-negotiable.
- No em-dashes in any Politiface-facing written content or UI copy.
- Dawood is on F-1. Be careful about publicly naming him as commercial founder/operator. "A student building a civic-education tool" is smarter and safer than "a student entrepreneur selling to the college." (Not legal advice.)
- Positioning language: "supplemental practice students choose," never "the official prep" or "classroom curriculum." FLDOE states its own materials are not curriculum and not predictors of performance; official-sounding framing invites friction.
- For the president: package everything so he approves an initiative he can take credit for, not a vendor he has to risk on. Deliverable is a decision packet: proof (adoption + efficacy + press clip) plus a ready-made upward story.
- No guaranteed deal yet. Intent is strong but unconfirmed. Sequence spend: cheap foundational work now (data minimization, accessibility, privacy policy, DPA template, security docs), let the institution's own review drive the rest.
