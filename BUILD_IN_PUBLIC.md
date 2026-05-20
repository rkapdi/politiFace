# Politiface — Build in Public Drop Set

A working library of posts, threads, demos, and content angles drawn from the actual build.

Pull from this file as needed. Edit voice to match your account. Add to it as new material accrues.

---

## A) Ready-to-post tweet threads

### Thread 1 — The iCloud Catastrophe

1/ Day 1 of building **Politiface**, I lost half a day to one cryptic iOS error:

`Failed to codesign Flutter.framework with identity -`

The culprit wasn't Xcode. Wasn't my certificate. Wasn't the project file.

It was iCloud Drive.

2/ My project lived on Desktop. Desktop is iCloud-synced by default on modern macOS. iCloud silently attaches extended attributes (`com.apple.iCloud`) to every file it touches — including built `.framework` bundles.

Codesigning treats foreign xattrs as tampering. Build dies.

3/ The fix wasn't `xattr -cr`. The fix wasn't ad-hoc signing.

The fix was:

```bash
mv ~/Desktop/cCcV/politiFace ~/Developer/
```

Built clean immediately. 4 hours of debugging → 1 directory move.

4/ Lesson: when your toolchain does something inexplicable, the bug isn't always in the toolchain. Sometimes Apple is "helpfully" syncing your build artifacts to the cloud and iOS codesigning never had a chance.

If you build iOS apps on Mac, get your code OUT of Desktop/Documents.

---

### Thread 2 — FSRS Was Returning NaN

1/ Building a flashcard app means picking a spaced repetition algorithm. I picked FSRS-4.5 — Anki's current algorithm, with explicit difficulty / stability / retrievability state per card.

I implemented the formulas. All 25 unit tests passed.

Then cards started returning **NaN stability** on Hard grades. 🐛

2/ Root cause: my difficulty-update step could return a negative number for certain `(difficulty, grade)` pairs near the boundary.

The next-stability formula has `D^-0.5` in it.

`(negative)^(-0.5) = NaN`. Once a card lands at NaN it never recovers — the scheduler can't compare it to anything.

3/ The official FSRS paper says difficulty is "in [1, 10]". It doesn't say "clamp before computing stability." It's implicit.

Implicit kills.

4/ Fix was one line:

```dart
final newD = computedD.clamp(1.0, 10.0);
```

Lesson: when implementing research formulas, if the paper says "D ∈ [1, 10]" — **actively enforce that bound** in code. Don't assume your inputs stay in range. They won't.

---

### Thread 3 — Stuck at 4/5 on Pam Bondi

1/ Beta tester: "Card 4 of 5 won't advance. App frozen on Pam Bondi."

The session queue I'd built had a 10-minute "recent" buffer — a card you just saw can't reappear in the same session too soon. Reasonable, right?

It also had an infinite loop. 🙃

2/ With 5 cards total + 10-min cooldown, by card 4 sometimes ALL remaining cards were in the cooldown buffer.

The queue would pop one, see it was too recent, push it back, pop the next, see it was too recent, push it back. Forever.

3/ Fix: budget the loop.

```dart
var budget = heap.length;
while (budget-- > 0) {
  final c = heap.removeFirst();
  if (!_recent.contains(c.id)) return c;
  heap.add(c);
}
return heap.isNotEmpty ? heap.removeFirst() : null;
```

After budget exhausted, return whatever's available — cooldown be damned.

4/ The deeper lesson isn't "watch for infinite loops."

It's: **your cooldown constants assume a population size you don't actually have**. 10-min cooldown is fine with 200 cards. With 5 cards it deadlocks.

Constants embed assumptions. Test the assumption.

---

### Thread 4 — Why I'm launching Politiface iOS-only

1/ **Politiface launches iOS-only.**

Counterintuitive — Flutter gives you Android free. Why throw that away?

2/ Three reasons:

- US political literacy is the target. iOS has ~60% of US smartphones (and skews demographically toward the user we want)
- Android = extra cert chain, Play Store review, testing matrix, support burden ≈ 30% more surface area
- Most painful: any cross-platform UI bug becomes 2× to investigate

For v1, single platform = faster iteration.

3/ When does Android come back?

When the iOS funnel is converting AND Android's slice would meaningfully change DAU.

Not before.

It's not a moral position. It's compute allocation. Every hour spent on Android-specific bugs is an hour not spent making iOS sticky.

---

### Thread 5 — The Memory Field

1/ Spaced repetition is invisible.

You review cards, an algorithm decides when you see them next, and you're supposed to trust it.

That's a terrible UX.

So I built the **Memory Field** — a live visualization of your memory according to the algorithm. [video]

2/ Each card you've reviewed becomes a glowing dot. Distance from center = mastery (logarithmic). Five concentric rings mark mastery tiers ★1–★5. They're labeled.

The whole field rotates slowly (one revolution per minute). Each dot breathes on a desynchronized cycle so the field never looks static.

3/ A radar beam sweeps across — one revolution per 10 seconds. When it crosses a card, that card brightens, glow expands, color whitens slightly, then fades.

It feels like watching a working instrument.

4/ The most analytical piece is the smallest: a **thin colored arc** around each dot.

It's your live retrievability for that card.

- Full circle = ~100% recall probability right now
- Half = 50%
- Sliver = you're about to forget it

You can watch the arcs shrink over hours and days. The algorithm is no longer a black box. It's a diagram of your knowledge decaying and renewing in real time.

5/ Implementation: one `CustomPainter`, three `AnimationController`s (rotation 60s, breath 3s, sweep 10s), and one function call per frame:

```dart
retrievability = 1 / (1 + days_since_review / (9 * stability))
```

~380 lines total.

The win isn't engineering complexity. It's choosing to **visualize** what other apps treat as backend bookkeeping.

---

### Thread 6 — Phase 1: Skipped

1/ My build plan had a Phase 1: build a throwaway learning app first to get Flutter under your fingers.

I skipped it. Jumped straight to Phase 2+3 — real DB, real FSRS, real session loop.

I think that was the right call. Here's why:

2/ Throwaway projects sound wise but they're a tax. You internalize patterns that won't survive contact with your actual data model. You build for an imaginary domain, then rebuild for the real one.

If the goal is "learn Flutter," the best teacher is **building your actual app, page by page, fixing every error as it appears.**

3/ Exception: if your stack involves multiple unfamiliar technologies AND they interact in subtle ways, a throwaway helps.

For Politiface my new surface was just Flutter wiring — Drift/Riverpod/FSRS were all learnable from the real domain.

Net new complexity didn't warrant a throwaway.

---

### Thread 7 — Don't Mock Your Database

1/ The Drift (SQLite) tests for Politiface don't mock the database.

They run against `NativeDatabase.memory()` — a real SQLite, just in RAM.

Costs maybe 50ms per test. Has saved me from at least three subtle bugs that mocks would have hidden.

2/ Example: my repository updates `card_memory_state` AND appends a `review_log` in one transaction.

With a mock, two "the method got called" assertions pass.

With a real DB, you discover what happens when the second insert fails. **Mocks lie about transactional behavior.**

3/ Rule: if a layer's whole job is "talk to a database," don't mock the database.

It's not slower. It's not flakier.

A test that says "the query I wrote returns the rows I expected" is worth 10 tests that say "we called `.insert()`."

---

### Thread 8 — Build-in-Public Meta

1/ I'm documenting **Politiface** in public — every decision, every bug, every "why this and not that."

Politiface is a political literacy flashcard app (Duolingo for US government). Solo build. iOS-first. Spaced repetition under the hood (FSRS-4.5).

Follow along →

2/ What you'll see:

- Bug stories with the actual fix
- Tradeoff posts ("why iOS-only", "why I skipped Phase 1")
- Design walkthroughs (the Memory Field, the radar sweep, the share artifact)
- Screenshots and videos as features ship

3/ Why bother documenting?

Because the build-in-public posts I learn from are concrete: code, screenshots, specific decisions.

Not vibes. Not "I'm thinking about ___".

The build IS the marketing. If the work is interesting, the audience builds itself.

---

## B) Long-form posts

### Drafted — "How I Made Forgetting Visible"

Spaced repetition apps have a UX problem. The algorithm — usually FSRS or SM-2 — is doing extraordinarily clever bookkeeping about your memory. Every card has a stability, a difficulty, a retrievability. The algorithm knows, with surprising accuracy, whether you'd remember this card right now, in 3 days, in a month.

And then the UI shows you... a number. "Next review: 4 days." Maybe a small graph.

I built Politiface because I think this is a missed opportunity. The algorithm has a vivid model of your memory; the UI should let you SEE that model.

So I built the Memory Field.

Each card you've reviewed becomes a dot. The dot's distance from the center is logarithmic in stability — newly-mastered cards float close, cards you've held for months drift to the edge. Five concentric rings mark the mastery tiers: ★1, ★2, ★3, ★4, ★5. They're labeled in small chips.

The whole field rotates slowly — one revolution per minute. Each dot breathes on a desynchronized cycle, so the field never looks static. A radar beam sweeps across (one revolution per 10 seconds), brightening each dot as it passes. It feels like watching a working instrument.

The most analytical piece is the smallest: a thin colored arc around each dot. The arc is your live retrievability for that card. Full circle: you'd remember this with near certainty. Half: 50% chance. A sliver: you're about to forget it.

You can literally watch the arcs shrink over hours and days. The algorithm is no longer a black box — it's a diagram of your knowledge, decaying and renewing in real time.

The technical implementation is one `CustomPainter` with three `AnimationController`s (rotation 60s, breath 3s, sweep 10s) and one function call per frame: `retrievability = 1 / (1 + days_since_review / (9 * stability))`. The whole file is ~380 lines.

The win isn't engineering complexity — it's choosing to visualize something other apps treat as backend bookkeeping.

The closer you get to representing your actual data faithfully, the more your UI starts doing your marketing for you. People screenshot the Memory Field. They don't screenshot a number.

---

### Outline — "Building a 5-Card MVP"

- The first version of Politiface had 5 cards. Trump, Vance, Rubio, Hegseth, Bondi. That's it.
- Why so few? Because the whole point of v0 is to prove the **session loop**, not the content library.
- What I learned: even 5 cards reveals 80% of the bugs you'll hit at 500 cards. The cooldown deadlock, the NaN stability, the sync race conditions.
- The content library is a separate, parallelizable problem — and one that doesn't unlock until the engine is right.
- Counterintuitive: when people see your app with 5 cards they don't say "this is empty." They say "wait, you can already DO that?"

### Outline — "Riverpod Without Code Generation"

- I'm building Politiface in Flutter with Riverpod for state — but **not using** `@riverpod` codegen.
- Why: hand-written providers are 5 lines longer and zero lines of magic. When you're learning Flutter AND Riverpod AND your domain simultaneously, the last thing you want is one more codegen step in your mental loop.
- Examples: pure-Dart `Provider<T>`, `AsyncNotifier` subclasses, `StateProvider` for view-mode toggles.
- Cost: ~10 extra lines per provider file. Benefit: I can read my code without a `build_runner` step running in my head.
- When I'd switch to codegen: a team larger than 2, or when provider count crosses ~40.

### Outline — "Why Politiface, Why Now"

- Civic literacy in the US is collapsing — most adults can't name a senator, don't know what the Cabinet does, can't sequence the branches.
- Existing civic ed apps are quiz apps. Look-and-forget. None use real spaced repetition.
- Politics is a moving target — Cabinet members rotate every 4 years. Cards need to be **live**, sourced from a maintained YAML library.
- Duolingo proved the streak-driven gamified-learning model works. Same UX, applied to civic facts, has never been done well.
- Thesis: if you make remembering politicians as habit-forming as a Duolingo streak, you lift the floor of civic awareness. That's the goal.

---

## C) Demo videos / screenshots worth capturing

| Asset | Length | Where it ships | Why it works |
|---|---|---|---|
| Memory Field slow-drift | 15–20s | Twitter/X, threads, About page | Hypnotic. The arcs + radar + rotation read as "a working instrument." |
| Endless mode session | 30s | Twitter, demo reel | Back-to-back correct answers + streak counter ticking up. Hook caption: "the never-ending civics quiz" |
| Daily Challenge share artifact | static screenshot | Twitter quote tweets | Wordle-style emoji grid. Native virality format. |
| System view animated flow | 10s | Threads, blog | Eagle-eye of US gov with dots flowing along edges. Visually rich; conveys depth. |
| Mastery dot plot | static or 5s scroll | Bug-of-the-week threads | "N ready to advance →" callouts are proof of analytical depth. |
| Streak hero before/after | 2 stills | Onboarding posts | Slate → red/orange gradient. Conveys "your work shows here." |
| "Stuck at 4/5" bug + fix | screenshot + diff | Engineering thread | The before/after of a debug story always lands. |

---

## D) Angles you're missing

1. **Running decision log.** Every non-obvious tradeoff, two lines: what, why. People love decisions, not summaries. You've already made ~12: skipped Phase 1, iOS-only, hand-written Riverpod, hardcoded seed, real DB in tests, NOT NULL backfill approach, casino animations, Endless mode framing, etc.

2. **Bug-of-the-week thread.** Pick the most instructive bug each week. Symptom → diagnosis → fix. You have at least 6 great ones banked (iCloud xattrs, FSRS NaN, infinite loop, codegen "* 2.dart" duplicates from Finder, lints failing CI, notification permission silently revoked).

3. **AI/Claude Code transparency.** You're building this with Claude Code in the loop. Some founders hide that; the smart ones lean in. Post about what AI did well, what it got wrong, what you had to redo manually. Vastly underserved content vein right now.

4. **Pre-launch metrics curve.** Even before launch: lines of code, tests passing, commits per week, files in repo. People love watching curves climb. Post a weekly chart.

5. **"User is me" period.** Honest content about being your only user. What surprised you when you actually used your own app daily for 2 weeks? What made you pivot?

6. **Roadmap thread.** Not a wall — a punchy 5-bullet "v1.1, v1.2, v1.3 are about ___". Helps people commit to your story.

7. **Pricing-thinking-out-loud post.** Even if v1 is free, post your reasoning. "Free until 1k DAU then ___". Eventually-paying users want to see this thinking before they trust you.

8. **Dev environment teardown.** Flutter + FVM + Drift + Riverpod + Codemagic + Sentry + GitHub Actions. Show the actual `pubspec.yaml`. People with similar stacks lurk for this.

9. **CI war story.** Your `flutter analyze | tee | grep` hack to dodge `--fatal-infos` while keeping warnings fatal. One tweet. Self-contained.

10. **Brand/icon journey.** Once you commission real artwork, post the iterations. Logo evolution threads do well.

11. **The skipped-pricing post.** "Politiface is free during v1. Here's exactly when I'd add pricing and what I'd charge for." Pre-commits you to a model; signals seriousness.

12. **Counterintuitive learning post.** "I built a memorization app. Three things I now believe about how memory actually works that I didn't before." Almost always lands.

---

## E) Cadence recommendation

- **Daily:** one screenshot or one-paragraph "today I learned" (5 min effort)
- **Weekly:** one bug story OR one decision log post (20 min)
- **Biweekly:** one feature demo video (30–60s of footage + caption) (30 min)
- **Monthly:** one long-form post pulling from the week's threads

Total: ~2 hours/week of content for the rest of the build.

Front-load this week — you have ~3 months of backlog worth shipping. Post Threads 1–3 (iCloud / FSRS NaN / Stuck at 4/5) on three consecutive days; you'll have momentum before you've spent an hour.
