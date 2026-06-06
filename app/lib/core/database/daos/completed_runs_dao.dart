import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'completed_runs_dao.g.dart';

/// CRUD over [CompletedRuns]. Insert on every finished trivia / daily round
/// / endless run; query for the Memory tab's History view + per-mode
/// review screens.
@DriftAccessor(tables: [CompletedRuns])
class CompletedRunsDao extends DatabaseAccessor<AppDatabase>
    with _$CompletedRunsDaoMixin {
  CompletedRunsDao(AppDatabase db) : super(db);

  Future<void> insert(CompletedRunsCompanion entry) {
    return into(completedRuns).insertOnConflictUpdate(entry);
  }

  Future<CompletedRunEntry?> byId(String id) {
    return (select(completedRuns)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Most recent first. Filter by mode if provided.
  Future<List<CompletedRunEntry>> recent({
    String userId = 'local-user',
    String? mode,
    int limit = 100,
  }) {
    final q = select(completedRuns)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
      ..limit(limit);
    if (mode != null) {
      q.where((t) => t.mode.equals(mode));
    }
    return q.get();
  }

  Future<int> deleteAllForUser(String userId) {
    return (delete(completedRuns)..where((t) => t.userId.equals(userId)))
        .go();
  }
}
