# PROGRESS

Working log for the launch-readiness phases. Baseline state of the codebase is in
[CODEBASE_BRIEF.md](CODEBASE_BRIEF.md). Post-launch projects live in [ROADMAP.md](ROADMAP.md).

Standing constraints (apply to every phase):
- Never modify the FSRS algorithm or the same-day practice-path policy in
  `card_review_repository.dart` without explicit approval.
- Never commit secrets. Preserve user memory state in every migration.
- No Flutter upgrade / major dependency bumps in this effort (separate future project).
- Tests green and `flutter analyze` clean (no warnings/errors) at every commit.

---

## Phase 1 — Truth reconciliation ✅ (2026-06-11)

Goal: the repo tells the truth about itself before any code changes.

- **LICENSE** (MIT) added at repo root. README had claimed MIT with no license file.
- **README.md** rewritten to describe only what exists: iOS-only V1, fully offline,
  no accounts, no analytics, MIT. Removed claims of cloud sync, leagues/leaderboards,
  government map, Android/web support, and references to nonexistent
  `seed_governments.py`, `seed_decks.py`, and `docker-compose.yml`.
- **VERIFIED.md** rewritten to the truth: no analytics exist; the only telemetry is
  Sentry crash reporting; removed the fictional analytics event list.
  **Honesty note:** Sentry in official builds is enabled by default, not opt-in
  (`main.dart` initializes unconditionally; DSN injected by Codemagic). VERIFIED.md
  states this plainly as a known gap. → Decision needed: build an in-app consent
  toggle (proposed for Phase 2 alongside removing the dead analytics toggle).
- **CONTRIBUTING.md** rescoped to US content fixes + code contributions. Removed the
  no-code country-addition promise (code can't honor it) and the Supabase/.env dev
  setup (no backend exists). Fixed wrong content paths (`content/decks/` →
  `app/assets/content/decks/`).
- **content/portraits/** (46 images + manifest.json) committed for provenance —
  previously untracked, byte-identical to the bundled `app/assets/portraits/`.
- **`{app/` junk directory** (empty brace-expansion accident, untracked) deleted from
  the working copy.
- **ROADMAP.md** added with the founder's "Over-the-air content packs" post-launch
  project spec.
- Verification: `flutter test` green, `flutter analyze` 0 errors / 0 warnings.

## Phase 2 — Dead code removal ✅ (2026-06-11)

- **Supabase fully cut:** deleted `core/sync/sync_engine.dart` (never
  instantiated), the `supabase/` schema directory, and `.env.example`. Removed
  8 unused deps (supabase_flutter, flutter_secure_storage, flutter_dotenv,
  shimmer, intl, path, riverpod_annotation, riverpod_generator); added
  `sqlite3` as an explicit dev dep for migration-test fixtures.
- **Plan correction, flagged:** `SyncMeta` was NOT dead sync code — it is the
  app's key-value store (streak, XP, settings, seed flags, pending-session
  snapshot); my reconnaissance brief was wrong on this point. Instead of
  dropping it, schema v8 renames `sync_meta` → `app_meta` in place; every row
  survives. The always-false `ReviewLogs.synced` column stays (dropping a
  column = full table rebuild; not worth the risk for a cosmetic win).
- **Legacy daily_challenge subsystem removed** (service, providers, the
  challenge-origin plumbing in SessionController/PendingSessionStore — the
  flow was already unreachable from the UI). Schema v8 drops
  `daily_challenge_caches`; FSRS reviews made during old challenges live in
  `review_logs`/`card_memory_states` and are untouched.
- **Migration test added** (`app/test/core/database/migration_v7_to_v8_test.dart`):
  seeds a real v7 database from verbatim captured v7 DDL with FSRS state,
  review logs, streak (42) / XP (1337) meta, chapter progress, history, node
  progress, and a populated legacy cache row → opens under v8 → asserts
  bit-for-bit survival, dropped/renamed tables, user_version 8.
- **Crash reporting is now truly opt-in** (founder-approved item 6): the dead
  analytics toggle is gone; a working Settings → Privacy → Crash reports
  toggle (default OFF) gates `SentryFlutter.init` in `main.dart`. No consent
  or no DSN → the SDK never starts. VERIFIED.md's known-gap note removed
  because the gap is fixed. Tests pin the default-off posture.
- **Stale docs cleaned:** SETUP.md rewritten for the offline reality;
  GIT_AND_FLUTTER_SETUP.sh (Supabase-era genesis script) deleted;
  docs/index.md checked — already truthful.
- Verification: 157 tests passed + 4 skipped, `flutter analyze` 0 errors /
  0 warnings, iOS release build succeeds.

## Phase 3 — Canonical content pipeline ✅ (2026-06-11)

- **Government graph now loads from YAML** (`government_yaml_loader.dart` +
  rewritten `GovernmentSeedService`); `gov_seed_data.dart` deleted. The canonical
  file is `content/governments/us/government.yaml`; the app bundles a
  byte-identical copy under `app/assets/content/governments/us/` (Flutter can't
  bundle outside the package) and CI fails on drift between the two.
- **Canonical-wins divergences adopted:** node names/descriptions where the Dart
  mirror had drifted (e.g. "The Senate" vs "United States Senate"); the loader
  also now populates `map.icon`/`map.label_position` (schema columns the Dart
  seed never set). The YAML `concepts:` section is NOT ingested — no table for
  it yet; that's Phase 5 concept-card territory.
- **Checksum-based reseeding** replaces manual flag bumping for BOTH seeders
  (`seed.government_hash`, `seed.decks_hash` in app_meta; SHA-256 via
  `core/content/content_checksum.dart`). Content edits reach existing installs
  on next launch; unchanged content is a no-op; legacy flags
  (`gov_seed_v1_done`, `yaml_seed_v3_done`) cleaned up on first checksum seed.
  This is the mechanism the OTA-content-packs roadmap project piggybacks on.
- **Data-safety guarantees, tested (26 new tests):** progress rows are
  insert-if-absent only (a content update can never reset unlocks — new
  `ProgressDao.insertIfAbsent`); FSRS memory state survives deck re-seeds
  bit-for-bit; nodes removed from content are deactivated, never deleted;
  malformed bundled YAML keeps the existing graph instead of crashing/wiping.
- **Graph contract pinned:** `government_yaml_loader_test.dart` parses the real
  bundled YAML and pins the node-ID set, tiers, and unlock graph — exactly the
  values the deleted Dart seed carried (the parity proof). Node IDs are forever;
  renaming one now fails CI.
- **New CI workflow** `.github/workflows/content-ci.yml`: runs
  `validate_government.py` on the canonical file (no content CI existed before —
  CONTRIBUTING's claim was aspirational until now) + the canonical/bundled sync
  check. Validator passes locally.
- Verification: 179 tests passed + 4 skipped, `flutter analyze` 0 errors /
  0 warnings, iOS release build succeeds (75.4MB).

## Interlude — founder-reported fixes (2026-06-11, pre-Phase 4)

- **Chapter replay** (founder request, from device screenshots): completed
  chapters showed a dead-end "Replay coming with History" banner. Now a
  REPLAY THIS CHAPTER button samples 10 cards from the chapter pool and
  launches a session via a new explicit-card-list path
  (`activeSessionCardIdsProvider`). Non-due cards load by design; the FSRS
  practice path makes replays safe for the memory model. 3 new tests.

## Phase 4 — iOS launch readiness (pending)

Error-handling audit (Wikipedia fetch, offline, notification denial); release path
verification (build, Codemagic, App Store metadata vs. truth-reconciled features);
lint cleanup or documented waiver.

## Phase 5 — Proposals (pending)

Top-5 highest-leverage pre-launch improvements with effort estimates, incl. concept
cards, content expansion past 46 cards, Flutter 3.22 upgrade path, government map
revival.
