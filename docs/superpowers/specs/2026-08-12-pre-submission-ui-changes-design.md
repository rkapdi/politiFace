# Pre-submission UI changes (build for App Store review, fall semester)

Date: 2026-08-12. Branch: v2-planning. Approved by founder in session.
Goal: ten UI changes to the iOS app, shipped in one build submitted for App Store review before the semester starts. No em-dashes in any user-facing copy.

## 1. Home: Study/Drill/Play row moves above Today's Review

`app/lib/features/home/presentation/home_screen.dart` build order (lines 73-96) becomes:
ReadinessHero -> `_MoreWaysRow` (Study/Drill/Play) -> `_TheOneButton` (Today's Review) -> `_ClassBlock` -> The Season.
Also: reorder `GuidedTour` steps (readiness -> verbs -> button) in `guided_tour.dart` so the tour does not scroll backwards, refresh its stale "FOUR DOORS" copy (Pulse is a tab, not a door), rebalance the 18px spacer `_ClassBlock` carries internally, and update the file header comment documenting composition order.

## 2. Class selection persistence

Bug: selected class chip on the leaderboard screen is ephemeral `setState` (`leaderboard_screen.dart:34`); Home's MY CLASS card independently shows `cohorts.first` (most recently joined). Fix:

- New `selectedCohortIdProvider` persisted via `metaDao` under AppMeta key `class.selected_cohort_id` (follows the profile.* key pattern).
- Leaderboard chips read/write the provider; Home `_ClassBlock` reads it.
- Validation: if the stored id is not in `myCohortsProvider`, fall back to `list.first` (newest joined) and do not write back.
- Out of scope: server-side activity attribution (audit F13) still tags answers to the most recently joined cohort. This change is display/selection only.

## 3. Chapter sheet: CTA to the top

`app/lib/features/home/presentation/chapter_info_sheet.dart`: `_ChapterCta` moves from the bottom (lines 218-242) to directly under the title/subtitle block, above PROGRESS. All three CTA states move (locked note, completed banner + replay, continue/review) so the sheet always opens with its action visible.

## 4. TOUCHES heading rename

The chips are the government-branch taxonomy (Foundations, Legislative, Executive, Judicial, State and Local), not FCLE domains. Heading `TOUCHES` (`chapter_info_sheet.dart:204`) becomes `BRANCHES COVERED` with a one-line caption: "Groundwork for the FCLE domains you see on Home." No data-source change; mapping chapters to FCLE domains is explicitly deferred.

## 5. Atlas: Reference section to the top

`app/lib/features/atlas/presentation/atlas_screen.dart` (`_AtlasBody.build`, lines 113-155): `_ReferenceSection` moves to directly under the search field, above `ChapterSpotlight` and the branch sections. It stays gated on an empty search query (search results win the screen). Update the file header comment.

## 6. Pulse: contextual, tappable notifications box

Two parts, both in `pulse_screen.dart` plus one change in `notification_orchestrator.dart`.

(a) Richer alert log + tappable rows:
- `NotificationOrchestrator._appendAlertLog` additionally stores `k` (dedupeKey, e.g. `eo:14418`), `kind`, and `url` when the candidate carries them. Cap stays 20. Old entries without keys remain readable.
- Notification rows become tappable. A row with a key that matches a `_PulseItem` in the current feed deep-links: bill/law -> `/pulse/bill` detail, executive order -> its Federal Register URL. A row without a key (digest "Washington was busy" entries, pre-upgrade entries, or keyed items no longer in the feed) opens a small detail sheet: full title, body, delivered-at time, and a "See what's new in the Pulse" action that clears the filter to All.

(b) Filter-aware box content:
- Filter All (or landing): the notifications list, scrollable within a fixed-height card, all rows tappable per (a).
- Filter Executive orders / New laws / Bill actions: the card content swaps to a short nonpartisan explainer of that instrument (what it is, who issues/passes it, how it takes effect), citation-backed tone, reusing `_PulseTile._badge` colors. Static curated copy, no em-dashes.

## 7. Streak chip tappable

`_StreakChip` (`home_screen.dart:104-132`) gains an onTap opening a bottom sheet whose body is the existing, currently-unused `StreakHero` widget (`streak_hero.dart`) plus one line explaining the rule: one review day keeps the streak alive; missing a day resets it. No streak history exists in the data model; no calendar view this round.

## 8. Readiness card reads as FCLE

`ReadinessHero` (`home_screen.dart:137-212`): header `YOUR READINESS` becomes `FCLE READINESS`; add caption "Florida Civic Literacy Exam · practice projection". `PASS LINE 48`, stage words, domain bars unchanged. Positioning stays "practice, not predictor". `PowerlineBar`/neo-kit labels untouched (shared, tested).

## 9. Radar sweep fix

`memory_field.dart` `_drawRadarSweep` (lines 544-584): the `SweepGradient` is anchored at absolute angles and clamps wrong when the wedge straddles 0 degrees, painting a second flat-bright wedge once per 10s loop. Fix: canvas save/translate/rotate to the sweep angle and paint a fixed-angle wedge with a constant-angle gradient. Align the orb-brightening arc width (`sweepWidth`, currently pi/4) to the visible pi/3 tail.

## 10. Study tile points at The Season

STUDY tile (`home_screen.dart:414-425`) stops routing to `/session` (which duplicates Today's Review). New behavior: opens the current chapter's `ChapterInfoSheet` (chapter resolved from `curriculumProvider` + `seasonProgressProvider`, same resolution as `SeasonSpine._resolveCurrentOrder`). Tile subtitle "keep it fresh" becomes "continue the season". If the season is complete (no current chapter), fall back to the last chapter's sheet.

## Release chores

- Bump `app/pubspec.yaml` version 1.2.0+26 -> 1.3.0+27 (new marketing version required for a new App Store release).
- Keep green: `app/test/features/leaderboard/leaderboard_screen_test.dart`, `app/test/features/shared/neo_kit_test.dart`, full `flutter analyze` + `flutter test`.

## Testing

- Unit/widget: selected-cohort provider fallback logic; leaderboard chip persistence across rebuild; home section order; chapter sheet CTA-first order; pulse explainer swaps per filter; alert-log entries round-trip with and without keys.
- Manual on device: guided tour order, radar loop boundary, notification deep links, streak sheet.
