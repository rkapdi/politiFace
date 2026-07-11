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
