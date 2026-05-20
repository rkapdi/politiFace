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
}
