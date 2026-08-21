# Pre-Submission UI Changes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the ten approved UI changes (spec: `docs/superpowers/specs/2026-08-12-pre-submission-ui-changes-design.md`) in one App Store build.

**Architecture:** All changes are Flutter client-side. One new persisted preference (selected cohort) follows the existing AppMeta/metaDao key pattern. The Pulse alert log gains an optional item key per entry; old entries stay readable. No server or schema changes.

**Tech Stack:** Flutter, Riverpod, Drift (AppMeta), go_router.

## Global Constraints

- No em-dashes in any user-facing copy (CLAUDE.md house rule).
- All copy stays "practice, not predictor" (FLDOE positioning).
- Keep `app/test/features/leaderboard/leaderboard_screen_test.dart` and `app/test/features/shared/neo_kit_test.dart` green.
- Version bump: `app/pubspec.yaml` 1.2.0+26 -> 1.3.0+27.

---

### Task 1: Home reorder + guided tour (spec item 1)

**Files:**
- Modify: `app/lib/features/home/presentation/home_screen.dart:73-96` (Column order), header comment lines 3-13
- Modify: `app/lib/features/home/presentation/guided_tour.dart:100-151` (step order + copy)

- [ ] New Column order: ReadinessHero, 18, KeyedSubtree(verbsKey, _MoreWaysRow), 18, KeyedSubtree(buttonKey, _TheOneButton), 18, _ClassBlock (internal bottom-18 stands in for the gap when present), 8, _SectionDivider('THE SEASON'), 12, SeasonSpine, 16. Solo users get 18+8=26 before the divider, matching today's 26.
- [ ] Guided tour: swap the button and verbs steps (readiness -> verbs -> button). Verbs step kicker becomes `THREE DOORS`, body: "Study picks up the season where you left off. Drill moves your exam score. Play is the arcade, zero stakes, never burns your streak." Closing step body: "Check the band, pick a door, press the yellow when in doubt. Replay this tour any time from Settings."
- [ ] Update home_screen.dart header comment to the new order.
- [ ] `flutter analyze` clean; commit "Home: Study/Drill/Play row above Today's Review; tour follows".

### Task 2: Persisted class selection (spec item 2)

**Files:**
- Modify: `app/lib/features/leaderboard/application/leaderboard_providers.dart`
- Modify: `app/lib/features/leaderboard/presentation/leaderboard_screen.dart:33-99`
- Modify: `app/lib/features/home/presentation/home_screen.dart` (_ClassBlock)
- Test: `app/test/features/leaderboard/selected_cohort_test.dart` (new)

**Interfaces (produces):**
```dart
// leaderboard_providers.dart
final selectedCohortIdProvider =
    AsyncNotifierProvider<SelectedCohortId, String?>(SelectedCohortId.new);
class SelectedCohortId extends AsyncNotifier<String?> {
  static const metaKey = 'class.selected_cohort_id';
  @override Future<String?> build();          // reads metaDao
  Future<void> select(String id);             // writes metaDao + state
}
```

- [ ] Write failing test: provider round-trips a selection through an in-memory AppDatabase (`NativeDatabase.memory()` pattern from existing dao tests), and a second container read returns the persisted id.
- [ ] Implement the provider (reads `databaseProvider.metaDao`).
- [ ] LeaderboardScreen: drop the `_selectedCohortId` field; watch the provider; `onSelect` calls `select(id)`; keep a local `_justJoined` string so the just-joined spinner branch still works, but a stale persisted id (class left) silently falls back to `list.first` instead of spinning.
- [ ] Home `_ClassBlock`: `final sel = ref.watch(selectedCohortIdProvider).valueOrNull;` then `cohorts.firstWhere((c) => c.id == sel, orElse: () => cohorts.first)`.
- [ ] Run new test + `leaderboard_screen_test.dart`; commit "Class selection persists across screens (AppMeta-backed provider)".

### Task 3: Chapter sheet CTA to the top + BRANCHES COVERED (spec items 3, 4)

**Files:**
- Modify: `app/lib/features/home/presentation/chapter_info_sheet.dart`

- [ ] Move the `_ChapterCta(...)` invocation (currently lines 218-242) to directly after the subtitle Text (line 173): subtitle, 18, CTA, 22, PROGRESS... Remove the old bottom copy; keep the trailing SizedBox(12).
- [ ] Rename `_SectionHeader(label: 'TOUCHES')` to `'BRANCHES COVERED'`; after the chip Wrap add: SizedBox(6) + `Text('Groundwork for the FCLE domains you see on Home.', style: bodySmall, color onSurfaceVariant)`.
- [ ] `flutter analyze`; commit "Chapter sheet: CTA first; Touches becomes Branches Covered".

### Task 4: Atlas Reference to the top (spec item 5)

**Files:**
- Modify: `app/lib/features/atlas/presentation/atlas_screen.dart:113-155` + header comment 17-24

- [ ] Inside `if (showSpotlight)` move `_ReferenceSection` (+16 gap) to before `ChapterSpotlight`; delete the lower `if (showSpotlight)` block.
- [ ] `flutter analyze`; commit "Atlas: Reference section moves to the top".

### Task 5: Pulse notifications box (spec item 6)

**Files:**
- Modify: `app/lib/features/notifications/data/notification_orchestrator.dart:323-393`
- Modify: `app/lib/features/pulse/presentation/pulse_screen.dart` (_Alert, _alertLogProvider, _AlertsCard -> _PulseInfoCard, tap handling, detail sheet)

- [ ] Orchestrator: `_appendAlertLog(c, deliveredAt)` takes the `NotifCandidate`; entry gains `'k': c.dedupeKey` (only when non-empty). Verify dedupeKey formats against `washington_watch_service.dart:80-100` before matching.
- [ ] `_Alert` gains `final String? itemKey;` parsed from `'k'`.
- [ ] Matching helper: `eo:<n>` -> feed item `kind == order && detail.startsWith('Executive Order <n>,')`; `law:<bill>:...`/`bill:<bill>:...` -> feed item `item.bill == <bill>`. Tap on matched row reuses `_PulseTile`'s navigation (push `/pulse/bill` with `BillDetailArgs`, or `launchUrl` for orders). Unmatched/keyless rows open `_AlertDetailSheet`: full title, body, delivered time, and a "SEE WHAT'S NEW IN THE PULSE" button that pops and clears the filter to All.
- [ ] `_PulseInfoCard(filter, alerts, ...)` replaces `_AlertsCard`; shown when `filter != null || alerts.isNotEmpty`:
  - filter null: header FROM YOUR NOTIFICATIONS; alert rows (up to 8) in a `ConstrainedBox(maxHeight: 180)` + `SingleChildScrollView`, each an InkWell with a chevron.
  - filter order: header WHAT IS AN EXECUTIVE ORDER?; body: "An executive order is a written directive from the President that manages how the federal government operates. Orders draw their force from Article II of the Constitution and from powers Congress delegates by statute. They do not need a vote in Congress, but they cannot override the Constitution or existing law, courts can strike them down, and a later President can amend or revoke them. Each order is numbered and published in the Federal Register."
  - filter law: header HOW A BILL BECOMES A LAW; body: "A bill becomes a law after both chambers of Congress pass identical text and the President signs it, or Congress overrides a veto with a two thirds vote in each chamber. Each new statute receives a Public Law number and is published by the Office of the Federal Register."
  - filter bill: header WHAT ARE BILL ACTIONS?; body: "A bill action is any recorded step in a bill's life on congress.gov: introduction, committee referral, floor votes, passage in either chamber, and presidential action. Most bills never become law; the trail of actions shows where a bill actually stands."
- [ ] `flutter analyze`; commit "Pulse: notifications box is tappable and filter-aware".

### Task 6: Streak chip sheet (spec item 7)

**Files:**
- Modify: `app/lib/features/home/presentation/home_screen.dart` (_StreakChip + call site; import streak_hero.dart)

- [ ] `_StreakChip` takes the full `UserProfile`, wraps in InkWell with `Semantics(button: true, label: 'Streak, N days')`; onTap opens `showModalBottomSheet` -> SafeArea/Padding Column: `StreakHero(profile: profile)`, 12, rule line: "One day with any review keeps the streak alive. Miss a day and it resets to zero. Play never burns it; skipping does."
- [ ] `flutter analyze`; commit "Streak chip opens streak details".

### Task 7: Readiness card says FCLE (spec item 8)

**Files:**
- Modify: `app/lib/features/home/presentation/home_screen.dart:164` + caption
- Modify: `app/lib/features/home/presentation/guided_tour.dart:102` (kicker)

- [ ] Header 'YOUR READINESS' -> 'FCLE READINESS'; under the header Row add SizedBox(2) + `Text('Florida Civic Literacy Exam · practice projection', bodySmall onSurfaceVariant)`.
- [ ] Tour step 1 kicker -> 'FCLE READINESS'.
- [ ] `flutter analyze`; commit "Readiness card names the FCLE".

### Task 8: Radar sweep loop fix (spec item 9)

**Files:**
- Modify: `app/lib/features/memory/presentation/memory_field.dart:479-481, 544-584`

- [ ] Rewrite `_drawRadarSweep`: `canvas.save(); canvas.translate(center); canvas.rotate(angle);` then draw the wedge in rotated space with constant gradient angles: `drawArc(rectAtOrigin, -wedge, wedge, true, SweepGradient(startAngle: 2π - wedge, endAngle: 2π, colors: [transparent, 0.18]))`, leading line from origin to `(radius*0.95, 0)`, `canvas.restore()`. Gradient angles never span the 0-degree axis, killing the once-per-loop bright flat wedge.
- [ ] Align orb boost: `sweepWidth = math.pi / 3`.
- [ ] `flutter analyze`; commit "Memory field: radar sweep no longer doubles at the loop boundary".

### Task 9: Study tile opens the season (spec item 10)

**Files:**
- Modify: `app/lib/features/home/presentation/season_spine.dart:73` (`_resolveCurrentOrder` -> public `resolveCurrentOrder`)
- Modify: `app/lib/features/home/presentation/home_screen.dart` (_MoreWaysRow -> ConsumerWidget)

- [ ] Expose `SeasonSpine.resolveCurrentOrder` (rename, update internal call).
- [ ] `_MoreWaysRow` becomes ConsumerWidget. STUDY tile: subtitle 'continue the season'; onTap reads `curriculumProvider` + `seasonProgressProvider`, resolves current chapter (fallback `context.go('/session')` if curriculum missing), opens `ChapterInfoSheet.show(context, chapter, entry, currentOrder)`. DRILL/PLAY unchanged.
- [ ] `flutter analyze`; commit "Study tile resumes The Season".

### Task 10: Release chores

- [ ] `app/pubspec.yaml` version -> `1.3.0+27`.
- [ ] Full `flutter analyze` + `flutter test` in `app/`; fix any breakage.
- [ ] Commit "Bump to 1.3.0+27 for App Store review".
