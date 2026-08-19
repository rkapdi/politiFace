# Android Pilot Release: Design

Date: 2026-08-19
Status: Approved pending user review
Goal: Android students in the MDC pilot cohort can install Politiface by approximately Aug 24, 2026, via Google Play closed testing, with production release following the mandatory testing period.

## Context

The Flutter app ships iOS-only (1.3.0 build 31, in App Store review). The `app/android/` scaffold exists from `flutter create` but has never shipped: debug signing, default manifest, lowercase app label, `android: false` on launcher icons, no Play Store presence, no Android CI. The Dart codebase is platform-clean: no `Platform.isIOS` branches, the notification service already configures Android channels, and workmanager periodic tasks are natively supported on Android (better than iOS BGAppRefresh).

There is no Google Play developer account yet. New personal accounts must run a closed test with 12+ opted-in testers for 14 consecutive days before Google grants production access. The pilot cohort itself satisfies the tester count, and the closed track is how students install during the pilot anyway, so the requirement costs nothing extra if the clock starts by Aug 24.

The critical path is Google, not engineering: account identity verification (1 to 3 days) and new-account app review (hours to days). The design keeps engineering small enough to finish inside those waits and starts them immediately.

## Decision

Minimal pilot path with local builds (Approach A from brainstorming), improved with: internal-track-first distribution, real-device smoke testing via Dawood plus the Play pre-launch report, a reproducible build script, and an explicit edge-to-edge contingency rule. Codemagic Android CI is deferred to the week after the pilot ships. Sideloading the same signed APK is the documented fallback if Play review drags past Aug 23.

## Scope

In scope: Android project config, signing, launcher icons, one small Dart change (Android 13+ notification permission), emulator QA, Play Console setup, closed-testing release.

Out of scope: Codemagic Android workflow (week two; the build script becomes its body), Flutter version upgrade (only if `compileSdk 35` forces it), Play production release (blocked by the 14-day rule; follows automatically), tablet or foldable layout work, Wear or widget surfaces.

Invariants: iOS behavior untouched. One shared version line (`1.3.0+N`) covers both platforms. Data minimization stance unchanged; the Play data safety form must declare no more than what iOS collects today.

## Workstreams

Three tracks run in parallel.

### Track 1: Play Console (external; start day one)

1. Create personal Google Play developer account ($25 one-time). Identity verification takes 1 to 3 days; nothing downstream can start until it clears, so this is the first action of the project.
2. Create the app as `io.politiface.politiface` (matches the iOS bundle id and the existing `applicationId`).
3. Store listing: short and full description using the neutral "supplemental practice students choose" framing, no em-dashes, no official-sounding FCLE claims. Screenshots from the emulator, 1024x500 feature graphic, privacy policy URL (verify the site page exists and covers Android before submitting).
4. Data safety form: optional account email (Supabase auth), opt-in crash data (Sentry), no ads, no third-party tracking, no political affiliation or voting data collected (Florida hard rule; also true of the app). Content rating questionnaire: education app, no user-generated content visible to others.
5. Internal testing track: add Rissalat and Dawood as testers. Internal releases distribute within minutes and do not wait on full review; this is the first real-device artifact.
6. Closed testing track: tester email list seeded with pilot students, Rissalat, and Dawood (12+ total). Promoting the internal build here starts the 14-day production clock. Target: clock running by Aug 24.
7. Pre-launch report: enabled by default on internal and closed tracks; Google runs the build on physical devices and reports crashes and screenshots. Review its output as part of QA.

### Track 2: Android app configuration

1. `AndroidManifest.xml`:
   - `android:label` becomes `Politiface`.
   - Permissions: `POST_NOTIFICATIONS` (API 33+ runtime notifications), `RECEIVE_BOOT_COMPLETED` (reschedule reminders after reboot), `SCHEDULE_EXACT_ALARM` (the notification service uses `AndroidScheduleMode.exactAllowWhileIdle`).
   - `flutter_local_notifications` receivers: `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`, per plugin documentation, so FSRS reminders fire when scheduled and survive reboot.
2. `app/android/app/build.gradle`:
   - `compileSdk 35` and `targetSdk 35` overrides (Play requires 35+ for new apps; the pinned Flutter 3.22 defaults to 34). If plugin or AGP incompatibilities appear, fixing them is in scope; upgrading Flutter is the last resort.
   - Release signing config read from `key.properties` (gitignored). Remove the scaffold TODO comments and the debug-signing fallback for release builds.
3. Upload keystore: generated once with `keytool`, stored outside the repo, backed up in the founders' password manager. Play App Signing holds the actual app signing key, so a lost upload key is recoverable through Google support, but treat the backup as mandatory anyway.
4. Launcher icons: `flutter_launcher_icons` gains an Android adaptive icon config: navy background color, P-profile mark as foreground with adaptive-safe padding. `android: false` becomes the adaptive config. Regenerate and verify no iOS icon churn in the diff.
5. Build script `scripts/build_android.sh`: mirrors the Codemagic iOS steps (pub get, build_runner, flutter test, `flutter build appbundle --release` with the same `--dart-define` secrets: `SENTRY_DSN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, reading from environment). Purpose: a hand-typed build that forgets one define ships a silently degraded binary; the script makes the release reproducible and becomes the body of the future Codemagic Android workflow.

### Track 3: Code change plus QA

1. Dart change (the only one): request the Android notification permission where iOS permissions are requested today, via the `flutter_local_notifications` Android platform implementation (`requestNotificationsPermission()`). No-op on iOS. Denial degrades gracefully: the app fully works, reminders do not fire, no nagging.
2. Emulator QA pass on an API 35 image:
   - Fresh install: content seeding, decks, chapter journey.
   - FSRS session flow, Mock FCLE, readiness indicator.
   - Notifications: permission prompt, scheduling, delivery, reboot persistence.
   - Workmanager periodic refresh registers and runs (minimum 15-minute interval).
   - Share sheet (share_plus), sounds (audioplayers), Supabase auth sign-in and sync.
   - Edge-to-edge layout check: API 35 enforces edge-to-edge drawing; status and navigation bar insets are the likely breakage.
   - Existing `flutter test` suite stays green.
3. Real-device smoke pass: Dawood (or a borrowed Android in Fort Lauderdale) installs from the internal track and runs the happy path, with attention to notification delivery on Samsung hardware. Known risk: aggressive OEM battery management (Samsung especially) can kill WorkManager tasks and delay notifications. Existing defense: `main.dart` runs the notification sweep on every foreground open, so reminders recover on next launch even if background work is killed. No additional engineering for OEM quirks in the pilot.
4. Pre-launch report findings triaged alongside QA.

## Decision rules and contingencies

- Edge-to-edge: if the QA pass finds inset issues not fixable in under an hour, set `windowOptOutEdgeToEdgeEnforcement` (Google's sanctioned temporary opt-out) and ship, with a cleanup ticket for week two.
- Play review drag: if the closed-track review has not cleared by Aug 23, distribute the same signed build as an APK via direct link to students. No rework; the 14-day clock starts when review clears.
- compileSdk 35 friction: fix plugin or Gradle issues in place; upgrade Flutter only if the build cannot otherwise succeed, because a mid-week toolchain upgrade is pure risk with no pilot-visible payoff.

## Error handling

- Notification permission denied: silent graceful degradation (existing behavior pattern).
- Missing dart-defines at build time: empty Sentry DSN and Supabase values are legal per codemagic.yaml (they disable those features), so the build script does not abort on them; it prints which defines are set and which are empty, so a degraded binary is a visible choice rather than a silent accident.
- Keystore loss: Play App Signing plus password-manager backup.

## Testing

- Automated: existing `flutter test` suite must pass; no new automated tests required (the change surface is config, not logic).
- Manual: the Track 3 emulator matrix, one real-device smoke pass, and the Play pre-launch report.
- Acceptance: a pilot student on Android can join the closed test from the opt-in link, install from Play, complete an FSRS session and a Mock FCLE, and receive a scheduled reminder notification.

## Sequencing summary

Day 1: Play account created (verification clock starts), keystore generated, manifest and gradle changes, icon generation, build script.
Day 1-2: notification permission change, emulator QA, fix findings.
Day 2-3 (gated on verification): Play app created, listing and forms filled, internal track release, Dawood smoke pass.
Day 3-4: promote to closed testing, submit for review, add student testers.
By Aug 24: students installing via closed test; 14-day production clock running. Fallback APK link ready if review is still pending.

## Week-two follow-ups (out of scope, recorded so they are not lost)

- Codemagic `android-release` workflow wrapping `scripts/build_android.sh`, publishing to the closed track via a Play service account.
- Edge-to-edge cleanup if the opt-out flag was used.
- Production promotion once the 14-day requirement clears and Google grants production access.
