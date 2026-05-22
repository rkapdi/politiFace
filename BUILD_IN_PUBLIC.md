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

### Thread 9 — Endless Mode: recognition vs recall, same cards

1/ Shipped a second loop today: **Endless mode**.

Primary loop is FSRS-4.5 spaced repetition — self-graded recall, finite session, due queue. Endless is the opposite shape: objectively-graded MCQs, no due queue, infinite.

Same card data. Different cognitive task.

2/ Recall ("who is this face?", type the name in your head, grade yourself) and recognition ("who is this face? — pick one of 4") are not the same memory operation.

FSRS schedules recall. Endless drills recognition. Different angle on the same underlying card.

3/ Four MCQ variants, one card pool:

```dart
enum QuestionMode {
  photoToName,
  nameToPhoto,
  titleToWho,
  photoToTitle,
}
```

That triangulates face ↔ name ↔ role. If you only know two of the three corners for a card, Endless will find the missing edge.

4/ The engine has a hard floor:

```dart
if (pool.length < 4) return null;
```

MCQ needs 4 options. With 5 seed cards, Endless works the day you install. The empty-state copy is honest about it: "Endless needs at least 4 cards in the pool."

5/ Recency buffer, take two. Same instinct as the FSRS session queue ("don't repeat a card you just saw"), but this time it can't deadlock:

```dart
var eligible = pool.where((c) => !_recent.contains(c.id)).toList();
if (eligible.isEmpty) eligible = pool;
```

If everything's recent, just pick from everything. No budget loop needed.

6/ Why ship a second loop instead of more content?

Because a session has a commitment cost — you're agreeing to grade yourself N times. Endless has none. Tap, tap, tap. It's the warm-up that gets you to the real session.

One memory model, two doors in.

---

### Thread 10 — Two bugs, one Flutter footgun

1/ Shipped two animation fixes today. Different symptoms. Same root cause.

Bug A: when you finished grading one card, the next card briefly flashed its answer before rotating to the question.

Bug B: every time you came back to the home screen, your XP counter rolled up from 0 to its real value. Felt like you'd just earned XP.

Both were `TweenAnimationBuilder`. 🙃

2/ `TweenAnimationBuilder` is Flutter's "implicit animation" widget. You give it a tween and a duration, it interpolates for you. No `AnimationController` required.

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: value),
  duration: 800.ms,
  builder: (_, v, __) => Text('$v'),
)
```

Looks innocent. Reads like a one-shot.

3/ It isn't. It has *internal state* — the current animated value. And that state has two behaviors that bite you in opposite directions:

**Behavior 1**: if the widget stays mounted and you change the tween's `end`, it animates from the *current value* to the new end. (Not from `begin`.)

**Behavior 2**: if the widget is remounted, the state resets. It animates from `begin` to `end` — fresh.

4/ Bug A: the card flip widget stayed mounted across cards. Card 1 ended with the tween at 1.0 (showing the answer). When card 2 mounted with `revealed: false`, the tween's end was now 0.0. Behavior 1 kicked in: it animated from 1.0 → 0.0. Which meant the card spun *backwards* from its answer side, briefly showing card 2's name before landing on "Who is this?".

Fix: a `ValueKey(card.id)` on the flip widget. New key = new state = fresh mount. No backwards animation.

5/ Bug B: the home screen tears down and remounts whenever you navigate to a full-screen route (`/session`, `/summary`) and come back. So the XP pill remounts. Behavior 2 kicked in: every remount animated `begin: 0` → `end: 47`. The user perceived this as "I just got 47 XP" even though they never played a card.

Fix: `Tween(begin: value, end: value)`. On fresh mount, both endpoints equal the current value — no animation. On actual change, Behavior 1 still animates from the prior value to the new end, so genuine XP gains still feel rewarding.

6/ Lesson: implicit animations are convenient *until* you start moving widgets in and out of the tree. `TweenAnimationBuilder` has two completely different behaviors depending on whether you mounted-with-new-state or rebuilt-with-new-props. Both are documented. Neither is obvious from the call site.

If the widget's lifetime is unstable — keyed lists, conditional rendering, full-screen route detours — you almost always want one of:
- explicit `AnimationController` (full control, more code)
- `begin: currentValue` (tween is a no-op on mount, animates only on prop change)

7/ The second bug is the kind that's only caught by a real user telling you "I'm getting XP without playing." It looked correct in every diff. It would have shipped. Beta testing is not optional.

---

### Thread 11 — The Dark Souls of civics

1/ Spent today ripping out Politiface's Learn tab and replacing it with a top-down progression tree. Khan Academy mastery gating + Duolingo path + OSINT-Framework horizontal layout, all converging on one canvas.

The hard part wasn't the rendering. It was figuring out what "mastered" should mean.

2/ The science-honest answer: a card is mastered when FSRS stability climbs past ~30 days. That takes weeks of spaced reviews. *Impossible in a single session.*

The game-honest answer: mastered = "I tapped the cards enough times to feel like I earned the next node." That's reachable in 3 minutes but doesn't mean you actually remember anything.

Both wrong.

3/ The right answer is a third thing — *demonstrated recall*. A node's tier is mastered when every card in it has:
  - been recalled correctly at least 3 separate times this session
  - last grade ≥ Good
  - current FSRS retrievability ≥ 0.80

The queue interleaves so each retrieval is a real "did you remember this without seeing it 5 seconds ago" attempt, not a button-mash.

4/ This is Dark Souls. The challenge is *real* (you can't speedrun by tapping Good — you have to actually remember). The reward is *earned* (3 successful spaced retrievals is honest signal). The progression is *visible* (you always see "you need 1 more good answer on Pam Bondi to unlock Cabinet").

Difficulty that feels fair never loses players.

5/ Side problem: same-day repeat grading was poisoning FSRS state. Stability would grow on rapid re-grades it shouldn't grow on — making future scheduling wrong.

Fix: split the grade router. Same single button on screen, two paths underneath:

```dart
if (grade == Again || cardIsActuallyDue):
  → real FSRS update
else:
  → practice mode (counter ticks, FSRS frozen)
```

Anki, Duolingo, Wanikani all have this split. Apparently it's just A Thing You Have To Do for any SRS that also doubles as a game.

6/ Visual is OSINT Framework — root anchored left, branches fanning rightward, locked subtrees collapsed so the canvas stays readable. Pinch-zoom, pan, tap a node → bottom sheet with tier-grouped decks.

Single canvas. No Path/System toggle. The structure of the US government laid out as a constellation that lights up branch by branch as you master it.

7/ Pulled it off in 3 phases over a weekend:
  Phase 0: schema migration, practice-mode router, pure-Dart state machine + 25 unit tests. Pure plumbing. App looked identical when it shipped.
  Phase 1: the OSINT renderer. Tidy-tree layout, marker widgets, curved bezier connectors over a starfield.
  Phase 2: tap-to-tier-sheet, post-session unlock detection, branch-color halo flash on newly-available children.
  
Each phase = one commit, all pushable independently. Boring engineering plus a structural payoff.

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

---

## F) Live design deliberations

Things being weighed right now. Worth posting *as* deliberations — "here's what I'm considering and why" reads honestly, invites replies, and pre-stages whatever ships next.

### Should the app open straight into gameplay?

**The proposal:** delete the home screen. Open Politiface and you're already playing.

- First open today + onboarded → today's challenge (5 cards)
- Daily already played → due FSRS reviews (if any) → Endless mode
- After every session → quick map "fly-to" showing the node you just strengthened, then "tap to keep going"

Inspiration: Tinder, Snapchat, Duolingo. Apps that get used daily kill the decide-what-to-do screen. The content is the landing.

**The case for:**
- Removes a tap. The hardest tap is the one you have to *decide* to make.
- Daily challenge play rate goes up — it's no longer behind a card on a screen.
- Endless-as-default gives a unique answer to "what's next?" that other flashcard apps don't have.
- Streak, XP, level become *rewards you see after playing* instead of dashboard furniture you click through *before* playing.

**The case against:**
- FSRS reviews get orphaned. Today's home surfaces the daily 20-card due review — that's the actual memory-science backbone. Daily challenge is 5 cards, Endless is MCQ (no FSRS impact). If autopilot is Daily → Endless, users may never hit their due reviews and stability stops growing. Fix: insert due reviews into the rotation between Daily and Endless.
- No agency. Sometimes you want to study a specific deck (e.g. US Exec) or just check your stats. Need an obvious escape hatch — bottom nav stays.
- Cold open is jarring. A card on screen the instant the app opens is unsettling if you opened it for a different reason. Soft middle: 1.5s splash with streak + "Daily Challenge — 5 cards" + a card peeking up, then it auto-flips to the question.

**Where I'm leaning:**
1. Build the post-session map fly-to first. It's the strongest piece independently — makes every Endless run feel like *territorial progress* rather than score-chasing. Ships regardless of whether home gets gutted.
2. Behind a flag, try true auto-play. A/B with myself for a week. If it feels right, kill the home screen for real and turn it into a "Stats" tab.
3. FSRS reviews go second in the rotation, always — Daily Challenge → Due Reviews → Endless. The bedrock loop doesn't get to be optional.

This whole post is content material on its own — "considering deleting the home screen of my app" is a strong opener.

---

## Z) Ideas / drafts — borderline moments

Half-formed angles, rough one-liners, and moments from the build that *might* become a post. Not ready for section A) yet. Park them here; promote when they crystallize.
