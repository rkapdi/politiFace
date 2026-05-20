import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/domain/mastery.dart';

class NodeMastery {
  const NodeMastery({
    required this.totalCards,
    required this.masteredCount,
  });

  /// Number of distinct cards across all decks attached to the node.
  final int totalCards;

  /// Cards whose FSRS stability puts them at mastery level 5.
  final int masteredCount;

  bool get hasContent => totalCards > 0;
  bool get isFullyMastered => totalCards > 0 && masteredCount == totalCards;
}

class GovMapData {
  const GovMapData({
    required this.nodes,
    required this.edges,
    required this.progressByNodeId,
    required this.masteryByNodeId,
  });

  final List<GovNode> nodes;
  final List<GovEdge> edges;
  final Map<String, String> progressByNodeId; // locked | unlocked | in_progress | completed
  final Map<String, NodeMastery> masteryByNodeId;

  bool isUnlocked(String nodeId) {
    final status = progressByNodeId[nodeId];
    return status != null && status != 'locked';
  }

  NodeMastery? masteryFor(String nodeId) => masteryByNodeId[nodeId];
}

/// Build a NodeMastery summary per node. O(decks + cards) per node — fine
/// for V1 sizes (9 nodes × ~5 cards). Optimize later if it shows in profiles.
Future<Map<String, NodeMastery>> _loadMastery(
  AppDatabase db,
  List<GovNode> nodes,
) async {
  final result = <String, NodeMastery>{};
  for (final node in nodes) {
    final decks = await db.decksDao.decksByNodeId(node.id);
    if (decks.isEmpty) continue;
    var total = 0;
    var mastered = 0;
    for (final deck in decks) {
      final cards = await db.cardsDao.cardsByDeckId(deck.id);
      for (final card in cards) {
        total++;
        final state = await db.reviewsDao.stateFor(card.id);
        if (state == null || state.isNew) continue;
        final level = masteryLevelFromStability(
          isNewCard: false,
          stability: state.stability,
        );
        if (level == 5) mastered++;
      }
    }
    if (total > 0) {
      result[node.id] = NodeMastery(totalCards: total, masteredCount: mastered);
    }
  }
  return result;
}

final govMapDataProvider = FutureProvider<GovMapData>((ref) async {
  // Refetch after every grade so the mastery rollup stays current.
  ref.watch(sessionTickProvider);

  final db = ref.watch(databaseProvider);
  final nodes = await db.governmentDao.nodes();
  final edges = await db.governmentDao.edges();
  final progressList = await db.progressDao.all();
  final progressByNodeId = {
    for (final p in progressList) p.nodeId: p.status,
  };
  final masteryByNodeId = await _loadMastery(db, nodes);

  return GovMapData(
    nodes: nodes,
    edges: edges,
    progressByNodeId: progressByNodeId,
    masteryByNodeId: masteryByNodeId,
  );
});
