# PROPOSALS — Pre-launch priorities

Phase 5 deliverable: the five highest-leverage moves before public launch,
with effort estimates. Written against the founder's strategic frame:
**MVP is US federal only (and deliberately non-exhaustive); the federal core
is free forever; monetization later = depth, test prep, citizenship prep,
via subscription plus one-time owned packs.**

Ranked. #1 is the recommended Phase 6.

---

## 1. The lesson layer — turn drills into a course  ⟵ PHASE 6

**Problem.** The app has practice (FSRS cards) and proof (trivia) but no
*teach* step. The first encounter with any fact is a quiz, so rounds feel
like guesswork. Chapters promise a curriculum; the rounds don't deliver one.
Most of the curriculum's 83 items resolve to no card at all and silently
fall back to face cards (`chapter_content_sampler.dart` documents this).

**Fix (three pieces):**

1. **Briefing phase in the daily round.** 2–4 short readable lesson pages
   (heading + tight paragraph + optional portrait) before the cards phase;
   the cards drilled are the ones the briefing introduced. The round
   controller's phase machine (cards → trivia → reveal) extends naturally
   to (briefing → cards → trivia → reveal).
2. **Concept cards, teach-first.** First encounter renders as a lesson
   ("Got it"), later encounters are FSRS recall. `CardType.concept` exists
   unused; `CardMemoryStates.isNew` is the first-encounter signal.
3. **Legible progression.** The chapter sheet lists lesson titles —
   "what you'll learn" before, "what you learned" (re-readable, pairs with
   the replay button) after.

**Content reality:** the engineering is the smaller half. Seed material
exists (the `concepts:` prose in government.yaml — Filibuster, 25th
Amendment, Connecticut Compromise — plus node descriptions), covering maybe
a third of 6 chapters × 3–5 lessons. The rest is authoring neutral, sourced
civics prose under the CONTRIBUTING guidelines. **This authoring IS the
product** — it's also exactly the muscle the paid test-prep/citizenship
packs will need later.

**Scope discipline (per strategy):** existing 6 chapters only. No new
institutions, no breadth expansion. Lessons live in the curriculum YAML so
the pack rails (below) can carry them later.

**Effort:** engineering 2–3 days; authoring 2–4 days (parallelizable).
Requires a curriculum-YAML schema extension — shape needs founder approval
(standing constraint).

## 2. Content-pack readiness — the monetization rail (design now, build later)

The strategy (free federal core + paid one-time regional packs + optional
subscription) maps 1:1 onto infrastructure that already exists or is specced:

- Phase 3's checksum seeder = pack installer (it already re-seeds on content
  change, preserving user state).
- ROADMAP's OTA content packs = pack delivery.
- One-time owned packs = StoreKit non-consumables gating which packs the
  seeder loads; subscription = ongoing depth/test-prep pack refresh.

**Recommendation: build nothing yet.** Pre-launch, only avoid painting into
corners: keep lesson/curriculum content addressed by pack id in the schema
design (#1 does this), and don't hardcode new content paths beyond the
existing `us_civics` ones. StoreKit, entitlements, and multi-pack loading
are post-launch projects (~1 week when their time comes). USCIS test-prep
pack is the natural first paid product — the keyword field already targets
uscis/naturalization searches.

**Effort now: zero** (a schema-design consideration inside #1).

## 3. Card-set curation pass — not expansion

Per strategy, do NOT chase coverage. One curation pass (~1 day incl.
portrait pipeline runs) fixes what hurts at launch:

- Staleness audit of all 46 cards against current officeholders (the
  pipeline's whole pitch is currency; one wrong Cabinet secretary at launch
  undercuts it).
- Add cards only where a chapter's lessons need a face that's missing
  (likely single digits: e.g. VP belongs in several lessons).
- Verify gender/portrait wiring on anything touched.

Checksum reseeding ships all of it to existing installs automatically.

## 4. Government map revival — post-launch, as the skill tree

`GovMapScreen` exists, unrouted; nodes carry map coordinates, colors, icons;
unlock progression already computes per-node states. "Done well" =
pan/zoomable building-map with locked/unlocked/mastered node states, tap →
node sheet (exists), and the lesson layer's titles surfacing per node — the
full "I'm here, this unlocks next" experience the founder described.
**Effort: ~3–4 days. Should not gate launch** — the chapter sheet carries
progression legibility for V1, and shipping a mediocre map would burn the
feature's one first impression.

## 5. Flutter 3.22 → current — post-launch, before next April

Two years of framework drift, pinned everywhere (pubspec, CI, Codemagic).
Risks compound: each year of Apple SDK-minimum bumps makes the jump less
optional and more deadline-driven (Apple historically enforces new-SDK
builds each spring). Plan: dedicated branch; Flutter upgrade first, then
majors one at a time (Riverpod 2→3 is the big one — hand-written providers
keep it mechanical; drift/go_router/sentry are mild); the test suite
(186 tests, incl. migration + content pinning) is the safety net.
**Effort: 2–3 days. Do it in the quiet window right after launch.**

---

## Recommended sequence

1. **Phase 6: lesson layer** (engineering + authoring in parallel) — the
   one change that moves the product from flashcards to civics course.
2. **Curation pass (#3)** alongside Phase 6's authoring days.
3. Launch.
4. Post-launch: Flutter upgrade (#5) → government map (#4) → OTA packs +
   beta analytics when the tester trigger hits (ROADMAP.md) → StoreKit/
   pack monetization (#2).
