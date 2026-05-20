# Politiface — Session Handoff

**Last working session:** 2026-05-20
**For:** the next Claude Code agent picking up in this VSCode window
**Repo:** https://github.com/rkapdi/politiFace (push to `main`)
**Working dir:** `/Users/rkapdi/Developer/politiFace/politiface` — NOT the old `~/Desktop/cCcV/` path (that's been deleted; old path had iCloud xattr issues that broke iOS codesigning)

---

## Where the project stands

Feature-complete MVP shipping to the iOS Simulator (iPhone 17 Pro, id `8CFA7742-9A63-4A1E-A3EC-3428ED337CA5`). Everything below is built, working, committed, and pushed:

**Core engine**
- FSRS-4.5 spaced repetition (with NaN-stability fix — clamp difficulty to [1,10] before computing stability)
- Drift (SQLite) with DAOs, sync log table, pending-session resume
- Riverpod hand-written providers (no codegen — user preference)
- GoRouter with `StatefulShellRoute.indexedStack` for persistent bottom nav

**Features shipped**
- Onboarding + daily session loop with FSRS scheduling
- Daily Challenge (5 cards, Wordle-style emoji share artifact, "next in Xh Ym" footer)
- Endless mode with 4 MCQ formats (photoToName, nameToPhoto, titleToWho, photoToTitle)
- US Government tab: Duolingo-style Path view + System view (eagle-eye with animated flow dots on edges) toggled via SegmentedButton
- Path tab has bottom scroll headroom + "More coming soon" footer card
- Memory tab: orbital **Memory Field** with radar sweep + retrievability arcs + labeled tier rings (just shipped — see below)
- Mastery distribution dot-plot with jitter + promotion-zone shading + "N ready →" callouts
- Top cards list
- Home: StreakHero (gradient banner) + DailyChallengeCard (gold/forest variants) + EndlessTile + NextUpSection
- Settings, notifications (with permission re-check), Sentry crash reporting
- Pending session store survives backgrounding/crash within 24h
- Concurrent-grade guard (`_gradeInFlight`) prevents double-grade on rapid taps

**CI / build**
- GitHub Actions: `flutter analyze` with custom grep gate (warnings + errors fail, info-level lints pass)
- Codemagic iOS-only release pipeline. Bundle id: `io.politiface.politiface`. Injects `SENTRY_DSN` via `--dart-define`.

---

## What I shipped in the most recent session

### 1. Memory Field upgrade (file: `lib/features/memory/presentation/memory_field.dart`)

Three additions on top of the existing orbital:
- **Radar sweep beam** — `_sweep` AnimationController (10s/turn). 60° trailing wedge using `SweepGradient` from transparent → `primary.withOpacity(0.18)`, plus a crisp leading line. When the leading edge crosses an orb (within 45°), the orb's glow expands and color whitens; fades over the trail.
- **Retrievability arcs** — thin colored arc around each dot. Starts at 12 o'clock, sweeps `2π × R` where `R = 1 / (1 + days_since_review / (9 * stability))`. Full circle = ~100% recall probability; sliver = about to forget.
- **Readable tier rings** — opacity bumped 0.06 → 0.14. Each ring gets a ★N label at ~4 o'clock with a backdropped chip for legibility over rings.

The user's reaction: shipped, awaiting visual confirmation. Build sync confirmed at "Syncing files to device iPhone 17 Pro... 77ms".

### 2. Build-in-public drop set (file: `BUILD_IN_PUBLIC.md` at repo root)

User asked for tweets/threads/articles/video shot list documenting the build. I produced a working library:
- 8 ready-to-post tweet threads (iCloud xattr disaster, FSRS NaN bug, "stuck at 4/5 on Pam Bondi" infinite loop, iOS-only rationale, Memory Field demo, skipping Phase 1, no-mock-DB rule, build-in-public meta)
- 1 fully drafted long-form ("How I Made Forgetting Visible") + 3 outlined
- Video/screenshot shot list (7 assets)
- 12 angles they're missing (decision log, bug-of-the-week, Claude Code transparency, pre-launch metrics curve, etc.)
- Cadence recommendation: daily one-line, weekly bug/decision post, biweekly demo, monthly long-form

User had not yet decided on next step when session window closed. Last offer: "Want me to film/script the Memory Field demo video next, or move to a different feature?"

---

## User preferences (honor these)

- **Work without stopping for clarifying questions; make the reasonable call.** They'll redirect if needed.
- **Terse responses.** Skip preamble. No trailing summaries.
- **iOS-only for v1.** Don't add Android/Web concerns unless asked.
- **Hand-written Riverpod providers.** No `@riverpod` codegen.
- **All code lives at https://github.com/rkapdi/politiFace.** Push to `main`.
- **Building in public.** When something interesting happens during dev (bug, decision, design choice), flag it as build-in-public material.
- **Force-push to main was authorized ONCE only.** Don't repeat without re-asking.
- **No mocks for DB-layer tests.** Use `NativeDatabase.memory()`. Real DB > mock DB.
- **Casino/Duolingo-style gamification is the design language.** Bold gradients, glassmorphism, big numbers, motivational microcopy.

---

## Pending / open items

**Likely-next based on recent thread:**
- Long-press a dot in the Memory Field for a popover ("JD Vance · ★2 · 4.2 days · 60% through tier"). Offered but not built — confirm with user before starting.
- Film a Memory Field demo video (mentioned in BUILD_IN_PUBLIC.md as the highest-leverage asset to capture).

**Pre-launch blockers (user's responsibility):**
- Apple Developer Program enrollment
- App Store Connect listing + screenshots + description
- Privacy policy hosting (URL needed for App Store)
- Real card content authored in YAML (currently 5 hardcoded executive-branch cards)
- Real politician photos via Cloudflare CDN (currently using avatars-with-initials)
- App icon artwork (currently placeholder)

**Engineering items deferred to V1.1 / later:**
- Phase 6 (Supabase auth, account sync)
- Achievements / badges system
- Multiple daily quests
- Leaderboards (needs backend)
- Real device testing (only run on simulator so far)
- Time-zone-aware streak (looked at, deemed unnecessary for v1)
- `package_info_plus` for version display
- Sentry release tagging

---

## Repo structure cheat sheet

```
/Users/rkapdi/Developer/politiFace/politiface/
├── HANDOFF.md                      ← this file
├── BUILD_IN_PUBLIC.md              ← content library
├── codemagic.yaml                  ← iOS-only release pipeline
├── .github/workflows/flutter-ci.yml ← analyze gate with grep
└── app/
    ├── pubspec.yaml
    ├── assets/content/decks/*.yaml ← card content source
    └── lib/
        ├── main.dart
        ├── app/
        │   ├── providers.dart      ← all Riverpod providers (hand-written)
        │   ├── router.dart         ← GoRouter w/ StatefulShellRoute
        │   └── politiface_app.dart
        ├── core/
        │   └── database/
        │       ├── drift/app_database.dart
        │       └── daos/*.dart
        └── features/
            ├── home/
            │   └── presentation/
            │       ├── home_screen.dart
            │       ├── streak_hero.dart
            │       ├── daily_challenge_card.dart
            │       └── next_up_section.dart
            ├── session/             ← FSRS + session queue + pending-session-store
            ├── endless/             ← MCQ endless mode
            ├── government/
            │   └── presentation/
            │       ├── gov_map_screen.dart  ← Path/System toggle
            │       └── system_view.dart     ← eagle-eye animated flow
            ├── memory/
            │   ├── data/memory_service.dart
            │   └── presentation/
            │       ├── memory_screen.dart   ← dot-plot lives here
            │       └── memory_field.dart    ← MOST RECENT EDIT
            ├── daily_challenge/
            ├── profile/
            ├── onboarding/
            └── settings/
```

---

## How to resume

1. Confirm with the user how the Memory Field upgrade looks (radar sweep, retrievability arcs, ★N ring labels).
2. If they're happy: ask whether to (a) add long-press popover on orbs, (b) film the Memory Field demo video, or (c) move to a different feature.
3. If they're not happy: iterate. Common tuning knobs in `memory_field.dart`:
   - Sweep speed → `_sweep` duration (currently 10s)
   - Sweep wedge width → `wedge` const in `_drawRadarSweep` (currently π/3 ≈ 60°)
   - Sweep brightness boost trail → `sweepWidth` in `paint()` (currently π/4 ≈ 45°)
   - Ring opacity → `ringColor` opacity in `_drawRings` (currently 0.14)
   - Arc thickness → `strokeWidth` in `_drawRetrievabilityArc` (currently 1.5)

The iOS Simulator should already be running. If not:

```bash
cd /Users/rkapdi/Developer/politiFace/politiface/app
flutter run -d "8CFA7742-9A63-4A1E-A3EC-3428ED337CA5"
```

If `flutter` isn't on PATH in the new shell, prepend `/opt/homebrew/bin:`.
