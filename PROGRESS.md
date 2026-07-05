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

## Phase 4 — iOS launch readiness ✅ (2026-06-11)

- **Error-handling audit.** Findings: the Wikipedia/Wikidata client had no
  network timeouts (hung socket = spinner forever, no retry) — fixed with a
  10s connect + 15s per-request deadline; timeouts now surface as lastError
  rows so the next screen open retries. Everything else already handled:
  per-card fetch failures render a reason in the detail screen, notification
  permission denial shows guidance and main.dart re-syncs the toggle with OS
  state on launch, portraits are bundled (offline-safe), and every game mode
  is fully local. connectivity_plus removed — its only consumer was the
  Phase-2-deleted SyncEngine.
- **Lint debt: 573 → 0; `flutter analyze` exits clean.** dart fix --apply
  (509 fixes) + hand fixes (including a real BuildContext-across-async-gap).
  Two rules deliberately disabled with documented reasons in
  analysis_options.yaml: avoid_catches_without_on_clauses (bare catch is the
  intended best-effort contract), avoid_dynamic_calls (YAML/JSON boundaries).
- **CI/CD fixes:** Codemagic pr-tests never ran (its branch pattern excluded
  PRs targeting main) — now triggers on every PR, and its bare
  `flutter analyze` step works since the lint sweep. ios-release workflow
  audited: still consistent with the post-cleanup repo (build_runner, tests,
  SENTRY_DSN dart-define, TestFlight publish).
- **Store docs truth pass:** privacy policy now documents opt-in/off-by-default
  crash reporting (it claimed crashes couldn't be disabled and referenced the
  removed analytics toggle), corrects portraits to bundled-not-fetched, and
  aligns the age rating (9+). App Store metadata privacy questionnaire:
  Usage data honestly "No", Diagnostics "Yes, opt-in only"; review notes and
  TestFlight notes updated (incl. chapter replay). support.md checked — fine.
- **Release path verified end-to-end:** full test suite green, analyzer
  clean, and `flutter build ipa --release` produces a signed 43.1MB App
  Store IPA on the dev machine — the exact artifact of the manual
  Transporter submission flow. (Machine note: the rbenv CocoaPods install
  is broken; builds work with Homebrew's pod via
  `PATH="/opt/homebrew/bin:$PATH"`.)

## Phase 5 — Proposals ✅ (2026-06-11)

Written to [PROPOSALS.md](PROPOSALS.md), restructured around two founder
inputs: (a) the core content gap — the app drills recall but never teaches;
(b) the strategy frame — federal MVP only, federal core free forever,
monetize depth/test-prep/citizenship later via subscription + one-time owned
packs. Ranked outcome: #1 lesson layer (→ Phase 6, pre-launch), #2 content-
pack monetization rails (design-only now, zero build), #3 card curation pass
(not expansion), #4 government map revival (post-launch skill tree),
#5 Flutter upgrade (post-launch). Sequencing recommendation included.

## Phase 6 — Lesson layer + guided experience ✅ engineering / ⏳ content review (2026-06-12)

The teach step now exists. Founder decisions folded in: per-card retention
curve + survey benchmarks deferred to Phase 7; "guided experience" = lesson
layer + a first-run tour.

- **Schema v9** (additive): LocalCards gains cardType/body/recallPrompt;
  migration chain v7→v9 tested. Curriculum YAML gains per-day `lessons:`
  blocks (id, day, title, body, related_cards, source) with loader
  validation (founder-approved shape).
- **Briefing phase**: rounds walk briefing → cards → trivia → reveal.
  Swipeable lesson pages; resume-safe; days without lessons skip (tested).
  The sampler drills lesson-related cards first — read, then practice.
- **Teach-first concept cards** on both play surfaces: first encounter =
  lesson + GOT IT (grade good through the unchanged FSRS pipeline);
  afterwards recall via prompt. Face-only filters keep concept titles out
  of Atlas and politician-name MCQ distractors. Two latent SessionQueue
  bugs found and fixed (new-card ratio cap emptying explicit lists; field
  loss at SessionCard reconstruction sites).
- **Legible progression**: chapter sheet lists lesson titles with day
  chips, check marks once played, tap-to-reread after. First-run tour:
  one-time 3-step orientation, skippable, flag in app_meta.
- **Content authored (FOUNDER EDITORIAL REVIEW PENDING)**: chapters 1–3
  fully lessoned — 18 lessons + 23 concept cards, all sourced to official
  sites (archives.gov, constitution.congress.gov, senate.gov, house.gov,
  whitehouse.gov, supremecourt.gov, loc.gov). Concept-card ids equal
  curriculum item ids so the linker resolves them (chapter rounds stop
  falling back to random face cards). Chapters 4–6 are the next authoring
  tranche after review.
- Verification: 190 tests passed + 4 skipped, analyzer clean, iOS build
  succeeds (75.5MB).

## Phase 7 — Retention curve, linker fix, benchmarks, ch4–6 lessons ✅ (2026-06-14)

Four changes, each its own commit. Tests green + analyzer clean at each.

- **Per-card retention curve.** Tap a card in Memory (orbital field or
  strongest-cards list) → a detail screen plotting the FSRS forgetting curve
  across the full review history (sawtooth), with today/next-due markers,
  grade-colored review dots, and plain-language stats (no FSRS jargon shown).
  `ReviewsDao.logsForCard`, `FSRS.retrievabilityCurve` (fractional days),
  `TopCardEntry.id`, `MemoryField.onCardTap`, route `/memory/card/:id`.
- **ContentLinker fix.** `face_card` items resolved to null, so the sampler
  topped rounds up with *random* faces — the guided drill didn't match the
  lesson. Added `card_ids` to curriculum items; linker resolves externalId
  first (existing concept cards win), then the first active card in
  `card_ids`. Mapped the 9 face_card items to their intended faces. Broad
  fallback preserved for genuine gaps.
- **Survey benchmarks.** End-of-round "Did you know" stat keyed to the
  chapter played, also embedded in the share PNG. Every figure is a real,
  sourced survey number (Annenberg 2024/2025; Citizens & Scholars 2018; Pew
  2025) — chapter-keyed because surveys are topic-level and there is no
  player-data backend. New `benchmarks.yaml` + loader + provider; share-card
  line is optional so existing goldens are unchanged.
- **Chapters 4–6 lessons.** 10 briefing lessons authored (ch4 How Laws Get
  Made ×3, ch5 Your Rights ×3, ch6 Voting & You ×4), each sourced to a
  stable .gov page (constitution.congress.gov, congress.gov, archives.gov
  milestone documents, uscourts.gov case summaries, usa.gov, fec.gov,
  uscis.gov). The guided teach layer now spans all six chapters.

**Remaining content tranche (founder editorial review + per-card source
verification):** concept-card decks for chapters 4–6 (~29 cards: ch4
lawmaking powers, ch5 landmark cases, ch6 voting/parties/symbols). Until
authored, ch4–6 card phases fall back to face cards while the briefing
lessons teach. ch1–3 concept cards remain pending editorial review.

---

## Phase 0 (V2) — Backend foundation ✅ (2026-07-04)

Goal: the greenfield Supabase backend per `ARCHITECTURE.md`, data-minimal by
schema, with the append-only event log as the spine.

- **Branch consolidation.** `worktree-ownership-phase1` (29 commits: lesson
  layer, ch2-6 content, YAML seeding, checksum deck versioning, content CI,
  lint zero, opt-in Sentry) merged into `v2-planning`. Conflicts resolved so
  both the review-today hotfix and chapter replay survive; live version
  1.1.0+7 kept. Privacy policy truth pass ported into the canonical
  `docs/privacy-policy/index.html` (deploys with the next release from main).
- **Supabase migrations** (`supabase/migrations/`, 7 files): identity and
  tenancy (pseudonymous profiles, cohorts, join codes), content (four FCLE
  domains seeded, entities, questions with answer keys split into a
  client-inaccessible `app` schema), append-only event log + mock attempts,
  derived read models with a 1:1 plpgsql port of the app's FSRS-4.5,
  cohort-aggregate efficacy rollups (pg_cron nightly), entitlements +
  redemption codes, and the SECURITY DEFINER RPC trust boundary
  (`submit_answer`, `submit_review`, `assemble_mock`, `finalize_mock`,
  `join_cohort`, `redeem_code`, `upsert_faculty_question`).
- **Validated end to end** without Docker: `supabase/tests/run_local.sh`
  boots a throwaway Postgres 17, applies a Supabase auth shim + all
  migrations, and runs `smoke.sql` (full student/faculty lifecycle, mock
  80Q assemble/answer/finalize, idempotent retries, plus RLS negatives:
  no key-table reads, no event forgery/updates, no cross-cohort visibility,
  faculty aggregates only). Passing.

**Next:** YAML -> Postgres content ingest CI, Flutter Supabase auth +
event outbox sync, RevenueCat webhook Edge Function, efficacy one-pager
export.

### Content ingest CI (2026-07-04, same day)

- **Canonical FCLE question bank format** under `content/questions/` (one
  YAML per domain) + `content/fcle/objectives.yaml` (format defined; codes
  await transcription from the official FLDOE competencies document, never
  invented). Starter tranche: 8 original questions (2 per domain), each
  cited to a primary public source, all `status: draft` pending founder
  editorial review (publish is gated at PR review).
- **`scripts/ingest_content.py`**: `--check` validates on every PR (ids,
  options, answer key membership, https citations, explanations, domains,
  objectives, house style); `--db` ingests under a new `content_version`.
  Question ids map to deterministic UUIDv5, so re-ingest updates in place
  and student FSRS state survives edits. Questions removed from YAML are
  unpublished, never deleted. Government graph nodes ingest into
  `public.entities`.
- **`content-ci.yml`** extended: question validation on PRs; on merge to
  main an ingest job runs when the `SUPABASE_DB_URL` secret exists (skips
  quietly until the hosted project is provisioned).
- Verified against a throwaway Postgres: double ingest idempotent, publish
  flip, unpublish-on-removal, malformed YAML rejected with exit 1.

### Flutter auth + outbox sync (2026-07-04, same day)

- **Optional backend wiring in the app.** `SupabaseConfig` reads
  SUPABASE_URL / SUPABASE_ANON_KEY from --dart-define exactly like the
  Sentry DSN: unconfigured builds never initialize Supabase and stay fully
  offline (v1 behavior preserved bit for bit). Codemagic passes both
  through; they are optional secrets.
- **Auth (email OTP, pseudonymous).** `AuthService`: request/verify one-time
  code, sign out, and `ensureProfile()` which creates the server profile
  with a generated neutral handle (adjective_noun_nnnn). The email lives
  only in Supabase Auth; nothing app-visible derives from it. Sign in with
  Apple deferred (needs entitlement + portal setup). Settings gains an
  Account section (hidden in unconfigured builds): sign in is explicitly
  optional copy, sheet does email -> code -> verified.
- **Outbox sync (schema v10).** New `outbox_events` Drift table + OutboxDao
  (FIFO, per-row tries, dead-letter after 8). `SyncEngine` behind a
  `SyncTransport` boundary: answers -> submit_answer RPC, reviews ->
  submit_review RPC, session boundaries -> direct insert (RLS-allowed).
  Client-generated UUIDv4 event ids make retries idempotent; 23505 on
  replay counts as delivered. Transient errors stop the pass (retry on next
  trigger: enqueue, sign-in, app launch); permanent server rejections
  record the error and never dam the queue. Enqueue is a no-op unless a
  backend is configured AND a user is signed in: nothing leaves the device
  otherwise.
- **Hooks.** Daily round emits session_start on creation and session_end on
  completion (efficacy engagement metrics). FCLE answer/review enqueue
  paths are built and tested, activating when the FCLE prep UI ships;
  v1 face/concept card reviews intentionally stay local (their cards are
  not in the server question bank).
- Tests: 9 new sync-engine tests (idempotence, ordering, transient vs
  permanent failure, dead-lettering, field carriage); migration test now
  pins v10 + outbox table. Full suite green, analyze clean.
- NOT yet verified against a hosted Supabase project (none provisioned);
  the transport talks to the RPC contract validated by supabase/tests.

### FCLE Prep UI + Edge Functions + compliance scaffolds (2026-07-04, same day)

- **FCLE prep feature (local-first).** The bank YAML ships in app assets
  (CI drift check mirrors the government.yaml pattern). New feature module:
  question model over the four-domain taxonomy, published-only bank loader
  (drafts never reach students), MockEngine (80Q, 4x20 in domain order, no
  repeats, 48-to-pass grading, per-domain breakdown, weakest-domain pick),
  schema v11 fcle_answers local log, per-domain rolling-accuracy readiness
  (window 50, matching the server read model), and weak-area practice sets
  (missed first, then unseen). Dart uuidV5 port pinned bit-for-bit to the
  Python ingest via fixtures, so outbox answer events reference the exact
  server question UUIDs.
- **Screens + flow.** Hub (readiness bars, mock CTA with a bank-growing
  state until 20/domain exist, per-domain practice), Mock exam (no feedback
  until the end, exam-mirroring; answers recorded one by one so
  backgrounding loses nothing), Results (score vs the 60% bar, per-domain
  bars, straight into weakest-area practice), Practice (immediate feedback
  with explanation + tappable primary-source citation). Home gains an FCLE
  tile ("Could you pass?"). Positioning copy everywhere: supplemental
  practice, not the official exam, not a predictor.
- **Sync tie-in.** Every FCLE answer logs locally and enqueues to the
  outbox (server UUID, chosen key); readiness works fully offline; server
  efficacy accumulates when signed in. Server-side mock_attempts
  (assemble_mock online flow) is deliberately deferred until the hosted
  project exists.
- **Edge Functions authored** (deploy pending hosted project):
  revenuecat-webhook (shared-secret auth, entitlement mirror, verify_jwt
  off) and efficacy-report (printable cohort one-pager HTML; runs under
  the caller's JWT so RLS keeps it faculty-only).
- **Compliance scaffolds** in docs/compliance/: AI usage note (HECVAT 4 AI
  section), DPA template (FERPA school-official fallback), VPAT 2.5
  scaffold with the WCAG 2.1 A/AA criteria list + known work items, HECVAT
  4.1.5 answer bank keyed to the data-minimal posture.
- Tests: 17 new FCLE tests (engine, loader, DAO, practice-set builder,
  uuid5 parity). Full suite green, analyze clean.
