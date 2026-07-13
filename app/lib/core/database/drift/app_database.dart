// lib/core/database/drift/app_database.dart
//
// Local SQLite database via Drift.
// This is the SOURCE OF TRUTH — the app is fully offline; there is no backend.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../daos/cards_dao.dart';
import '../daos/chapter_progress_dao.dart';
import '../daos/completed_runs_dao.dart';
import '../daos/daily_rounds_dao.dart';
import '../daos/decks_dao.dart';
import '../daos/fcle_answers_dao.dart';
import '../daos/government_dao.dart';
import '../daos/meta_dao.dart';
import '../daos/outbox_dao.dart';
import '../daos/people_dao.dart';
import '../daos/politician_bios_dao.dart';
import '../daos/progress_dao.dart';
import '../daos/reviews_dao.dart';

part 'app_database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class GovNodes extends Table {
  TextColumn get id => text()();
  TextColumn get governmentId => text()();
  TextColumn get externalId => text().unique()();
  TextColumn get name => text()();
  TextColumn get shortName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get nodeType => text()();
  BoolColumn get isHeadOfState =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isHeadOfGovt => boolean().withDefault(const Constant(false))();
  BoolColumn get isElected => boolean().nullable()();
  RealColumn get mapX => real().nullable()();
  RealColumn get mapY => real().nullable()();
  RealColumn get mapWidth => real().nullable()();
  RealColumn get mapHeight => real().nullable()();
  TextColumn get mapShape => text().withDefault(const Constant('rectangle'))();
  TextColumn get mapIcon => text().nullable()();
  TextColumn get mapColor => text().nullable()();
  TextColumn get mapLabelPos => text().withDefault(const Constant('bottom'))();
  IntColumn get tierOrder => integer()();
  TextColumn get unlockRequires =>
      text().withDefault(const Constant('[]'))(); // JSON array
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class GovEdges extends Table {
  TextColumn get id => text()();
  TextColumn get governmentId => text()();
  TextColumn get fromNodeId => text()();
  TextColumn get toNodeId => text()();
  TextColumn get relationshipType => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVisibleOnMap =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lineStyle => text().withDefault(const Constant('solid'))();
  TextColumn get lineColor => text().nullable()();
  TextColumn get arrowDirection => text().withDefault(const Constant('to'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalDecks extends Table {
  TextColumn get id => text()();
  TextColumn get nodeId => text().nullable()();
  TextColumn get governmentId => text().nullable()();
  TextColumn get externalId => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get tierOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('published'))();
  IntColumn get cardCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()(); // Unix timestamp for watermark sync
  // Whether this deck's cards enter the global rotation (daily session,
  // Endless, Trivia, round fallback). Defaults true so curated decks keep
  // current behavior; delegation decks are seeded unsubscribed (opt-in).
  BoolColumn get isSubscribed => boolean().withDefault(const Constant(true))();
  // 'curated' (bundled YAML decks) or 'delegation' (in-app generated state
  // delegation decks).
  TextColumn get category => text().withDefault(const Constant('curated'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text()();
  TextColumn get externalId => text().unique()();
  TextColumn get politicianName => text()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get lqipBase64 => text().nullable()();
  TextColumn get title => text()();
  TextColumn get party => text().nullable()();
  TextColumn get jurisdiction => text().nullable()();
  TextColumn get oneLiner => text().nullable()();
  TextColumn get sourceUrl => text()();
  // Wikidata P21 sex/gender: 'male', 'female', 'nonbinary', or null. Drives
  // gender-aware distractor selection in TriviaGenerator + EndlessEngine so
  // "identify the male senator" doesn't get women as wrong-option foils.
  TextColumn get gender => text().nullable()();
  // 'face' (politician recognition) or 'concept' (civics fact). Concept
  // cards teach on first encounter (body) and recall afterward (recallPrompt).
  TextColumn get cardType => text().withDefault(const Constant('face'))();
  TextColumn get body => text().nullable()(); // teach-first prose
  TextColumn get recallPrompt =>
      text().nullable()(); // later-encounter question
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()(); // Unix timestamp

  @override
  Set<Column> get primaryKey => {id};
}

// ── FSRS Memory State (hot table — O(cards seen) rows) ──────────────────────
// Split from review log for performance.
// FSRS only needs current state to compute next review.
class CardMemoryStates extends Table {
  TextColumn get cardId => text()(); // PRIMARY KEY
  // userId is 'local-user' for the no-account MVP. When Supabase auth ships,
  // backfill with auth.uid() and the rest of the schema is unchanged.
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  RealColumn get difficulty =>
      real().withDefault(const Constant(5))(); // FSRS D: 1-10
  RealColumn get stability =>
      real().withDefault(const Constant(1))(); // FSRS S: days to 90% retention
  RealColumn get retrievability => real()
      .withDefault(const Constant(1))(); // FSRS R: current recall probability
  IntColumn get lastReviewedAt =>
      integer().withDefault(const Constant(0))(); // Unix timestamp
  IntColumn get nextReviewAt =>
      integer().withDefault(const Constant(0))(); // Unix timestamp — INDEXED
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  BoolColumn get isNew => boolean().withDefault(const Constant(true))();
  // Practice-mode counter: increments on every same-day re-grade that doesn't
  // touch FSRS state (see CardReviewRepository.recordGrade). Resets to 0 when
  // a real FSRS review fires. Drives the demonstrated-recall unlock gate.
  IntColumn get practiceCountSinceReview =>
      integer().withDefault(const Constant(0))();
  // Last grade observed (0..3), set on EVERY grade including practice mode.
  // Used by the unlock gate (must be >= Good to count toward tier mastery).
  IntColumn get lastGrade => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {cardId};
}

// ── Review log (append-only — not queried during sessions) ───────────────────
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get cardId => text()();
  IntColumn get reviewedAt => integer()(); // Unix timestamp
  IntColumn get grade => integer()(); // 0=again, 1=hard, 2=good, 3=easy
  RealColumn get stability => real()(); // FSRS state AFTER this review
  RealColumn get difficulty => real()();
  RealColumn get retrievability => real()();
  IntColumn get intervalDays => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

// ── User map progress ─────────────────────────────────────────────────────────
@DataClassName('UserNodeProgressEntry')
class UserNodeProgress extends Table {
  TextColumn get nodeId => text()();
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get governmentId => text()();
  TextColumn get status => text().withDefault(const Constant('locked'))();
  IntColumn get unlockedAt => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {nodeId};
}

// ── App meta (key-value store) ────────────────────────────────────────────────
// Holds streak/XP counters, settings, seed flags, onboarding state, and the
// pending-session snapshot. Was named `sync_meta` until schema v8 (a leftover
// from the cut sync design); the v8 migration renames the SQL table in place
// so every row survives.
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Politician bios (Wikipedia summary cache) ────────────────────────────────
// One row per cardId. Populated by WikipediaBioService at first launch (or
// on-demand when the user opens a politician detail screen). Never queried
// during a session — pure read-on-detail-screen.
@DataClassName('PoliticianBio')
class PoliticianBios extends Table {
  TextColumn get cardId => text()();
  TextColumn get wikidataQid => text().nullable()();
  TextColumn get wikipediaTitle => text().nullable()();
  TextColumn get wikipediaUrl => text().nullable()();
  TextColumn get bioExtract =>
      text().nullable()(); // lead paragraph from Wikipedia
  IntColumn get fetchedAt =>
      integer().nullable()(); // Unix timestamp, null = never tried
  IntColumn get lastError =>
      integer().nullable()(); // Unix timestamp of last failed attempt
  TextColumn get lastErrorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {cardId};
}

// ── Daily rounds (chapter-aware play history) ────────────────────────────────
// One row per (user, date). Stores everything needed to resume a round
// mid-flight (after backgrounding the app) or read back today's recap.
// JSON columns keep the schema flexible — round content shape will evolve
// across phases without further migrations.
@DataClassName('DailyRoundEntry')
class DailyRounds extends Table {
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get dateIso => text()(); // YYYY-MM-DD
  TextColumn get chapterId => text()();
  IntColumn get dayInChapter => integer()();
  TextColumn get cardIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get triviaJson => text().withDefault(const Constant('[]'))();
  TextColumn get gradesJson => text().withDefault(const Constant('[]'))();
  TextColumn get answersJson => text().withDefault(const Constant('[]'))();
  TextColumn get phase => text().withDefault(const Constant('cards'))();
  IntColumn get startedAt => integer()(); // Unix timestamp
  IntColumn get completedAt => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId, dateIso};
}

// ── Completed runs (cross-mode history log) ──────────────────────────────────
// One row per finished trivia run, daily round, or ended endless session.
// Powers the Memory tab's history view + per-mode review screens. Payload
// is opaque JSON keyed by mode — review screens deserialize on read.
@DataClassName('CompletedRunEntry')
class CompletedRuns extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get mode => text()(); // 'trivia' | 'round' | 'endless'
  IntColumn get completedAt => integer()(); // Unix seconds
  IntColumn get durationMs => integer().nullable()();
  IntColumn get score => integer().nullable()();
  IntColumn get correctCount => integer().nullable()();
  IntColumn get totalCount => integer().nullable()();
  TextColumn get summary => text().nullable()(); // short one-line label
  TextColumn get payload => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Chapter progress (player's position in a season) ─────────────────────────
// One row per (user, season, chapter). Chapters the user hasn't reached yet
// have no row — absent = locked. The "current" chapter is the one with a
// startedAt set AND no completedAt yet (max one per season).
@DataClassName('ChapterProgressEntry')
class ChapterProgress extends Table {
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get seasonId => text()();
  TextColumn get chapterId => text()();
  IntColumn get dayInChapter => integer().withDefault(const Constant(1))();
  IntColumn get roundsCompleted => integer().withDefault(const Constant(0))();
  IntColumn get startedAt => integer()(); // Unix timestamp
  IntColumn get completedAt =>
      integer().nullable()(); // Unix timestamp, null = in progress
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId, seasonId, chapterId};
}

// ── Sync outbox ───────────────────────────────────────────────────────────────
// Server-bound events, queued locally and flushed by SyncEngine when signed
// in. event_id is client-generated so server retries are idempotent; rows are
// deleted on confirmed delivery. Only rows the server can accept are queued
// (session boundaries now; FCLE answers/reviews once that UI ships).
class OutboxEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get type =>
      text()(); // answer | review | session_start | session_end
  TextColumn get questionId => text().nullable()(); // server question UUID
  TextColumn get attemptId => text().nullable()(); // server mock attempt UUID
  TextColumn get chosenKey => text().nullable()();
  TextColumn get grade => text().nullable()(); // again | hard | good | easy
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  IntColumn get clientTs => integer()(); // Unix ms at the moment of action
  IntColumn get tries => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()(); // Unix ms enqueue time

  @override
  Set<Column> get primaryKey => {eventId};
}

// ── FCLE answer log ───────────────────────────────────────────────────────────
// Local record of every FCLE practice/mock answer. Source of truth for the
// readiness indicator and weak-area practice (per-domain rolling accuracy);
// the server event log gets the same answers via the outbox when signed in.
class FcleAnswers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionId => text()(); // YAML slug id
  TextColumn get domain => text()(); // FCLE domain code
  BoolColumn get correct => boolean()();
  BoolColumn get inMock => boolean().withDefault(const Constant(false))();
  IntColumn get answeredAt => integer()(); // Unix ms
}

// ── People (the Atlas reference layer) ────────────────────────────────────────
// Every person page ships complete inside the app: structured facts, full
// career term history, committees, citations. Seeded from bundled
// content/people YAML by checksum; no runtime fetches. JSON columns hold
// the list-shaped data (terms, committees, citations).
@DataClassName('Person')
class People extends Table {
  TextColumn get id => text()(); // bioguide id or slug
  TextColumn get name => text()();
  TextColumn get personType =>
      text().withDefault(const Constant('legislator'))();
  TextColumn get chamber => text().nullable()(); // senate | house
  TextColumn get state => text().nullable()(); // 2-letter code
  IntColumn get district => integer().nullable()(); // house only
  TextColumn get party => text().nullable()();
  TextColumn get birthday => text().nullable()(); // ISO date
  TextColumn get currentRole => text()(); // display line
  TextColumn get termStart => text().nullable()(); // current term ISO
  TextColumn get termEnd => text().nullable()();
  TextColumn get officialUrl => text().nullable()();
  TextColumn get wikidataId => text().nullable()();
  TextColumn get portraitAsset => text().nullable()(); // bundled asset path
  TextColumn get terms => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get committees =>
      text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get citations =>
      text().withDefault(const Constant('[]'))(); // JSON
  // Open-ended enrichment payload (api.congress.gov: sponsored/cosponsored
  // counts, leadership history, honorific, portrait attribution). JSON so
  // future enrichment needs no further migrations.
  TextColumn get extras => text().withDefault(const Constant('{}'))(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database class ────────────────────────────────────────────────────────────
@DriftDatabase(
  tables: [
    GovNodes,
    GovEdges,
    LocalDecks,
    LocalCards,
    CardMemoryStates,
    ReviewLogs,
    UserNodeProgress,
    AppMeta,
    ChapterProgress,
    DailyRounds,
    PoliticianBios,
    CompletedRuns,
    OutboxEvents,
    FcleAnswers,
    People,
  ],
  daos: [
    CardsDao,
    ReviewsDao,
    DecksDao,
    GovernmentDao,
    ProgressDao,
    MetaDao,
    ChapterProgressDao,
    DailyRoundsDao,
    PoliticianBiosDao,
    CompletedRunsDao,
    OutboxDao,
    FcleAnswersDao,
    PeopleDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor. Inject an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Add migration steps here as schemaVersion increases.
          // User data (FSRS memory state, review logs, streak/XP meta, history)
          // must survive every migration — test against a populated DB.
          if (from < 8) {
            // v8 renamed sync_meta → app_meta (the table was always the app's
            // key-value store — streaks, XP, settings, seed flags — never sync
            // state; the name was a leftover from the cut sync design). Rename
            // FIRST so the steps below can target the table by its current
            // Dart definition even when upgrading from very old versions.
            // ALTER TABLE RENAME preserves every row.
            await customStatement('ALTER TABLE sync_meta RENAME TO app_meta');
          }
          if (from < 2) {
            // v1 → v2: add userId everywhere, plus the practice-mode counter
            // and lastGrade columns on CardMemoryStates for the
            // demonstrated-recall unlock gate. All additive ALTER TABLEs.
            await m.addColumn(cardMemoryStates, cardMemoryStates.userId);
            await m.addColumn(
              cardMemoryStates,
              cardMemoryStates.practiceCountSinceReview,
            );
            await m.addColumn(cardMemoryStates, cardMemoryStates.lastGrade);
            await m.addColumn(reviewLogs, reviewLogs.userId);
            await m.addColumn(userNodeProgress, userNodeProgress.userId);
            await m.addColumn(appMeta, appMeta.userId);
          }
          if (from < 3) {
            // v2 → v3: add ChapterProgress for the chapter-aware daily round.
            // Brand-new table; no data backfill needed (existing users will
            // get a Chapter 1 entry created on first call to currentProgress).
            await m.createTable(chapterProgress);
          }
          if (from < 4) {
            // v3 → v4: add DailyRounds — the chapter-aware round history.
            // Replaces the role of DailyChallengeCaches once Phase 5 cutover
            // lands; for now both tables coexist.
            await m.createTable(dailyRounds);
          }
          if (from < 5) {
            // v4 → v5: add PoliticianBios — Wikipedia summary cache that
            // powers the Atlas politician detail screen. New table; empty
            // until WikipediaBioService backfills.
            await m.createTable(politicianBios);
          }
          if (from < 6) {
            // v5 → v6: add LocalCards.gender (nullable text) — sourced from
            // Wikidata P21 by the portraits fetcher, used to gender-match
            // distractors in trivia and endless modes. NULL falls through to
            // unfiltered behavior, so old rows degrade gracefully until a
            // re-seed populates the column.
            await m.addColumn(localCards, localCards.gender);
          }
          if (from < 7) {
            // v6 → v7: add CompletedRuns — the cross-mode history log that
            // powers the Memory tab's History view and the per-mode review
            // screens. Empty table at first; trivia/round/endless completion
            // paths backfill on every finished run going forward.
            await m.createTable(completedRuns);
          }
          if (from < 8) {
            // v7 → v8: drop the legacy daily-challenge cache, superseded by
            // DailyRounds. The table held each day's card picks plus, for
            // played days, the legacy challenge's result payload. The FSRS
            // reviews made during those challenges live in review_logs /
            // card_memory_states and are untouched; only the removed feature's
            // own rows go. Shipped TestFlight builds may have rows here.
            await customStatement(
              'DROP TABLE IF EXISTS daily_challenge_caches',
            );
          }
          if (from < 9) {
            // v8 → v9: concept-card columns on LocalCards for the lesson layer.
            // All additive with defaults — face cards and user data untouched.
            await m.addColumn(localCards, localCards.cardType);
            await m.addColumn(localCards, localCards.body);
            await m.addColumn(localCards, localCards.recallPrompt);
          }
          if (from < 10) {
            // v9 → v10: sync outbox for the V2 backend. Brand-new table; no
            // user data touched.
            await m.createTable(outboxEvents);
          }
          if (from < 11) {
            // v10 → v11: local FCLE answer log (readiness + weak-area
            // practice). Brand-new table; no user data touched.
            await m.createTable(fcleAnswers);
          }
          if (from < 12) {
            // v11 → v12: the people reference layer (Atlas as IMDb). Content
            // table seeded from bundled YAML; no user data touched.
            await m.createTable(people);
          }
          if (from == 12) {
            // v12 → v13: enrichment payload column on people (congress.gov
            // legislative activity). Additive with default; content-only.
            // Guarded to exactly 12: older versions create the table above
            // with the column already in the current definition.
            await m.addColumn(people, people.extras);
          }
          if (from < 14) {
            // v13 -> v14: per-deck subscription flag + deck category for the
            // delegation deck system. Additive with defaults; existing curated
            // decks stay subscribed so nothing changes for current users.
            await m.addColumn(localDecks, localDecks.isSubscribed);
            await m.addColumn(localDecks, localDecks.category);
          }
        },
      );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'politiface_db');
}
