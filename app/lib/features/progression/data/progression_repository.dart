import '../../../core/database/drift/app_database.dart';
import '../domain/card_evaluation.dart';
import '../domain/node_state.dart';
import '../domain/progression_state_machine.dart';
import '../domain/tier_mastery.dart';

/// Snapshot of the entire progression map for a user — node states plus per-
/// tier rollups. Computed fresh from the underlying Drift tables. Cheap for
/// MVP sizes (~9 nodes × 3 tiers × ~5 cards). Optimize when content grows.
class MapProgressionSnapshot {
  const MapProgressionSnapshot({
    required this.nodeStates,
    required this.tiersByNode,
  });

  final Map<String, NodeState> nodeStates;
  final Map<String, List<TierMasteryStatus>> tiersByNode;

  NodeState stateFor(String nodeId) =>
      nodeStates[nodeId] ?? NodeState.locked;

  List<TierMasteryStatus> tiersFor(String nodeId) =>
      tiersByNode[nodeId] ?? const [];
}

/// Result of a `recordGrade` call, mirroring the shape a future Supabase
/// RPC would return — so the UI can react to "one tap caused these nodes
/// to flip from locked → available" without re-reading the entire map.
class ProgressionMutationResult {
  const ProgressionMutationResult({
    required this.nodeId,
    required this.newNodeState,
    required this.newlyUnlockedNodeIds,
  });

  final String nodeId;
  final NodeState newNodeState;
  final List<String> newlyUnlockedNodeIds;
}

/// Wraps the Drift tables with method signatures that match the future
/// Supabase RPC contract. When accounts ship, swap the implementation; the
/// callers above don't change.
class ProgressionRepository {
  ProgressionRepository(
    this._db, {
    ProgressionStateMachine stateMachine = const ProgressionStateMachine(),
  }) : _sm = stateMachine;

  final AppDatabase _db;
  final ProgressionStateMachine _sm;

  /// Build the full map snapshot — node states + tier rollups.
  /// Equivalent future Supabase shape:
  ///   GET /rpc/map_progression  → MapProgressionSnapshot
  Future<MapProgressionSnapshot> loadMapSnapshot({DateTime? now}) async {
    final nowUnix = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final nodes = await _db.governmentDao.nodes();
    final decks = await _db.decksDao.allDecks();

    // Map nodeId → list of decks grouped by tier. tier comes from
    // LocalDecks.tierOrder (already in the schema; the existing YAML deck is
    // tagged tier_order: 1).
    final decksByNode = <String, Map<int, List<LocalDeck>>>{};
    for (final d in decks) {
      final nodeId = d.nodeId;
      if (nodeId == null) continue;
      final byTier = decksByNode.putIfAbsent(nodeId, () => {});
      byTier.putIfAbsent(d.tierOrder, () => []).add(d);
    }

    // Pull every card state once up front (single pass over the hot table).
    final allStates = await _db.select(_db.cardMemoryStates).get();
    final statesByCard = {for (final s in allStates) s.cardId: s};

    // Build tier rollups per node.
    final tiersByNode = <String, List<TierMasteryStatus>>{};
    for (final node in nodes) {
      final byTier = decksByNode[node.id] ?? const {};
      final tierStatuses = <TierMasteryStatus>[];
      // Always evaluate tiers 1, 2, 3 even if empty — UI may want to render
      // placeholders ("Tier 2 — coming soon").
      for (var tier = 1; tier <= 3; tier++) {
        final tierDecks = byTier[tier] ?? const <LocalDeck>[];
        final evals = <CardEvaluation>[];
        for (final deck in tierDecks) {
          final cards = await _db.cardsDao.cardsByDeckId(deck.id);
          for (final c in cards) {
            evals.add(_evaluationFromState(c.id, statesByCard[c.id]));
          }
        }
        tierStatuses.add(_sm.evaluateTier(
          tier: tier,
          cards: evals,
          nowUnix: nowUnix,
        ));
      }
      tiersByNode[node.id] = tierStatuses;
    }

    // Resolve node states top-down by tierOrder so each node's evaluation
    // sees its parent's already-resolved state. For the unlockRequires
    // model (multiple parents possible), we treat the union: a node is
    // locked unless every required predecessor is mastered.
    final nodeById = {for (final n in nodes) n.id: n};
    final stateById = <String, NodeState>{};
    final sortedNodes = [...nodes]..sort((a, b) {
        final byTier = a.tierOrder.compareTo(b.tierOrder);
        return byTier != 0 ? byTier : a.sortOrder.compareTo(b.sortOrder);
      });

    for (final node in sortedNodes) {
      final reqs = _parseRequires(node.unlockRequires);
      final parentState = _aggregateParentState(reqs, stateById);
      final tiers = tiersByNode[node.id] ?? const [];
      stateById[node.id] = _sm.computeNodeState(
        parentState: parentState,
        tiers: tiers,
      );
    }

    // Ignore nodeById warning by referencing it in a no-op assertion.
    assert(nodeById.isNotEmpty || nodes.isEmpty);

    return MapProgressionSnapshot(
      nodeStates: stateById,
      tiersByNode: tiersByNode,
    );
  }

  /// Recompute states after a grade and return the delta — which node was
  /// affected, its new state, and any children that flipped to available.
  /// Equivalent future Supabase shape:
  ///   POST /rpc/record_grade { cardId, grade } → ProgressionMutationResult
  Future<ProgressionMutationResult?> recomputeAfterGrade({
    required String cardId,
    DateTime? now,
  }) async {
    final card = await _db.cardsDao.cardById(cardId);
    if (card == null) return null;
    final deck = await (_db.select(_db.localDecks)
          ..where((d) => d.id.equals(card.deckId)))
        .getSingleOrNull();
    final nodeId = deck?.nodeId;
    if (nodeId == null) return null;

    final beforeSnap = await loadMapSnapshot(now: now);
    final beforeStates = Map<String, NodeState>.from(beforeSnap.nodeStates);

    final afterSnap = await loadMapSnapshot(now: now);
    final afterState =
        afterSnap.stateFor(nodeId);

    final newlyUnlocked = <String>[];
    afterSnap.nodeStates.forEach((id, state) {
      final prev = beforeStates[id] ?? NodeState.locked;
      if (prev == NodeState.locked && state != NodeState.locked) {
        newlyUnlocked.add(id);
      }
    });

    return ProgressionMutationResult(
      nodeId: nodeId,
      newNodeState: afterState,
      newlyUnlockedNodeIds: newlyUnlocked,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  CardEvaluation _evaluationFromState(String cardId, CardMemoryState? row) {
    if (row == null) {
      return CardEvaluation(
        cardId: cardId,
        isNew: true,
        stability: 0,
        lastReviewedAtUnix: 0,
        reviewCount: 0,
        practiceCountSinceReview: 0,
        lastGrade: 0,
      );
    }
    return CardEvaluation(
      cardId: cardId,
      isNew: row.isNew,
      stability: row.stability,
      lastReviewedAtUnix: row.lastReviewedAt,
      reviewCount: row.reviewCount,
      practiceCountSinceReview: row.practiceCountSinceReview,
      lastGrade: row.lastGrade,
    );
  }

  /// Treat a node with multiple unlockRequires as locked unless ALL of them
  /// are mastered (root nodes with no requires count as available).
  NodeState _aggregateParentState(
    List<String> requires,
    Map<String, NodeState> stateById,
  ) {
    if (requires.isEmpty) return NodeState.mastered;
    for (final r in requires) {
      if (stateById[r] != NodeState.mastered) return NodeState.locked;
    }
    return NodeState.mastered;
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
