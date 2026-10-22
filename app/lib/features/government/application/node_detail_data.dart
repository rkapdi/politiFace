import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';

class NodeDetail {
  const NodeDetail({
    required this.node,
    required this.decks,
    required this.status,
  });

  final GovNode node;
  final List<LocalDeck> decks;
  final String status; // 'locked' | 'unlocked' | 'in_progress' | 'completed'

  bool get isUnlocked => status != 'locked';
}

final nodeDetailProvider =
    FutureProvider.family<NodeDetail?, String>((ref, nodeId) async {
  final db = ref.watch(databaseProvider);
  final nodes = await db.governmentDao.nodes();
  final node = nodes.where((n) => n.id == nodeId).firstOrNull;
  if (node == null) return null;
  final decks = await db.decksDao.decksByNodeId(nodeId);
  final progress = await db.progressDao.forNode(nodeId);
  return NodeDetail(
    node: node,
    decks: decks,
    status: progress?.status ?? 'locked',
  );
});
