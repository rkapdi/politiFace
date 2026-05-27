import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../data/progression_repository.dart';
import '../domain/node_state.dart';
import '../domain/tier_mastery.dart';
import '../presentation/tidy_tree_layout.dart';

/// Synthetic root id — every real node hangs off this in the rendered tree.
const String kRootId = '__root__';

/// Synthetic branch-grouping ids. These don't exist in the GovNodes table —
/// they're computed at render time from the nodeType field so the user sees
/// Legislative / Executive / Judicial as visible groups (matching the org-
/// chart reference image) without us needing to author them in the DB.
const String kLegislativeId = '__branch_legislative__';
const String kExecutiveId = '__branch_executive__';
const String kJudicialId = '__branch_judicial__';
const String kOtherBranchId = '__branch_other__';

/// All node metadata + state + layout coordinates needed by [OrgChartMap].
class ProgressionMapModel {
  const ProgressionMapModel({
    required this.nodes,
    required this.layout,
    required this.snapshot,
  });

  /// Every renderable node — real gov nodes + synthetic branch groupers.
  final Map<String, ProgressionMapNode> nodes;
  final LayoutResult layout;
  final MapProgressionSnapshot snapshot;

  /// Every node that has a layout position — the actual filter that drives
  /// rendering. With manual expand/collapse, locked nodes stay visible (just
  /// styled as locked); the layout's collapse-aware filter is what hides
  /// children of a collapsed parent.
  Iterable<ProgressionMapNode> get visibleNodes =>
      nodes.values.where((n) => layout.positions.containsKey(n.id));
}

/// One node in the rendered tree. Wraps the real [GovNode] when present,
/// or is a synthetic branch grouper.
class ProgressionMapNode {
  const ProgressionMapNode({
    required this.id,
    required this.label,
    required this.parentId,
    required this.branchColor,
    required this.isSynthetic,
    this.govNode,
  });

  final String id;
  final String label;
  final String? parentId;
  final Color branchColor;

  /// True for the synthetic root and the synthetic branch groupings —
  /// they don't have decks or progress, and the unlock gate doesn't apply.
  final bool isSynthetic;

  /// The underlying real node, when this isn't synthetic.
  final GovNode? govNode;
}

/// Brand-aware branch palette — lighter than the existing seed colors so
/// markers read well against the dark map background.
Color branchColorFor(String? nodeType) {
  switch (nodeType) {
    case 'executive':
      return const Color(0xFFF59E0B); // amber
    case 'legislature':
      return const Color(0xFF60A5FA); // blue
    case 'judicial':
      return const Color(0xFFC084FC); // purple
    case 'political-party':
      return const Color(0xFF34D399); // green
    default:
      return const Color(0xFF94A3B8); // slate fallback (root, etc.)
  }
}

String _branchIdFor(String nodeType) {
  switch (nodeType) {
    case 'executive':
      return kExecutiveId;
    case 'legislature':
      return kLegislativeId;
    case 'judicial':
      return kJudicialId;
    default:
      return kOtherBranchId;
  }
}

ProgressionMapNode _syntheticBranchNode(String id) {
  switch (id) {
    case kLegislativeId:
      return ProgressionMapNode(
        id: id,
        label: 'Legislative',
        parentId: kRootId,
        branchColor: branchColorFor('legislature'),
        isSynthetic: true,
      );
    case kExecutiveId:
      return ProgressionMapNode(
        id: id,
        label: 'Executive',
        parentId: kRootId,
        branchColor: branchColorFor('executive'),
        isSynthetic: true,
      );
    case kJudicialId:
      return ProgressionMapNode(
        id: id,
        label: 'Judicial',
        parentId: kRootId,
        branchColor: branchColorFor('judicial'),
        isSynthetic: true,
      );
    case kOtherBranchId:
      return ProgressionMapNode(
        id: id,
        label: 'State and Local Governments',
        parentId: kRootId,
        branchColor: branchColorFor('political-party'),
        isSynthetic: true,
      );
    default:
      throw StateError('Unknown synthetic branch: $id');
  }
}

/// Walks [govNodes] and produces the rendered tree.
///
/// Tree parentage and unlock gating are deliberately separate concepts:
///   * Unlock gating uses unlock_requires (state machine, lives in Phase 0)
///   * Tree parentage uses the nodeType-based branch grouping — and only
///     prefers a node from unlock_requires when that node shares the same
///     branch. Otherwise we'd cascade everything under President (since
///     Congress, SCOTUS, etc. all list President as a prereq) and the
///     Legislative / Judicial / State+Local branches would look empty.
Map<String, ProgressionMapNode> _buildNodeMap(List<GovNode> govNodes) {
  final result = <String, ProgressionMapNode>{};

  // Synthetic root + branch groupings (always present, even if a branch is
  // empty — keeps the silhouette consistent across content additions).
  result[kRootId] = const ProgressionMapNode(
    id: kRootId,
    label: 'U.S. Government',
    parentId: null,
    branchColor: Color(0xFF94A3B8),
    isSynthetic: true,
  );
  for (final id in const [
    kLegislativeId,
    kExecutiveId,
    kJudicialId,
    kOtherBranchId,
  ]) {
    result[id] = _syntheticBranchNode(id);
  }

  final byId = {for (final n in govNodes) n.id: n};

  for (final node in govNodes) {
    final reqs = _parseRequires(node.unlockRequires);
    // Walk unlock_requires in order, pick the first prerequisite that
    // belongs to the SAME branch (same nodeType). That keeps Senate under
    // Congress, SCOTUS under the Judicial branch root, etc. — without
    // dragging cross-branch deps (President → Congress) into the topology.
    String parentId = _branchIdFor(node.nodeType);
    for (final reqId in reqs) {
      final reqNode = byId[reqId];
      if (reqNode != null && reqNode.nodeType == node.nodeType) {
        parentId = reqNode.id;
        break;
      }
    }
    result[node.id] = ProgressionMapNode(
      id: node.id,
      label: (node.shortName?.isNotEmpty ?? false) ? node.shortName! : node.name,
      parentId: parentId,
      branchColor: branchColorFor(node.nodeType),
      isSynthetic: false,
      govNode: node,
    );
  }

  return result;
}

List<String> _parseRequires(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '[]') return const [];
  final inner = s.substring(1, s.length - 1);
  return inner
      .split(',')
      .map((p) => p.trim().replaceAll('"', ''))
      .where((p) => p.isNotEmpty)
      .toList();
}

/// Compose a [TidyTreeNode] graph from the rendered node map. Locked
/// children stay visible (rendered as dashed grey by the marker); only
/// nodes whose ancestor is in [collapsedIds] get pruned from the layout.
TidyTreeNode _buildTreeForLayout(
  Map<String, ProgressionMapNode> all,
  Set<String> collapsedIds,
) {
  final byParent = <String?, List<ProgressionMapNode>>{};
  for (final n in all.values) {
    byParent.putIfAbsent(n.parentId, () => []).add(n);
  }
  // Stable ordering: tierOrder, then sortOrder, then id, for real nodes.
  // Synthetic branches get a fixed ordering for visual consistency.
  int branchRank(String id) {
    switch (id) {
      case kLegislativeId:
        return 0;
      case kExecutiveId:
        return 1;
      case kJudicialId:
        return 2;
      case kOtherBranchId:
        return 3;
    }
    return 4;
  }

  for (final list in byParent.values) {
    list.sort((a, b) {
      if (a.isSynthetic && b.isSynthetic) {
        return branchRank(a.id).compareTo(branchRank(b.id));
      }
      if (a.isSynthetic != b.isSynthetic) {
        return a.isSynthetic ? -1 : 1;
      }
      final ag = a.govNode!;
      final bg = b.govNode!;
      final byTier = ag.tierOrder.compareTo(bg.tierOrder);
      if (byTier != 0) return byTier;
      final bySort = ag.sortOrder.compareTo(bg.sortOrder);
      if (bySort != 0) return bySort;
      return ag.id.compareTo(bg.id);
    });
  }

  TidyTreeNode build(ProgressionMapNode n) {
    final node = TidyTreeNode(id: n.id, parentId: n.parentId);
    // When this node is collapsed, its subtree drops out of the layout
    // entirely — children don't get assigned positions and won't render.
    if (collapsedIds.contains(n.id)) return node;
    final children = byParent[n.id] ?? const <ProgressionMapNode>[];
    for (final child in children) {
      node.children.add(build(child));
    }
    return node;
  }

  return build(all[kRootId]!);
}

/// Tracks the snapshot of node states from the previous map render.
/// Survives navigation (lives at the ProviderScope level) so that when the
/// user returns to the Learn tab after a session, the map can diff against
/// what it last knew and highlight newly-unlocked nodes. Null on cold start.
final lastKnownNodeStatesProvider =
    StateProvider<Map<String, NodeState>?>((_) => null);

/// Which node ids the user has manually collapsed in the map. Persists
/// across navigation so re-entering the Learn tab remembers your view.
final collapsedNodeIdsProvider =
    StateProvider<Set<String>>((_) => const <String>{});

/// Riverpod source of truth for the org-chart map. Refetches whenever
/// sessionTickProvider fires (the session controller bumps it on every
/// grade) or when the user toggles a node's expand/collapse state.
final progressionMapDataProvider =
    FutureProvider<ProgressionMapModel>((ref) async {
  ref.watch(sessionTickProvider);
  final collapsedIds = ref.watch(collapsedNodeIdsProvider);

  final db = ref.watch(databaseProvider);
  final repo = ProgressionRepository(db);
  final snapshot = await repo.loadMapSnapshot();

  final govNodes = await db.governmentDao.nodes();
  final nodes = _buildNodeMap(govNodes);
  final layoutTree = _buildTreeForLayout(nodes, collapsedIds);
  final layoutResult = TidyTreeLayout.layout(layoutTree);

  return ProgressionMapModel(
    nodes: nodes,
    layout: layoutResult,
    snapshot: snapshot,
  );
});

/// Tier list per node — for the NodeDetailSheet in Phase 2. Exposed as a
/// helper so the sheet doesn't have to rebuild the whole map snapshot.
List<TierMasteryStatus> tiersForNode(
  ProgressionMapModel model,
  String nodeId,
) =>
    model.snapshot.tiersFor(nodeId);
