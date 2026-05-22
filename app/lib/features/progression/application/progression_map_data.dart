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

  Iterable<ProgressionMapNode> get visibleNodes =>
      nodes.values.where((n) {
        final state = snapshot.stateFor(n.id);
        // Real nodes hide when locked. Synthetic nodes always render so the
        // user sees the gov structure even before they've unlocked deep into
        // a branch.
        return n.isSynthetic || state != NodeState.locked;
      });
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
        label: 'Other',
        parentId: kRootId,
        branchColor: branchColorFor('political-party'),
        isSynthetic: true,
      );
    default:
      throw StateError('Unknown synthetic branch: $id');
  }
}

/// Parse the first id out of a JSON-encoded array literal, or null if empty.
String? _firstRequire(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '[]') return null;
  final inner = s.substring(1, s.length - 1);
  for (final part in inner.split(',')) {
    final cleaned = part.trim().replaceAll('"', '');
    if (cleaned.isNotEmpty) return cleaned;
  }
  return null;
}

/// Walks [govNodes] and produces the rendered tree. Each real node hangs
/// under its first unlockRequires parent, or — when it has none — under
/// the synthetic branch grouping that matches its nodeType.
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

  for (final node in govNodes) {
    final firstReq = _firstRequire(node.unlockRequires);
    final parentId = firstReq ?? _branchIdFor(node.nodeType);
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

/// Compose a [TidyTreeNode] graph from the rendered node map. Hides any
/// subtree under a locked node so the layout doesn't reserve space for it.
TidyTreeNode _buildTreeForLayout(
  Map<String, ProgressionMapNode> all,
  MapProgressionSnapshot snapshot,
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
    final children = byParent[n.id] ?? const <ProgressionMapNode>[];
    for (final child in children) {
      // Real nodes hide when locked; the layout pass should skip them
      // entirely so siblings stack tightly. Synthetic branches always show.
      if (!child.isSynthetic &&
          snapshot.stateFor(child.id) == NodeState.locked) {
        continue;
      }
      node.children.add(build(child));
    }
    return node;
  }

  return build(all[kRootId]!);
}

/// Riverpod source of truth for the org-chart map. Refetches whenever
/// sessionTickProvider fires (which the session controller bumps on every
/// grade, so the map mastery state stays live).
final progressionMapDataProvider =
    FutureProvider<ProgressionMapModel>((ref) async {
  ref.watch(sessionTickProvider);

  final db = ref.watch(databaseProvider);
  final repo = ProgressionRepository(db);
  final snapshot = await repo.loadMapSnapshot();

  final govNodes = await db.governmentDao.nodes();
  final nodes = _buildNodeMap(govNodes);
  final layoutTree = _buildTreeForLayout(nodes, snapshot);
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
