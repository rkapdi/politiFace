// lib/core/database/drift/app_database.dart
//
// Local SQLite database via Drift.
// This is the SOURCE OF TRUTH on device.
// Supabase is the sync target, never the hot path.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../daos/cards_dao.dart';
import '../daos/reviews_dao.dart';
import '../daos/decks_dao.dart';
import '../daos/government_dao.dart';
import '../daos/progress_dao.dart';
import '../daos/meta_dao.dart';

part 'app_database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class GovNodes extends Table {
  TextColumn get id            => text()();
  TextColumn get governmentId  => text()();
  TextColumn get externalId    => text().unique()();
  TextColumn get name          => text()();
  TextColumn get shortName     => text().nullable()();
  TextColumn get description   => text().nullable()();
  TextColumn get nodeType      => text()();
  BoolColumn get isHeadOfState => boolean().withDefault(const Constant(false))();
  BoolColumn get isHeadOfGovt  => boolean().withDefault(const Constant(false))();
  BoolColumn get isElected     => boolean().nullable()();
  RealColumn get mapX          => real().nullable()();
  RealColumn get mapY          => real().nullable()();
  RealColumn get mapWidth      => real().nullable()();
  RealColumn get mapHeight     => real().nullable()();
  TextColumn get mapShape      => text().withDefault(const Constant('rectangle'))();
  TextColumn get mapIcon       => text().nullable()();
  TextColumn get mapColor      => text().nullable()();
  TextColumn get mapLabelPos   => text().withDefault(const Constant('bottom'))();
  IntColumn  get tierOrder     => integer()();
  TextColumn get unlockRequires => text().withDefault(const Constant('[]'))(); // JSON array
  BoolColumn get isActive      => boolean().withDefault(const Constant(true))();
  IntColumn  get sortOrder     => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class GovEdges extends Table {
  TextColumn get id               => text()();
  TextColumn get governmentId     => text()();
  TextColumn get fromNodeId       => text()();
  TextColumn get toNodeId         => text()();
  TextColumn get relationshipType => text()();
  TextColumn get description      => text().nullable()();
  BoolColumn get isVisibleOnMap   => boolean().withDefault(const Constant(true))();
  TextColumn get lineStyle        => text().withDefault(const Constant('solid'))();
  TextColumn get lineColor        => text().nullable()();
  TextColumn get arrowDirection   => text().withDefault(const Constant('to'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalDecks extends Table {
  TextColumn get id           => text()();
  TextColumn get nodeId       => text().nullable()();
  TextColumn get governmentId => text().nullable()();
  TextColumn get externalId   => text().unique()();
  TextColumn get name         => text()();
  TextColumn get description  => text().nullable()();
  IntColumn  get tierOrder    => integer().withDefault(const Constant(0))();
  BoolColumn get isPremium    => boolean().withDefault(const Constant(false))();
  TextColumn get status       => text().withDefault(const Constant('published'))();
  IntColumn  get cardCount    => integer().withDefault(const Constant(0))();
  IntColumn  get updatedAt    => integer()(); // Unix timestamp for watermark sync

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCards extends Table {
  TextColumn get id              => text()();
  TextColumn get deckId          => text()();
  TextColumn get externalId      => text().unique()();
  TextColumn get politicianName  => text()();
  TextColumn get photoUrl        => text().nullable()();
  TextColumn get lqipBase64      => text().nullable()();
  TextColumn get title           => text()();
  TextColumn get party           => text().nullable()();
  TextColumn get jurisdiction    => text().nullable()();
  TextColumn get oneLiner        => text().nullable()();
  TextColumn get sourceUrl       => text()();
  TextColumn get tags            => text().withDefault(const Constant('[]'))(); // JSON array
  BoolColumn get isActive        => boolean().withDefault(const Constant(true))();
  IntColumn  get sortOrder       => integer().withDefault(const Constant(0))();
  IntColumn  get updatedAt       => integer()(); // Unix timestamp

  @override
  Set<Column> get primaryKey => {id};
}

// ── FSRS Memory State (hot table — O(cards seen) rows) ──────────────────────
// Split from review log for performance.
// FSRS only needs current state to compute next review.
class CardMemoryStates extends Table {
  TextColumn get cardId          => text()();           // PRIMARY KEY
  // userId is 'local-user' for the no-account MVP. When Supabase auth ships,
  // backfill with auth.uid() and the rest of the schema is unchanged.
  TextColumn get userId          => text().withDefault(const Constant('local-user'))();
  RealColumn get difficulty      => real().withDefault(const Constant(5.0))();   // FSRS D: 1-10
  RealColumn get stability       => real().withDefault(const Constant(1.0))();   // FSRS S: days to 90% retention
  RealColumn get retrievability  => real().withDefault(const Constant(1.0))();   // FSRS R: current recall probability
  IntColumn  get lastReviewedAt  => integer().withDefault(const Constant(0))();  // Unix timestamp
  IntColumn  get nextReviewAt    => integer().withDefault(const Constant(0))();  // Unix timestamp — INDEXED
  IntColumn  get intervalDays    => integer().withDefault(const Constant(1))();
  IntColumn  get lapses          => integer().withDefault(const Constant(0))();
  IntColumn  get reviewCount     => integer().withDefault(const Constant(0))();
  BoolColumn get isNew           => boolean().withDefault(const Constant(true))();
  // Practice-mode counter: increments on every same-day re-grade that doesn't
  // touch FSRS state (see CardReviewRepository.recordGrade). Resets to 0 when
  // a real FSRS review fires. Drives the demonstrated-recall unlock gate.
  IntColumn  get practiceCountSinceReview =>
      integer().withDefault(const Constant(0))();
  // Last grade observed (0..3), set on EVERY grade including practice mode.
  // Used by the unlock gate (must be >= Good to count toward tier mastery).
  IntColumn  get lastGrade       => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {cardId};
}

// ── Review log (append-only — not queried during sessions) ───────────────────
class ReviewLogs extends Table {
  IntColumn  get id             => integer().autoIncrement()();
  TextColumn get userId         => text().withDefault(const Constant('local-user'))();
  TextColumn get cardId         => text()();
  IntColumn  get reviewedAt     => integer()();   // Unix timestamp
  IntColumn  get grade          => integer()();   // 0=again, 1=hard, 2=good, 3=easy
  RealColumn get stability      => real()();      // FSRS state AFTER this review
  RealColumn get difficulty     => real()();
  RealColumn get retrievability => real()();
  IntColumn  get intervalDays   => integer()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
}

// ── User map progress ─────────────────────────────────────────────────────────
@DataClassName('UserNodeProgressEntry')
class UserNodeProgress extends Table {
  TextColumn get nodeId       => text()();
  TextColumn get userId       => text().withDefault(const Constant('local-user'))();
  TextColumn get governmentId => text()();
  TextColumn get status       => text().withDefault(const Constant('locked'))();
  IntColumn  get unlockedAt   => integer().nullable()();
  IntColumn  get completedAt  => integer().nullable()();

  @override
  Set<Column> get primaryKey => {nodeId};
}

// ── Daily challenge cache ─────────────────────────────────────────────────────
class DailyChallengeCaches extends Table {
  TextColumn get challengeDate => text()();  // YYYY-MM-DD — PRIMARY KEY
  TextColumn get cardIds       => text()();  // JSON array of card IDs
  TextColumn get shareTemplate => text().nullable()();
  IntColumn  get cachedAt      => integer()();

  @override
  Set<Column> get primaryKey => {challengeDate};
}

// ── Sync metadata ─────────────────────────────────────────────────────────────
class SyncMeta extends Table {
  TextColumn get key    => text()();
  TextColumn get userId => text().withDefault(const Constant('local-user'))();
  TextColumn get value  => text()();

  @override
  Set<Column> get primaryKey => {key};
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
    DailyChallengeCaches,
    SyncMeta,
  ],
  daos: [
    CardsDao,
    ReviewsDao,
    DecksDao,
    GovernmentDao,
    ProgressDao,
    MetaDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor. Inject an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add migration steps here as schemaVersion increases.
      // Never drop tables. Use ALTER TABLE ADD COLUMN for additions.
      // Test every migration against a populated DB before shipping.
      if (from < 2) {
        // v1 → v2: add userId everywhere (future Supabase swap = one
        // find/replace), plus the practice-mode counter and lastGrade
        // columns on CardMemoryStates for the demonstrated-recall unlock
        // gate. All additive ALTER TABLEs — no data loss.
        await m.addColumn(cardMemoryStates, cardMemoryStates.userId);
        await m.addColumn(
            cardMemoryStates, cardMemoryStates.practiceCountSinceReview);
        await m.addColumn(cardMemoryStates, cardMemoryStates.lastGrade);
        await m.addColumn(reviewLogs, reviewLogs.userId);
        await m.addColumn(userNodeProgress, userNodeProgress.userId);
        await m.addColumn(syncMeta, syncMeta.userId);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'politiface_db');
  }
}
