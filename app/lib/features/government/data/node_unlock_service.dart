import 'package:drift/drift.dart';

import '../../../core/database/drift/app_database.dart';

/// Recomputes user_node_progress after a session completes.
/// A node is `completed` once every card in every deck under it has reviewCount >= 1.
/// A node is `unlocked` once every id in its unlock_requires[] has been completed.
class NodeUnlockService {
  NodeUnlockService(this._db);
  final AppDatabase _db;

  Future<NodeUnlockResult> recalculate() async {
    final nodes = await _db.governmentDao.nodes();
    if (nodes.isEmpty) return const NodeUnlockResult(unlocked: [], completed: []);

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newlyUnlocked = <String>[];
    final newlyCompleted = <String>[];

    await _db.transaction(() async {
      final progressList = await _db.progressDao.all();
      final progressByNodeId = {
        for (final p in progressList) p.nodeId: p.status,
      };

      // Pass 1 — recompute "completed" status.
      for (final node in nodes) {
        if (progressByNodeId[node.id] == 'completed') continue;
        final decks = await _db.decksDao.decksByNodeId(node.id);
        if (decks.isEmpty) continue;
        final allReviewed = await _allDeckCardsReviewed(decks);
        if (!allReviewed) continue;

        await _db.progressDao.upsert(UserNodeProgressCompanion.insert(
          nodeId: node.id,
          governmentId: node.governmentId,
          status: const Value('completed'),
          completedAt: Value(nowSeconds),
        ),);
        progressByNodeId[node.id] = 'completed';
        newlyCompleted.add(node.id);
      }

      // Pass 2 — recompute "unlocked" for previously-locked nodes whose
      // prerequisites are now satisfied.
      for (final node in nodes) {
        final status = progressByNodeId[node.id];
        if (status != null && status != 'locked') continue;
        final reqs = _parseRequires(node.unlockRequires);
        if (reqs.isEmpty) continue; // tier-1 nodes are already seeded unlocked
        final allMet = reqs.every(
          (id) => progressByNodeId[id] == 'completed',
        );
        if (!allMet) continue;

        await _db.progressDao.upsert(UserNodeProgressCompanion.insert(
          nodeId: node.id,
          governmentId: node.governmentId,
          status: const Value('unlocked'),
          unlockedAt: Value(nowSeconds),
        ),);
        progressByNodeId[node.id] = 'unlocked';
        newlyUnlocked.add(node.id);
      }
    });

    return NodeUnlockResult(unlocked: newlyUnlocked, completed: newlyCompleted);
  }

  Future<bool> _allDeckCardsReviewed(List<LocalDeck> decks) async {
    for (final deck in decks) {
      final cards = await _db.cardsDao.cardsByDeckId(deck.id);
      if (cards.isEmpty) return false;
      for (final c in cards) {
        final state = await _db.reviewsDao.stateFor(c.id);
        if (state == null || state.reviewCount < 1) return false;
      }
    }
    return true;
  }

  static List<String> _parseRequires(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '[]') return const [];
    final inner = s.substring(1, s.length - 1);
    return inner
        .split(',')
        .map((part) => part.trim().replaceAll('"', ''))
        .where((p) => p.isNotEmpty)
        .toList();
  }
}

class NodeUnlockResult {
  const NodeUnlockResult({required this.unlocked, required this.completed});
  final List<String> unlocked;
  final List<String> completed;

  bool get hasChanges => unlocked.isNotEmpty || completed.isNotEmpty;
}
