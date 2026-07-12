# Decision Log

Small notes at every strategy, product, and design decision, kept as raw material for
build-in-public posts. This realizes the "running decision log" in
`BUILD_IN_PUBLIC.md` section D, angle 1.

Format per entry: **what** we decided, **why**, and **hook** (the surprising or
quotable angle a post could open on). Keep entries to a few lines. Append newest
sessions at the top. Dates are absolute.

---

## 2026-07-09 to 07-10 — The V2 strategy turn and the FCLE content unlock

**Killed the "live in-class Kahoot" as the near-term wedge.**
Why: the FCLE is prepped for solo, not taught in class, so classroom theatre does not
serve the actual exam. Building it would have been the fun infra that avoids the real work.
Hook: "We almost built the flashy feature. Then we asked what the professor actually needed, and the answer wasn't a game show."

**Rejected a general, course-agnostic classroom tool.**
Why: it strips the content moat, forces LTI / gradebook / per-student education records onto
the critical path, and drops us into a fight with Top Hat, iClicker, and Poll Everywhere.
Hook: "Going 'general' feels bigger. It's actually smaller: you trade your only moat for a knife fight you can't win."

**Rejected proximity chat and open discussion forums.**
Why: user-generated content plus minors (app is rated 9+; the K-12 exam covers grades 6-12)
plus political discussion is a trust-and-safety catastrophe, and it attacks the one asset
everything else depends on: nonpartisan trust.
Hook: "The growth hack and the moat were the same asset. Ship one and it eats the other."

**Reframed the product as 'boundary and verdict,' not 'more content.'**
Why: our own beta user had every free resource available and still never sat the exam. The
gap isn't a shortage of material; it's not knowing exactly what's tested or when you're ready.
Hook: "The problem was never a shortage of study material. It was the absence of a finish line."

**Decoded the FCLE blueprint from the FLDOE guide's own hyperlinks: 32 official objective codes.**
Why: the exam publishes no objective codes, but the FLDOE Supplemental Guide hyperlinks every
topic to a real Florida CPALMS benchmark. Those codes are citable and impossible to invent, so
they became our objective taxonomy.
Hook: "The syllabus everyone said didn't exist was hiding in the footnote links of a state PDF."

**Copyright guardrail: never ingest the 40 official FLDOE sample items.**
Why: FLDOE withholds permission for commercial reproduction; we are commercial with a public
repo. We write original questions and cite primary sources (archives.gov, Oyez, congress.gov).
Hook: "You can't legally copy the answer key. So we rebuilt the map from the primary sources instead."

**Ran a real ARR model instead of a headline number.**
Why: naive "965k students x $5" implies $3.6M. A Monte Carlo over all 40 Florida public
institutions gives a ~$200k median at 30 months and a ~$2.2M ceiling at total victory, because
per-student pricing is concave, two-founder sales capacity binds, and procurement drags.
Hook: "Multiplying students by price overstated our revenue about 18x. Here's the model that shows why."

**Pricing insight: price UNDER the procurement threshold, on purpose.**
Why: crossing roughly $65k (a state college) or $75k (a university) triggers a formal
solicitation that slows and kills deals. Capping contracts lower barely moves the median and
collapses the downside.
Hook: "Charging more made us slower and poorer. The RFP threshold is a pricing cliff you price beneath."

**Corrected a false internal assumption: the champion professor wants it monetized.**
Why: prior notes treated the faculty relationship as anti-monetization, which was quietly
shaping a no-paywall design. He actually said to charge for it.
Hook: "We'd spent weeks designing around a constraint the customer never asked for."

**Content pipeline = author, then adversarially verify.**
Why: for a trust product the real risks are hallucinated facts, fabricated citations, and
distractors that are secretly also correct. Every generated question faces a skeptic agent
that fact-checks it, fetches the citation, and enforces nonpartisan framing before it survives.
Hook: "We don't let the AI write the quiz. We let it write, then set another AI loose to destroy it."

**Won't autopilot production-schema migrations.**
Why: the database is live in production. Readiness and cohort-attribution migrations ship as
draft PRs only, applied by a human after review. Parallelize aggressively everywhere else.
Hook: "Fan out a dozen agents, sure. But no agent applies a migration to prod unattended."

**Named the real state of the build: 90% infrastructure, 0% product.**
Why: there was a backend, an Atlas of 900+ entities, a leaderboard, and a full exam-prep UI,
but zero published questions, so a student couldn't answer a single item. Content, not code,
was the gate.
Hook: "We had a backend, an Atlas, and a leaderboard, and a student couldn't answer one question. 90% done, 0% of the product."

**Community and virality: make the daily loop social, don't host a forum.**
Why: virality comes from artifacts people share (streaks, challenge cards, results), not from
conversations we have to moderate. An open political forum manufactures the exact partisan
moment that destroys the trust moat.
Hook: "Duolingo's growth engine was never a forum. It's a streak you can't shut up about."

**Layered verification caught what single-layer would have shipped.**
Why: the content pipeline's adversarial reviewer caught a hallucinated citation (a 404
archives.gov path). But a dumb follow-up "does every URL actually resolve" curl sweep then
caught two MORE dead links the smart agents missed, including one that had lived in the
hand-written question bank for weeks. Different layers catch different failures.
Hook: "The AI hallucinated a citation. A second AI caught it. Then a ten-line curl loop caught two more the smart agents missed. Trust needs a dumb layer under the clever one."

**The delegated agent corrected my premise instead of executing it.**
Why: I dispatched an agent to 'add' cohort attribution to FCLE efficacy data. It found the
attribution already existed and was already server-side, and that the real bug was subtler:
the lookup was role-blind, so a professor running a practice mock polluted their own class's
stats. It fixed the actual defect, not the imagined one.
Hook: "I told the agent to build a feature. It came back and said the feature already existed, and here's the real bug you didn't know you had."

**Set the 'you're ready' bar well above the 60% passing score, on purpose.**
Why: practice accuracy over-predicts real-exam performance (questions repeat, no timer, no
nerves, easier items). Calibrating "ready" to the pass line would hand students false
confidence and fail them on a graduation requirement, which would also kill the pass-rate
efficacy story we sell to the institution. So "solid" is 85%+, not 60%+. Recalibrate later
against real baseline-to-outcome data.
Hook: "Our app tells you you're ready at 85%, not 60%. An exam-prep tool that celebrates the passing score is lying to you, and it'll get you failed."

**No 'percent ready' number. Coverage and a next step instead.**
Why: any single readiness percentage reads as a predicted exam score, which breaks our
positioning ("does not predict your score") and manufactures the false confidence above. The
verdict is what's covered, what's solid, what's untouched, and the one thing to do next.
Hook: "We refused to show a 'you're 74% ready' number. It's the most requested feature and the most dishonest one."

**Review flow: founder, then Dawood, then Purcell, never the reverse.**
Why: the questions are AI-drafted. Handing raw drafts to the champion professor as first-pass
QA would make his first real encounter with the content be spotting our mistakes. Founder gates
accuracy + brand; a trusted second reader confirms; the professor sees only clean content and is
asked to endorse, not to fix.
Hook: "Never let your most important evangelist be your QA. The first thing they touch has to be the polished thing, not the draft."

**Planning the pivot two years early, on purpose.**
Why: the FCLE trajectory tops out around $1M; the game/global vision is the path past it. But the
moves that unlock that path (grant funding, a dual-entity nonprofit/for-profit, no-regret
architecture) have lead times in quarters. If you wait for the pivot to plan the pivot, you've
already lost the runway.
Hook: "We're writing the pivot playbook two years before the pivot, because the moves that matter can't be made in a hurry."

**Shipped the bank on one reviewer, not three.**
Why: the review flow is founder -> Dawood -> Purcell, but with launch on July 25 the founder
reviewed all 80 questions against the FCLE material and shipped on his own sign-off. The
three-pass flow protects two things: accuracy (the founder pass caught that) and the rule that
Purcell only ever sees polished content (still true; his pass was endorsement, never QA, so
deferring it costs nothing). Dawood's student's-eye read still happens, it just happens on
published content and any fix ships as an edit. Ids are stable, so live corrections are safe.
Hook: "Process is a tool, not a ritual. We wrote a three-reviewer flow, then shipped on one, because the calendar is also a reviewer."
