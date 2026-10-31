import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'completed_runs_dao.g.dart';

/// CRUD over [CompletedRuns]. Insert on every finished daily round / endless
/// run; query for the Memory tab's History view + per-mode
/// review screens.
@DriftAccessor(tables: [CompletedRuns])
class CompletedRunsDao extends DatabaseAccessor<AppDatabase>
    with _$CompletedRunsDaoMixin {
  CompletedRunsDao(super.db);

  Future<void> insert(CompletedRunsCompanion entry) =>
      into(completedRuns).insertOnConflictUpdate(entry);

  Future<CompletedRunEntry?> byId(String id) =>
      (select(completedRuns)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Most recent first. Filter by mode if provided. Rows from the removed
  /// trivia mode stay on disk (cleared by account reset) but are never listed.
  Future<List<CompletedRunEntry>> recent({
    String userId = 'local-user',
    String? mode,
    int limit = 100,
  }) {
    final q = select(completedRuns)
      ..where((t) => t.userId.equals(userId) & t.mode.equals('trivia').not())
      ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
      ..limit(limit);
    if (mode != null) {
      q.where((t) => t.mode.equals(mode));
    }
    return q.get();
  }

  Future<int> deleteAllForUser(String userId) =>
      (delete(completedRuns)..where((t) => t.userId.equals(userId))).go();
}
