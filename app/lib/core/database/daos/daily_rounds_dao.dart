import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'daily_rounds_dao.g.dart';

/// CRUD over [DailyRounds]. Business logic (sampling, phase advancement,
/// JSON shape) lives in `DailyRoundController` — this DAO just talks to
/// the table.
@DriftAccessor(tables: [DailyRounds])
class DailyRoundsDao extends DatabaseAccessor<AppDatabase>
    with _$DailyRoundsDaoMixin {
  DailyRoundsDao(AppDatabase db) : super(db);

  Future<DailyRoundEntry?> get({
    required String userId,
    required String dateIso,
  }) {
    return (select(dailyRounds)
          ..where((t) =>
              t.userId.equals(userId) & t.dateIso.equals(dateIso)))
        .getSingleOrNull();
  }

  Future<List<DailyRoundEntry>> recent({
    required String userId,
    int limit = 30,
  }) {
    return (select(dailyRounds)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.dateIso)])
          ..limit(limit))
        .get();
  }

  Future<void> upsert(DailyRoundsCompanion entry) {
    return into(dailyRounds).insertOnConflictUpdate(entry);
  }

  /// Test/debug helper: wipe all rounds for a user. Not used in app code.
  Future<int> deleteAllForUser(String userId) {
    return (delete(dailyRounds)..where((t) => t.userId.equals(userId)))
        .go();
  }
}
