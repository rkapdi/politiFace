import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'government_dao.g.dart';

@DriftAccessor(tables: [GovNodes, GovEdges])
class GovernmentDao extends DatabaseAccessor<AppDatabase> with _$GovernmentDaoMixin {
  GovernmentDao(AppDatabase db) : super(db);

  Future<List<GovNode>> nodes() => select(govNodes).get();

  Future<void> upsertNode(GovNodesCompanion node) {
    return into(govNodes).insertOnConflictUpdate(node);
  }

  Future<List<GovEdge>> edges() => select(govEdges).get();

  Future<void> upsertEdge(GovEdgesCompanion edge) {
    return into(govEdges).insertOnConflictUpdate(edge);
  }
}
