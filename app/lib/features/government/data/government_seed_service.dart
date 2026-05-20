import 'package:drift/drift.dart';

import '../../../core/database/drift/app_database.dart';
import 'gov_seed_data.dart';

class GovernmentSeedService {
  GovernmentSeedService(this._db);
  final AppDatabase _db;

  static const _flagKey = 'gov_seed_v1_done';

  Future<void> ensureSeeded() async {
    final flag = await _db.metaDao.get(_flagKey);
    if (flag == '1') return;

    await _db.transaction(() async {
      for (final node in usGovNodes) {
        await _db.governmentDao.upsertNode(GovNodesCompanion.insert(
          id: node.id,
          governmentId: usGovernmentId,
          externalId: node.id,
          name: node.name,
          shortName: Value(node.shortName),
          description: Value(node.description),
          nodeType: node.nodeType,
          isHeadOfState: Value(node.isHeadOfState),
          isHeadOfGovt: Value(node.isHeadOfGovt),
          isElected: Value(node.isElected),
          mapX: Value(node.mapX),
          mapY: Value(node.mapY),
          mapWidth: Value(node.mapWidth),
          mapHeight: Value(node.mapHeight),
          mapShape: Value(node.mapShape),
          mapColor: Value(node.mapColor),
          tierOrder: node.tierOrder,
          unlockRequires: Value(_encodeStringList(node.unlockRequires)),
        ));

        await _db.progressDao.upsert(UserNodeProgressCompanion.insert(
          nodeId: node.id,
          governmentId: usGovernmentId,
          status: Value(
            node.unlockRequires.isEmpty ? 'unlocked' : 'locked',
          ),
          unlockedAt: Value(
            node.unlockRequires.isEmpty
                ? DateTime.now().millisecondsSinceEpoch ~/ 1000
                : null,
          ),
        ));
      }

      for (final edge in usGovEdges) {
        await _db.governmentDao.upsertEdge(GovEdgesCompanion.insert(
          id: edge.id,
          governmentId: usGovernmentId,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          relationshipType: edge.relationshipType,
          isVisibleOnMap: Value(edge.isVisibleOnMap),
          lineStyle: Value(edge.lineStyle),
          lineColor: Value(edge.lineColor),
        ));
      }

      // Backfill the seed_v1 deck's nodeId for DBs created before this phase.
      await _db.decksDao.setDeckNodeId(
        deckId: 'deck_us_exec_v1',
        nodeId: 'us-node-president',
      );

      await _db.metaDao.set(_flagKey, '1');
    });
  }

  static String _encodeStringList(List<String> items) {
    if (items.isEmpty) return '[]';
    final escaped = items.map((s) => '"$s"').join(',');
    return '[$escaped]';
  }
}
