# CODEBASE_BRIEF — Politiface

Reconnaissance report, generated 2026-06-11 from branch `feature/pages-pretty-urls` (21 commits).
Written for an outside technical advisor. No code was modified.

---

## 1. IDENTITY

**Name:** Politiface (bundle ID `io.politiface.politiface`, version `1.1.0+2`)

**What it actually is, as built:** An offline, single-user iOS flashcard app that teaches the
structure and personnel of the **US federal government only**. The user plays a daily
"chapter round" (FSRS-graded face/role cards followed by a short trivia quiz), an endless mode,
and a standalone trivia mode; browses a searchable "Atlas" of 46 politicians with lazily-fetched
Wikipedia bios; and tracks streaks, XP, and per-card mastery. All state lives in a local Drift
(SQLite) database. There are **no accounts, no cloud sync, no leaderboards, and no analytics**,
despite README/marketing copy implying all four. The only network calls the app makes are
Wikipedia/Wikidata bio fetches and Sentry crash reports.

**Versions:** Flutter 3.22.0 (pinned in CI and `.metadata`; released May 2024 — ~2 years old).
Dart SDK constraint `>=3.3.0 <4.0.0`.

**Target platforms:** All six platform directories exist (`ios`, `android`, `macos`, `windows`,
`linux`, `web`), but only iOS is real: launcher icons are `android: false` ("iOS-only V1"),
the Codemagic release pipeline builds only an iOS IPA, and Android/desktop/web dirs are
untouched Flutter templates. iOS deployment target is 12.0.

---

## 2. STACK INVENTORY

Persistence layer: **Drift (SQLite) on device, schema v7, 13 tables — and that is the entire
persistence story.** A Supabase Postgres schema exists (`supabase/migrations/001_initial.sql`,
15 tables incl. partitioned reviews, leagues, RLS policies) and a `SyncEngine` class exists
(`app/lib/core/sync/sync_engine.dart`), but the schema has never been deployed,
`Supabase.initialize()` is never called, and `SyncEngine` is **never instantiated anywhere**.
There is no functioning remote backend, API of its own, or sync mechanism in the code.

Dependencies (`app/pubspec.yaml`; resolved versions from `pubspec.lock`):

| Package | Purpose | Actually used? |
|---|---|---|
| flutter_riverpod 2.6.1 | State management | USED — 41 imports, all hand-written providers |
| riverpod_annotation | Codegen annotations | **UNUSED** — zero imports; project deliberately avoids codegen |
| drift 2.21.0 | Local SQLite ORM | USED — 24 imports, core of the app |
| drift_flutter | Drift platform glue | USED (via `driftDatabase()`) |
| sqlite3_flutter_libs | Native SQLite binaries | Build-time native dep (no import expected) — required |
| path_provider | App dirs | USED (1 import) |
| path | Path utils | **UNUSED** — declared, never imported |
| supabase_flutter 2.12.4 | Remote backend | **DEAD** — single import, in never-instantiated SyncEngine |
| go_router 14.8.1 | Navigation | USED — 22 imports, StatefulShellRoute + 17 routes |
| cached_network_image | Remote image cache | USED (2 imports) |
| connectivity_plus | Network status | USED (1 import) |
| flutter_local_notifications | Daily reminder | USED — 7 PM local reminder, wired to settings toggle |
| timezone | Notification scheduling | USED |
| sentry_flutter 8.14.2 | Crash reporting | USED — init in `main.dart`, the only telemetry in the app |
| flutter_animate | Animations | USED (6 imports) |
| shimmer | Loading shimmer | **UNUSED** — zero imports |
| confetti | Celebration FX | USED (1 import) |
| share_plus | Share result cards | USED (5 imports) |
| url_launcher | External links | USED (2 imports) |
| intl | Formatting/i18n | **UNUSED** — zero imports |
| flutter_dotenv | .env loading | **UNUSED** — never loaded; `.env` asset entry commented out |
| package_info_plus | Version display | USED (1 import) |
| collection | HeapPriorityQueue | USED — session queue |
| yaml | Content parsing | USED — deck/curriculum/atlas loaders |
| flutter_secure_storage | Auth tokens | **UNUSED** — declared for auth that doesn't exist |
| google_fonts | Editorial typeface | USED (2 imports) |
| flutter_localizations | SDK l10n | Declared; app is English-only |
| dev: drift_dev, build_runner | Drift codegen | USED (`.g.dart` files present) |
| dev: riverpod_generator | Riverpod codegen | **UNUSED** — no generated providers exist |
| dev: flutter_lints 4.x, flutter_launcher_icons | Lints / icons | USED |

Nothing is dangerously outdated *relative to the pinned Flutter 3.22*, but the whole stack is
frozen on a May-2024 toolchain: Riverpod 3.x, newer Drift/go_router/Sentry majors, and two years
of Flutter releases are all pending. Commented-out pubspec entries record deferred plans:
firebase_messaging ("when push notifications land") and posthog_flutter ("when analytics events
get wired").

---

## 3. ARCHITECTURE MAP

```
politiface/
├── app/                  Flutter application (the only runnable artifact)
│   ├── lib/app/          Bootstrap: router (17 routes), providers.dart (all Riverpod
│   │                     providers, hand-written), theme, 3-tab shell scaffold
│   ├── lib/core/         database/ (Drift schema v7 + 10 hand-written DAOs),
│   │                     sync/ (dead SyncEngine), cache/ (LRU util)
│   ├── lib/features/     16 feature dirs, mostly data/domain/presentation layered:
│   │                     atlas, curriculum, daily_challenge (legacy), endless,
│   │                     government, history, home, memory, notifications, profile,
│   │                     progression, round, session (FSRS core), settings, shared, trivia
│   ├── test/             17 test files, pure-Dart unit + widget/golden tests
│   └── assets/           content/ (decks, curriculum, atlas YAML) + portraits/ (44 imgs)
├── content/              Source-of-truth content: governments/us/government.yaml +
│                         portraits/ (untracked duplicate of app/assets/portraits)
├── supabase/migrations/  Designed-but-never-deployed Postgres schema
├── scripts/              Python: content validation, Wikidata portrait fetch/wiring, icon gen
├── docs/                 GitHub Pages: privacy policy, support, App Store metadata
├── .github/workflows/    CI: analyze+test gate, secrets-hygiene check, YAML validation
├── codemagic.yaml        iOS release pipeline → TestFlight
└── {app/                 Empty directory tree from a botched shell brace-expansion (junk)
```

**State management:** Riverpod 2, 100% hand-written providers in `app/lib/app/providers.dart`
(Provider / FutureProvider / StreamProvider / AsyncNotifierProvider). No codegen. A
`sessionTickProvider` counter is bumped after each graded card to invalidate profile/stat
providers — simple and effective, if blunt.

**Data flow (storage → UI):** Bundled YAML → seed services upsert into Drift on launch
(flag-gated) → DAOs → repositories/services → Riverpod providers → screens. Review path:
`SessionController.grade()` → `CardReviewRepository.recordGrade()` → pure `FSRS.schedule()` →
Drift transaction (upsert `CardMemoryStates`, append `ReviewLogs`) → `ProfileService` XP/streak →
tick provider → UI rebuild.

**FSRS:** Lives in `app/lib/features/session/domain/fsrs_algorithm.dart` (228 lines, pure Dart,
no deps). It is a **genuine, complete FSRS-4.5 implementation**: the 17 default weights match
the published fsrs4anki values exactly; power-law forgetting curve `R = (1 + t/9S)^-1`;
correct initial stability/difficulty, mean-reverting difficulty update, the published
stability-after-recall and stability-after-lapse formulas with hard-penalty/easy-bonus
(w15/w16); 4-grade scale; fractional-day elapsed time; sane clamps (D∈[1,10], S≤36500d).
25 unit tests cover it. Divergences from reference implementations: **no interval fuzzing**
(optional in upstream), and a deliberate policy layer in `card_review_repository.dart` that
routes same-day repeats to a "practice" path (XP only, FSRS state frozen) so unspaced repeats
don't corrupt the memory model — a sound design choice, not a bug.

---

## 4. CONTENT PIPELINE

**Volume (all of it):** 1 country (US). 7 decks / **46 cards total** (Presidency 5, EOP 5,
Cabinet 12, SCOTUS 9, Congress 5, Senate 5, House 5). 1 curriculum (`us_civics.yaml`):
6 chapters, ~83 concept/face items. 9 government nodes + 10 edges. 44 politician portraits
with a Wikidata-derived `manifest.json`. That's the whole content library.

**Schemas:** `content/governments/us/government.yaml` defines meta + nodes (tier_order,
unlock_requires, map coords) + edges. Deck YAMLs hold cards (name, title, party, `photo_url`,
gender, `node_id` linking to the government graph). Curriculum YAML defines a chapter →
branch → item hierarchy validated by `CurriculumLoader` (throws on schema error).

**How it reaches the app:**
- Deck/curriculum/atlas YAML is bundled under `app/assets/content/` and parsed in-app:
  `YamlSeedService` upserts decks/cards into Drift, gated by a manual version flag
  (`yaml_seed_v3_done` — content updates require remembering to bump it); user memory state
  is preserved across re-seeds. `CurriculumLoader` parses curriculum into memory each launch.
- **The government graph does NOT come from the YAML.** `gov_seed_data.dart` is a hardcoded
  Dart mirror of `government.yaml`, seeded by `GovernmentSeedService`. Comments say the YAML
  pipeline would replace it "in a later phase" — that phase never shipped. Two sources of truth.
- Portraits: `scripts/fetch_wikidata_portraits.py` downloads images + manifest from Wikidata;
  `scripts/wire_portraits.py` rewrites `photo_url`/`gender` into deck YAMLs pre-build.
  `app/assets/portraits/` (47 files) is tracked; `content/portraits/` is a byte-identical
  **untracked** duplicate.
- `scripts/validate_government.py` runs in CI on PRs (cycles, reachability, coord ranges).

**Hardcoded vs data-driven:** Card/people content is fully data-driven. Country is not:
`usGovernmentId`, the curriculum path `us_civics.yaml`, and the gov graph are hardcoded.
CONTRIBUTING.md promises "add your country with just YAML" — **untrue today**; a second country
needs Dart changes. README's self-hosting section references `scripts/seed_governments.py` and
`scripts/seed_decks.py` — **neither exists** — and a `docker-compose.yml` that also doesn't exist.

---

## 5. FEATURE STATUS TABLE

| Feature / screen | Status | Evidence |
|---|---|---|
| 3-tab shell (Home / Atlas / Memory) | COMPLETE | `router.dart` StatefulShellRoute; all tabs render real data |
| Home screen (streak hero, chapter card) | COMPLETE | `home_screen.dart`; CTA navigates to `/round` (`chapter_round_card.dart:194`) |
| Daily Round (cards + trivia phases) | COMPLETE | `/round` routed; controller has 10 passing tests (resume, phase flips, FSRS+XP) |
| Session (FSRS review) | COMPLETE | `/session` wired end-to-end to FSRS; tested |
| FSRS-4.5 engine | COMPLETE | Verified against published weights/equations; 25 tests |
| Endless mode + emoji-grid share | COMPLETE | `endless_screen.dart`; ShareCardRenderer + share_plus |
| Trivia mode (confidence betting) | COMPLETE | `trivia_screen.dart`; scoring/generator/golden tests pass |
| Atlas (politician browser + search) | COMPLETE | `atlas_screen.dart`; mastery rings, wired to `/map` tab |
| Politician detail + Wikipedia bio | COMPLETE | `politician_detail_screen.dart`; live Wikidata/Wikipedia fetch, cached in Drift |
| Node detail + deck picker | COMPLETE | `node_detail_screen.dart`; some tiers show "Content coming soon" (line ~130) |
| Government map (visual node tree) | **STUB/ORPHANED** | `GovMapScreen` exists but **no route builds it** — `/map` renders AtlasScreen; README's headline feature is unreachable |
| Progression / unlock state machine | COMPLETE | `progression_state_machine.dart`; 19 tests |
| Streaks, XP, levels | COMPLETE | `profile_service.dart`; graded per-review, tested |
| Memory screen (mastery stats) | COMPLETE | `memory_screen.dart`; tier distribution from Drift |
| History (per-mode run review) | COMPLETE | `history_screen.dart`; CompletedRuns table (schema v7) |
| Settings: theme, reminder, reset | COMPLETE | Toggles persist and act; reset wipes FSRS state |
| Settings: analytics opt-in toggle | **STUB** | Toggle stores a flag that **gates nothing** — no analytics code exists |
| Daily Challenge (legacy 5-card) | PARTIAL/LEGACY | `daily_challenge_service.dart` + cache table remain but superseded by Daily Round; dual systems coexist |
| Leagues / leaderboards | **STUB** | README advertises; only `TODO(post-leaderboards)` markers (`trivia_review_screen.dart:22,430`) |
| Accounts / auth | **ABSENT** | No screens, no flow; every row keyed to hardcoded `'local-user'` (`app_database.dart:118`) |
| Cloud sync | **STUB** | SyncEngine never instantiated; `SyncMeta` table never written; `ReviewLogs.synced` always false |
| Multiple card types (face/role/concept/sequence) | PARTIAL | Enum exists in schema; one unified card renderer, no type-specific UI; concept content largely unauthored (`chapter_content_sampler.dart:14` — "most curriculum items resolve to null", falls back to face cards) |
| Push notifications / Firebase | ABSENT | Commented out of pubspec; local notifications only |
| Onboarding | COMPLETE | Flag in meta table; reset re-triggers it |

---

## 6. QUALITY SIGNALS

- **Tests:** 17 test files, **158 passing, 4 skipped, 0 failing** (run 2026-06-11, ~13s).
  Coverage is concentrated on domain logic: FSRS (25), trivia scoring/generation (34 incl.
  goldens), progression (19), daily round controller (10), session queue/repository (21),
  curriculum (21), profile (6), unlocks (4). **Zero tests** for DAOs/migrations directly,
  routing, or most presentation code beyond trivia share cards.
- **flutter analyze:** passes — **0 errors, 0 warnings, 551 info-level style lints**
  (trailing commas, double literals, etc.). CI gates on warnings/errors only, so green.
- **Builds:** iOS release build **succeeds** on this machine (`flutter build ios --no-codesign`
  → Runner.app, 76.3MB, Xcode 26.5). Android **unverified**: not built by CI, launcher icons
  disabled, local SDK has unaccepted licenses; treat Android as never exercised.
- **CI:** GitHub Actions (`flutter-ci.yml`: analyze + test; `security.yml`: asserts `.env` and
  keystores are never committed; content validation on PRs) plus Codemagic `ios-release`
  (test → build IPA → TestFlight) and `pr-tests`. Sensible and real.
- **Secrets:** none found in the repo. `app/.env.example` (placeholder names only:
  Supabase/PostHog/Sentry), `codemagic.yaml` (references to a secrets group: App Store Connect
  keys, cert key, SENTRY_DSN), `GIT_AND_FLUTTER_SETUP.sh` (variable names in comments).
  No `.env` on disk, properly gitignored, no keystores. Clean.

---

## 7. RISK REGISTER (ranked)

1. **Public privacy claims describe software that doesn't exist** — README + `VERIFIED.md`
   publish a "complete list of analytics events we send", but there is zero analytics code
   (`app/lib`, no PostHog); the trust-through-transparency positioning is currently fiction
   in both directions (nothing is sent, but the published event list is unverifiable-by-code).
2. **No LICENSE file** (repo root) — README claims MIT; legally the code is all-rights-reserved,
   which undermines the entire "open source as proof" pitch and blocks contributions.
3. **README features that are vapor** — "syncs when connected", "leagues", "government map"
   (README.md) are respectively dead code, a TODO, and an orphaned screen; an App Store
   reviewer or technical user comparing claims to app will find gaps.
4. **Government structure has two sources of truth** — `content/governments/us/government.yaml`
   vs hardcoded `gov_seed_data.dart`; edits to the YAML do nothing at runtime, and CI validates
   the file the app ignores.
5. **CONTRIBUTING.md promises no-code country additions that the code can't honor** —
   `usGovernmentId` and `us_civics.yaml` hardcoded (`gov_seed_data.dart`,
   `curriculum_loader.dart:19`); a contributor following the guide hits a wall.
6. **~600 lines of dead backend code invite false confidence** — `sync_engine.dart` +
   `supabase/migrations/001_initial.sql` + `SyncMeta` table + supabase_flutter/
   flutter_secure_storage deps; anyone (or any AI) reading the repo will overestimate maturity.
7. **`content/portraits/` (44 images + manifest) is untracked in git** — a byte-identical copy
   is tracked under `app/assets/portraits/`, but the "source" copy can silently diverge or be
   lost; provenance pipeline (fetch → wire) isn't reproducible from the repo state.
8. **Manual seed-flag versioning** (`yaml_seed_v3_done`, `yaml_seed_service.dart`) — shipping
   content edits without remembering to bump the flag means existing installs never see them;
   no checksum/auto-detection.
9. **Toolchain frozen at Flutter 3.22 (May 2024)** — pinned in CI and Codemagic; two years of
   framework/dependency drift (Riverpod 3, newer Drift/Sentry) accrues into one painful upgrade,
   and App Store SDK-minimum requirements will eventually force it on a deadline.
10. **Legacy/duplicate subsystems left in place** — daily_challenge (superseded by round),
    orphaned `GovMapScreen`, the empty `{app/...}` brace-expansion directory tree at repo root,
    analytics toggle that gates nothing; individually trivial, collectively the codebase lies
    about itself.

---

## 8. OPEN QUESTIONS (founder intent needed)

1. **Is Supabase still the plan?** Keep the schema + SyncEngine as a roadmap artifact, or
   delete ~600 lines of dead code and 4 unused dependencies until accounts are actually next?
2. **VERIFIED.md direction:** implement the listed PostHog events behind the existing opt-in
   toggle, or rewrite the doc to say "we currently send nothing except opt-in crash reports"?
3. **MIT license:** was omission of the LICENSE file an oversight? (One-file fix, but it
   changes the legal status of every existing clone.)
4. **Government map:** is the visual node-map (`GovMapScreen`) still the product vision, or
   has the Atlas grid permanently replaced it? Decide before more content assumes map coords.
5. **Multi-country:** is internationalization a real near-term goal (justifying the
   parameterization work) or should CONTRIBUTING.md be scoped to "US content fixes" for now?
6. **Which is canonical for government structure** — the YAML (then build the loader that was
   deferred) or the Dart seed (then delete/demote the YAML and its CI validator)?
7. **Legacy daily_challenge code + `DailyChallengeCaches` table:** safe to remove, or do any
   shipped TestFlight builds still read them (migration concern)?
8. **Android/web:** the template dirs and README "single codebase for iOS, Android, and Web"
   imply intent — is there a target date, or should docs say iOS-only V1?
9. **`content/portraits/` untracked:** commit it (provenance) or gitignore it (it's ~44 images
   duplicated in assets)? Same question for the junk `{app/` directory (delete?).
10. **Card types:** schema reserves face/role/concept/sequence, but concept content is
    unauthored and there's one renderer — is authoring concept cards the next content milestone,
    or should the enum be trimmed to what exists?
