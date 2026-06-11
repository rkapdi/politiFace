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

## Phase 2 — Dead code removal (NEXT, awaiting approval)

Planned:
- Delete `SyncEngine`, `supabase/` directory, `SyncMeta` table usage.
- Drop unused deps: supabase_flutter, flutter_secure_storage, flutter_dotenv, shimmer,
  intl, path, riverpod_annotation, riverpod_generator.
- Remove the analytics opt-in toggle from Settings + its stored flag.
- Remove legacy daily_challenge subsystem + `DailyChallengeCaches` table via a
  **Drift v7→v8 migration** that preserves FSRS state, streaks, XP, CompletedRuns;
  with a migration test seeding a v7 DB and verifying user-data survival.
- Proposed addition (needs founder sign-off): in-app crash-reporting consent toggle so
  "opt-in Sentry" becomes true (see Phase 1 honesty note).

## Phase 3 — Canonical content pipeline (pending)

Government graph parsed from `content/governments/us/government.yaml` at seed time;
delete `gov_seed_data.dart`; CI validates the file the app actually uses;
checksum-based seed versioning replaces the manual `yaml_seed_v3_done` flag;
tests prove content edits propagate without data loss.

## Phase 4 — iOS launch readiness (pending)

Error-handling audit (Wikipedia fetch, offline, notification denial); release path
verification (build, Codemagic, App Store metadata vs. truth-reconciled features);
lint cleanup or documented waiver.

## Phase 5 — Proposals (pending)

Top-5 highest-leverage pre-launch improvements with effort estimates, incl. concept
cards, content expansion past 46 cards, Flutter 3.22 upgrade path, government map
revival.
