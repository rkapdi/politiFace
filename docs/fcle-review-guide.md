# FCLE Question Review Guide

How to take the 80 draft questions to publishable quality. They are AI-drafted,
machine-verified against a skeptic pass, cited to primary sources, and tagged to the
official CPALMS objectives. **Human review is the trust gate. Nothing goes live until a
human signs off**, because on a nonpartisan-trust product, one wrong or slanted question
costs more than ten good ones earn.

## Who reviews, in what order

The `status` field carries the state: `draft -> reviewed -> published`. Only `published`
questions are served to students or counted toward the Mock FCLE.

1. **Pass 1: Founder (you).** The accuracy *and* brand gate. You are the only reviewer who
   will catch the product-specific rules: nonpartisan framing and the no-score-prediction
   positioning. Mark each survivor `reviewed`; fix or cut the rest.
2. **Pass 2: Dawood.** Independent second read of the `reviewed` set. He is prepping for the
   exam himself, which makes him the ideal student's-eye fact-checker. On his confirmation,
   flip to `published`.
3. **Pass 3: Purcell (later, and only on clean `published` content).** Expert endorsement,
   not QA. The ask is "lend your expertise and your name," never "fix our mistakes." His edits
   are gold, but his review is a credibility layer, never a gate on the critical path.

## Per-question checklist

**Disqualifying (fail any one and the question must be fixed or cut):**

- [ ] **Answer is correct.** The keyed answer is unambiguously right.
- [ ] **Exactly one answer is correct.** No distractor is *also* defensibly correct. This is
      the single most common AI failure mode: an option that is "kind of right too." If two
      could be argued, it fails.
- [ ] **Citation supports the fact.** Open the URL and confirm the page actually backs the
      answer, not merely that it is a government domain. The pipeline confirmed every URL
      *resolves*; it did **not** confirm every page's *content* supports the claim. That check
      is yours.
- [ ] **Nonpartisan.** No framing implying a case, law, or policy was rightly or wrongly
      decided. Charged topics test only the neutral historical holding and its date.

**Quality (fix if weak):**

- [ ] Distractors are plausible to a novice but clearly wrong to an expert. No giveaways
      (grammatical mismatch, one absurd option, "all/none of the above").
- [ ] The question genuinely tests its tagged objective and belongs in its domain.
- [ ] Difficulty label is roughly right, and the domain has a spread (not all 1s or all 5s).
- [ ] The explanation teaches: why the answer is right and, where useful, why the tempting
      wrong option is wrong. Accurate and concise.

**Polish:**

- [ ] Stem is clear and recognition-level, reads like the real exam, not like a pop quiz. No
      em-dash (the CI already enforces this, but watch the phrasing).

## Where to spend your attention (hotspots)

- **Charged cases (verify strict neutrality):** Dred Scott, Plessy, Korematsu, Roe v. Wade,
  Bakke, Citizens United, Heller, McDonald. These are where a slanted phrasing would do the
  most damage to the trust moat. Read each twice.
- **Citations the machine could not content-verify:** every URL resolves, but the
  `constitution.congress.gov` and `senate.gov` pages block automated fetches, so no page-content
  check ran on them. Eyeball those. The tracker flags each question's citation host.
- **Assume a subtle error is hiding.** The pipeline already caught one fabricated citation and
  two dead links. Trust nothing; verify everything. A plausible, well-written, wrong question
  is the dangerous case, and these are all well-written.

## Mechanics

- **Render for review:** `python scripts/review_questions.py --domain us_constitution`
  (from PR #21) prints each question with the answer marked and the citation.
- **Flip status:** `python scripts/review_questions.py --set-status reviewed --ids id1,id2`
  then, after Dawood, `--set-status published`. It edits only the `status:` line, preserving
  formatting.
- **Track dispositions:** copy `docs/fcle-review-tracker.csv` into a shared sheet so you and
  Dawood can mark accept / edit / cut and leave notes per question.

## Dependency: the Mock FCLE needs 20 PUBLISHED questions per domain

There are exactly 20 per domain right now. **Every question you cut drops that domain below
the mock threshold**, and the mock will not assemble until it is back to 20. So:

- Do **not** publish a weak question just to keep the count. Cut it.
- Tell me the ids you cut, and I will run a small top-up: author replacements tagged to the
  same objectives, put them through the same adversarial verification, and hand you fresh
  drafts to review. Backfilling is cheap; a bad published question is not.
