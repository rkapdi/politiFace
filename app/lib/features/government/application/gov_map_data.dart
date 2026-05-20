import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';

class GovMapData {
  const GovMapData({
    required this.nodes,
    required this.edges,
    required this.progressByNodeId,
  });

  final List<GovNode> nodes;
  final List<GovEdge> edges;
  final Map<String, String> progressByNodeId; // 'locked' | 'unlocked' | 'in_progress' | 'completed'

  bool isUnlocked(String nodeId) {
    final status = progressByNodeId[nodeId];
    return status != null && status != 'locked';
  }
}

final govMapDataProvider = FutureProvider<GovMapData>((ref) async {
  final db = ref.watch(databaseProvider);
  final nodes = await db.governmentDao.nodes();
  final edges = await db.governmentDao.edges();
  final progressList = await db.progressDao.all();
  final progressByNodeId = {
    for (final p in progressList) p.nodeId: p.status,
  };
  return GovMapData(
    nodes: nodes,
    edges: edges,
    progressByNodeId: progressByNodeId,
  );
});
