# Politiface Near-Term Execution Plan

*Draft 2026-07-02. Reconciles the Context Packet (`CLAUDE.md`) with the prior strategy work. House style: no em-dashes.*

## The one objective
Convert Professor Purcell's enthusiasm into a signed institutional license by producing a **decision packet** the department/program president can carry upward: proof of **adoption** + a first-attempt **pass-rate/readiness lift** + a **press clip**, packaged so he is the hero. Every near-term engineering choice is scored by how much it moves that packet.

## Juxtaposition: packet vs. our prior strategy work
- **Strong convergence (validates the direction):** FCLE = wedge, Atlas = platform, one shared taxonomy, institutional B2B2C as the durable engine, nonpartisan-cited content as the moat, RevenueCat entitlement layer, data-minimal/privacy, content as the long pole. The packet and our independent analysis agree.
- **Three additions the packet brings that reshape the plan:**
  1. **Efficacy measurement is the product, not a feature.** The president buys a pass-rate story. This was under-weighted in our earlier feature-first framing. It now leads.
  2. **Compliance is architecture, not paperwork.** Data-minimization + WCAG 2.1 AA + HECVAT 4.1.5 + FERPA-avoidance are design constraints that, done right, make procurement cheap. Same choices that minimize data also pass the HECVAT.
  3. **The specific node + president-as-hero motion** (tbh/Gas saturation of the MDC North American Government cohort; the decision packet as the close). Sharper GTM than our general "faculty channel."
- **Now clearly deferred:** the "Politiface as a game" / civic-agency vision, energy/dopamine mechanics, and the mass-consumer/global expansion. Captured in `POLITIFACE_GAME_VISION.md`. The FCLE + executive-orders + expanded-Atlas work IS early construction of that vision's "Power Graph," so no wasted effort.

## Two architectural decisions to make first (they gate schema)
1. **Efficacy vs. data-minimization (the core tension).** Resolution: **pseudonymous per-user accounts** (enough to measure a single student's baseline-to-final improvement over time) with **cohort-level aggregate reporting only**, **no education records**, and **no institutional identity linkage in the pilot**. This measures longitudinal lift while staying out of FERPA and keeping the HECVAT in its lightest tier.
2. **How to prove "pass-rate lift" when the real FCLE is Cambium-administered and the app cannot see official results.** Resolution: a **two-part efficacy story**. (a) The app owns the **leading indicator**: baseline Mock FCLE -> final Mock FCLE readiness lift + usage + domain mastery, per cohort. (b) The **institution supplies the outcome**: aggregate cohort FCLE pass rates (the president has access and is motivated to pull them). Efficacy is a collaboration; design the app to produce (a) cleanly and to correlate readiness with the outcome once the institution shares it.

## The plan, sequenced by leverage

### Phase 0 - Foundations (now, under everything; includes standing up the backend)
- **Stand up the backend (greenfield).** Confirmed 2026-07-02: no backend exists yet (v1 is local-only Flutter/Drift; only the dormant `supabase/` schema is in-repo). Phase 0 builds it **Supabase-centric** (Auth + Postgres + RLS + Edge Functions + pg_cron + Realtime); Django/Redis/Railway are dropped for now (revised 2026-07-02, see `ARCHITECTURE.md`) and added only if a measured need appears. This is the heaviest single item in the near term. Decide up front: auth model (pseudonymous), the split between content tables (canonical from YAML), progress tables, and append-only efficacy-event tables, and the YAML -> Postgres content pipeline.
- **Data-minimal schema + privacy posture.** Lock the pseudonymous-account model; never store political affiliation or voting history; lean progress data. This constrains every later table.
- **Efficacy plumbing designed up front.** You cannot measure a lift you never baselined. Define the metric set now (baseline diagnostic mock, engagement, per-domain readiness, final mock) and instrument from day one. Output target: an **exportable one-pager** for Purcell.
- **Accounts (Epic 1), minimal.** Supabase Auth, pseudonymous, progress persistence. Unblocks efficacy, leaderboards, monetization. Keep it data-light.
- **Accessibility baseline (WCAG 2.1 AA) from the first screen.** Semantics, contrast, focus order, dynamic type. Note: the game-vision ink/gold palette must be re-checked for AA contrast before adoption. Output later: a **VPAT**.
- **Compliance docs track (non-eng, parallel, cheap):** privacy policy, **DPA template**, **HECVAT 4.1.5 self-assessment** draft, **AI-usage note** (document every LLM in the content pipeline), VPAT scaffold. These gate procurement and cost little now.
- **Verify current state:** what the live app has (FSRS engine, executive/legislative/judicial decks, `us_civics.yaml`) and what the `supabase/` schema already defines (confirmed: no live backend yet, and the packet is now Supabase-centric with Django/Redis dropped). Pull in the deferred `worktree-ownership-phase1` branch content (ch4-6 FCLE-domain lessons + benchmarks already authored) rather than re-writing it.

### Phase 1 - FCLE Prep System (Purcell ask #1; the student need; the efficacy instrument)
- **Build the four-domain taxonomy ONCE** (American Democracy, US Constitution, Founding Documents, Landmark Impact). Atlas and the quiz both hang off it.
- **Tagged question bank** (domain + objective + difficulty + required citation + review status).
  - **Sourcing (important, has a legal/brand trap):** "freely available" online FCLE sample exams are mostly **copyrighted**, so they cannot be copied into an MIT-open-source, citation-backed app. Use them only as a **model for style, difficulty, and coverage**, then author **original** questions grounded in **primary public sources** (the Constitution, founding documents, Federal Register EOs, official FLDOE competencies/study guide, government sites), AI-drafted + human-reviewed, each with a working citation. This satisfies the nonpartisan-cited + open-source + HECVAT-AI-governance constraints at once.
  - **Educator custom question sets (fast-follow):** let Purcell and other profs author their own questions and bundle them into **custom sets scoped to their own cohorts**, via a draft -> review -> publish pipeline with provenance. More than one-off questions: a professor can align practice to what they actually taught. Deepens institutional stickiness; not required for the first pilot.
  - Reuse existing decks + the phase7 branch content as seed.
- **Mock FCLE** (80Q, 4x20, 60% pass, no in-session repeats). This doubles as the **efficacy baseline/retest instrument**, so build it early.
- **Readiness indicator + weak-area practice** (per-domain), computed from recent accuracy.
- **Cohort domain-weakness feedback (professor-facing, lightweight):** a per-cohort view showing which of the four domains and which objectives students get wrong most, plus the highest-miss items, derived from mock/practice results via a class join code. **Cohort-aggregate only, no per-student education records**, so it stays FERPA-light and HECVAT-light while giving Purcell direct value ("here is where my class is weak"). Reuses the efficacy event log. Full instructor dashboards (per-student, assignable practice, gradebook) are deferred to Phase 5.
- **Positioning in copy:** "supplemental practice students choose," never "official prep."

### Phase 2 - Executive Orders + richer Atlas (Purcell asks #2 and #3; justifies a recurring license)
- **Entity schema on the same taxonomy** (documents, cases, executive orders, people/cabinet, vocabulary, government structure), every entry cited.
- **Executive Orders section** via the free **Federal Register API** (number, president, date, plain-language summary, status, affected agencies), with a "last verified" freshness timestamp.
- **Comprehensive, evergreen reference** usable across multiple courses. This is what makes it a **recurring** institutional license rather than a one-time pass.

### Phase 3 - Adoption and virality (saturate the node, timed to peak exam attention)
- **No-signup-wall onboarding:** open straight into a diagnostic "can you pass?" mock before asking for an account.
- **School-scoped leaderboard** with **server-validated scoring** (never trust the client).
- **Score-challenge share mechanic** ("I got X, beat me") as the engineered social loop.
- Saturate Purcell's American Government cohort at MDC North across every channel at once.

### Phase 4 - The decision packet (the actual close)
Assemble adoption metrics + the efficacy result (readiness lift + institution's aggregate pass-rate outcome) + the press clip into a president-ready packet: equal parts proof and a lift-and-use upward story. Keep the commercial lane separate from the public story (F-1, conflict-of-interest optics).

### Phase 5 - Institutional infrastructure (ONLY when purchase intent firms)
SSO, LMS/LTI (Canvas/Blackboard/D2L to the gradebook), class rostering, instructor dashboards (class readiness, weak domains, assignable practice, completion), multi-section/multi-campus scaling. Do not build speculatively; let the institution's own review pull these.

### Cross-cutting - Monetization plumbing
Stand up the **RevenueCat payment-agnostic entitlement layer** now (cheap, and it powers pilot comp/redemption codes so students see no paywall). Hold the three pricing models open; do not finalize prices until the deal shape is known.

### Cross-cutting - Credibility partnerships
Pursue endorsements and content collaborations with established nonpartisan civic organizations: the **National Constitution Center, iCivics, public libraries, and immigrant-services / naturalization nonprofits**. Two payoffs: (1) **credibility** that de-risks institutional adoption (the president approves a tool recognized civic bodies already trust) and reinforces the nonpartisan-trust moat; (2) **an adjacent distribution channel** into USCIS citizenship-test prep via libraries and naturalization nonprofits, beyond the FCLE wedge. iCivics also connects to civic-ed grant funding (see `V2_MONETIZATION.md` Rails 3 and 5). Treat these as logos/endorsements/bundles, not revenue dependencies; vet each partner for strict nonpartisanship before associating the brand. Cheap to start (outreach, not engineering); begin once there is a shippable demo to show.

## Sequencing principle
Cheap, foundational, reversible work now (data minimization, accessibility, efficacy plumbing, privacy policy, DPA template, HECVAT draft, entitlement layer). Let the institution's own procurement review drive the heavy infrastructure. No SOC 2, no PCI DSS, no GLBA at this stage.

## Immediate next actions
1. Lock the two architectural decisions above (pseudonymous accounts; two-part efficacy story).
2. Design the efficacy metric set + the exportable one-pager format (work backward from what Purcell hands the president).
3. Define the four-domain taxonomy + entity schema (build once), then audit existing content/decks + the phase7 branch against it to size the question-bank gap.
4. Start the compliance docs track in parallel (privacy policy, DPA template, HECVAT 4.1.5, AI-usage note, VPAT scaffold).

## Resolved 2026-07-02
- **Backend:** not stood up; Phase 0 builds it greenfield, Supabase-centric (Auth + Postgres + RLS + Edge Functions + pg_cron + Realtime). Django/Redis/Railway dropped for now (see `ARCHITECTURE.md`); add a dedicated API service or Redis only on a measured need.
- **Purcell data:** he will provide whatever data we need. Governance note: even so, prefer to ingest the exam outcome as **cohort aggregate** (or via pseudonymous keys), not identified student education records, to stay out of FERPA/DPA territory and keep the HECVAT light.
- **Question source:** start from freely available online FCLE sample/practice exams as a **coverage/style model only**, authoring original cited questions from primary public sources (copyright + open-source + citation constraints). Later, profs add their own questions via the authoring pipeline.

## Still open
- **Target exam window** = the calendar point when Purcell's cohort actually sits the FCLE. It anchors the whole pilot timeline: baseline diagnostic at cohort start -> usage period -> final mock -> real exam -> outcome data. Need the term/date to schedule the saturation launch and the baseline.
- Content authoring/review **throughput owner** for the original question bank (the long pole).
