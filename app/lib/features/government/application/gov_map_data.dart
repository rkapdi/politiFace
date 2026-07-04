import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/domain/mastery.dart';

class NodeMastery {
  const NodeMastery({
    required this.totalCards,
    required this.masteredCount,
    required this.masteryPoints,
  });

  /// Number of distinct cards across all decks attached to the node.
  final int totalCards;

  /// Cards whose FSRS stability puts them at mastery level 5.
  final int masteredCount;

  /// Sum of per-card progress contributions, each in [0, 1]. Continuous —
  /// every stability change moves it, not just the integer-tier crossings.
  /// See [_perCardMastery] for the curve.
  final double masteryPoints;

  bool get hasContent => totalCards > 0;
  bool get isFullyMastered => totalCards > 0 && masteredCount == totalCards;

  /// 0..1. The "soft" progress signal — moves on every grade, unlike
  /// [masteredCount] which only ticks when a card crosses the ★5 threshold.
  double get masteryFraction {
    if (totalCards == 0) return 0;
    return (masteryPoints / totalCards).clamp(0.0, 1.0);
  }
}

// Per-card mastery curve lives in mastery.dart so the in-card stars and the
// node bar are guaranteed to agree on what counts as progress. See
// cardMasteryFraction.

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
    var masteryPoints = 0.0;
    for (final deck in decks) {
      final cards = await db.cardsDao.cardsByDeckId(deck.id);
      for (final card in cards) {
        total++;
        final state = await db.reviewsDao.stateFor(card.id);
        final isNew = state == null || state.isNew;
        final stability = state?.stability ?? 0.0;
        // Bar's effort signal is real FSRS reviews + same-day practice taps.
        // Same total taps regardless of which path handled them, so the bar
        // moves on every grade even when FSRS state is frozen.
        final effortTaps = (state?.reviewCount ?? 0) +
            (state?.practiceCountSinceReview ?? 0);
        masteryPoints += cardMasteryFraction(
          isNewCard: isNew,
          stability: stability,
          reviewCount: effortTaps,
        );
        // Keep the binary ★5 milestone count for the "N/M" overlay — the
        // bar handles continuous feedback, this still marks the achievement.
        if (!isNew) {
          final tier = masteryLevelFromStability(
            isNewCard: false,
            stability: stability,
          );
          if (tier == 5) mastered++;
        }
      }
    }
    if (total > 0) {
      result[node.id] = NodeMastery(
        totalCards: total,
        masteredCount: mastered,
        masteryPoints: masteryPoints,
      );
    }
  }
  return result;
}

/// Resolve a list of card ids to the set of gov-node ids those cards belong
/// to (via deck membership). Cards whose deck has no nodeId are silently
/// skipped — they're real cards but don't show on the map.
Future<Set<String>> nodeIdsForCardIds(
  AppDatabase db,
  List<String> cardIds,
) async {
  if (cardIds.isEmpty) return const {};
  final cards = await db.cardsDao.cardsByIds(cardIds);
  if (cards.isEmpty) return const {};
  final deckIds = cards.map((c) => c.deckId).toSet().toList();
  final decks = await (db.select(db.localDecks)
        ..where((d) => d.id.isIn(deckIds)))
      .get();
  return decks
      .map((d) => d.nodeId)
      .whereType<String>()
      .toSet();
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
