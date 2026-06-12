import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/domain/mastery.dart';

/// One branch worth of Atlas content — the org-chart's top level, flattened
/// for a vertical scroll. Order is hardcoded (Legislative → Executive →
/// Judicial → State and Local) to match the canonical civics ordering the
/// rest of the app uses.
class AtlasBranch {
  const AtlasBranch({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.cards,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color color;

  /// Cards belonging to this branch, in deck → sort_order order.
  final List<AtlasCardData> cards;

  int get masteredCount =>
      cards.where((c) => c.masteryFraction >= 0.8).length;
}

class AtlasCardData {
  const AtlasCardData({
    required this.cardId,
    required this.nodeId,
    required this.name,
    required this.title,
    required this.photoUrl,
    required this.lqipBase64,
    required this.masteryFraction,
    required this.isLocked,
  });

  final String cardId;

  /// The map node this card belongs to — needed so tapping the card can
  /// open the existing NodeDetailScreen.
  final String? nodeId;
  final String name;
  final String title;
  final String? photoUrl;
  final String? lqipBase64;

  /// 0..1 — same curve as the in-app mastery rings on individual reviews.
  final double masteryFraction;
  final bool isLocked;
}

/// What [AtlasScreen] renders.
class AtlasView {
  const AtlasView({required this.branches});

  final List<AtlasBranch> branches;

  int get totalCards =>
      branches.fold(0, (sum, b) => sum + b.cards.length);
  int get masteredCards =>
      branches.fold(0, (sum, b) => sum + b.masteredCount);
}

// ── Branch grouping rules ──────────────────────────────────────────────────
// govNode.nodeType → which atlas branch the card lives under.

const String _branchLegislative = 'atlas-legislative';
const String _branchExecutive = 'atlas-executive';
const String _branchJudicial = 'atlas-judicial';
const String _branchStateLocal = 'atlas-state-local';

String? _branchIdForNodeType(String nodeType) {
  switch (nodeType) {
    case 'legislature':
      return _branchLegislative;
    case 'executive':
      return _branchExecutive;
    case 'judicial':
      return _branchJudicial;
    case 'political-party':
      return _branchStateLocal;
    default:
      return null; // unknown nodeType → omit from Atlas (root, etc.)
  }
}

AtlasBranch _emptyBranch(String id) {
  switch (id) {
    case _branchLegislative:
      return const AtlasBranch(
        id: _branchLegislative,
        title: 'Legislative',
        subtitle: 'Who writes the laws.',
        color: EditorialPalette.civicNavy,
        cards: [],
      );
    case _branchExecutive:
      return const AtlasBranch(
        id: _branchExecutive,
        title: 'Executive',
        subtitle: 'Who runs the country.',
        color: EditorialPalette.actionRed,
        cards: [],
      );
    case _branchJudicial:
      return const AtlasBranch(
        id: _branchJudicial,
        title: 'Judicial',
        subtitle: 'Who interprets the laws.',
        color: EditorialPalette.civicGreen,
        cards: [],
      );
    case _branchStateLocal:
      return const AtlasBranch(
        id: _branchStateLocal,
        title: 'State and Local',
        subtitle: 'Parties, states, and everything outside DC.',
        color: EditorialPalette.ochre,
        cards: [],
      );
  }
  throw ArgumentError('Unknown branch id: $id');
}

/// Branch ids that highlight when the chapter's curriculum branch id maps
/// to them. The curriculum's branch ids (`legislative`, `executive`, etc.)
/// are similar but not identical to the Atlas's grouping ids, so we
/// translate here.
const Map<String, String> curriculumBranchToAtlasBranch = {
  'legislative': _branchLegislative,
  'executive': _branchExecutive,
  'judicial': _branchJudicial,
  'state-local': _branchStateLocal,
  // 'foundations' has no face cards yet — skipped intentionally. Once
  // concept cards exist a fifth branch can join the Atlas.
};

/// One ordered list rendered top-to-bottom.
const List<String> atlasBranchOrder = [
  _branchLegislative,
  _branchExecutive,
  _branchJudicial,
  _branchStateLocal,
];

/// Derived provider for the Atlas screen. Aggregates cards + decks +
/// gov nodes + memory state + node progress in one shot; cheap enough
/// that re-querying on every [sessionTickProvider] bump is fine
/// (the dataset is bounded by total cards, not by user history).
final atlasViewProvider = FutureProvider<AtlasView>((ref) async {
  ref.watch(sessionTickProvider);
  final db = ref.watch(databaseProvider);

  // Pull every input in parallel.
  final results = await Future.wait<dynamic>([
    db.cardsDao.allActiveCards(),
    db.decksDao.allDecks(),
    db.governmentDao.nodes(),
    db.select(db.cardMemoryStates).get(),
    db.progressDao.all(),
  ]);
  final cards = results[0] as List<LocalCard>;
  final decks = results[1] as List<LocalDeck>;
  final nodes = results[2] as List<GovNode>;
  final memoryStates = results[3] as List<CardMemoryState>;
  final nodeProgress = results[4] as List<UserNodeProgressEntry>;

  final deckById = {for (final d in decks) d.id: d};
  final nodeById = {for (final n in nodes) n.id: n};
  final memoryByCardId = {for (final m in memoryStates) m.cardId: m};
  final progressByNodeId = {for (final p in nodeProgress) p.nodeId: p};

  // Sort cards by deck tierOrder, then by sortOrder within the deck — same
  // order the existing decks render in.
  final sortedCards = [...cards]..sort((a, b) {
      final deckA = deckById[a.deckId];
      final deckB = deckById[b.deckId];
      final tierCmp = (deckA?.tierOrder ?? 0).compareTo(deckB?.tierOrder ?? 0);
      if (tierCmp != 0) return tierCmp;
      return a.sortOrder.compareTo(b.sortOrder);
    });

  // Group cards into branches via deck.nodeId → govNode.nodeType.
  final cardsByBranch = <String, List<AtlasCardData>>{
    for (final id in atlasBranchOrder) id: [],
  };
  for (final card in sortedCards) {
    final deck = deckById[card.deckId];
    final nodeId = deck?.nodeId;
    final node = nodeId != null ? nodeById[nodeId] : null;
    if (node == null) continue;
    final branchId = _branchIdForNodeType(node.nodeType);
    if (branchId == null) continue;

    final mem = memoryByCardId[card.id];
    final fraction = mem == null
        ? 0.0
        : cardMasteryFraction(
            isNewCard: mem.isNew,
            stability: mem.stability,
            reviewCount: mem.reviewCount,
          );

    final nodeStatus = progressByNodeId[nodeId]?.status;
    final isLocked = nodeStatus == 'locked' || nodeStatus == null;

    cardsByBranch[branchId]!.add(AtlasCardData(
      cardId: card.id,
      nodeId: nodeId,
      name: card.politicianName,
      title: card.title,
      photoUrl: card.photoUrl,
      lqipBase64: card.lqipBase64,
      masteryFraction: fraction,
      isLocked: isLocked,
    ),);
  }

  final branches = [
    for (final id in atlasBranchOrder)
      _emptyBranch(id).let((b) => AtlasBranch(
            id: b.id,
            title: b.title,
            subtitle: b.subtitle,
            color: b.color,
            cards: cardsByBranch[id] ?? const [],
          ),),
  ];

  return AtlasView(branches: branches);
});

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
