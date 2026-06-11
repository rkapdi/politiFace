import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [UserNodeProgress])
class ProgressDao extends DatabaseAccessor<AppDatabase> with _$ProgressDaoMixin {
  ProgressDao(AppDatabase db) : super(db);

  Future<UserNodeProgressEntry?> forNode(String nodeId) {
    return (select(userNodeProgress)..where((p) => p.nodeId.equals(nodeId)))
        .getSingleOrNull();
  }

  Future<List<UserNodeProgressEntry>> all() => select(userNodeProgress).get();

  Future<void> upsert(UserNodeProgressCompanion entry) {
    return into(userNodeProgress).insertOnConflictUpdate(entry);
  }

  /// Insert only when no row exists for the node. Content re-seeds use this
  /// so a YAML update can introduce new nodes without ever resetting the
  /// unlock status of nodes the user already has.
  Future<void> insertIfAbsent(UserNodeProgressCompanion entry) {
    return into(userNodeProgress)
        .insert(entry, mode: InsertMode.insertOrIgnore);
  }
}
