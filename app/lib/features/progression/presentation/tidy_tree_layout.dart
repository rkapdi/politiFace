import 'dart:ui';

/// One node in the input tree for [TidyTreeLayout]. Mutable so the layout
/// pass can attach `children`; the rest is plain data.
class TidyTreeNode {
  TidyTreeNode({required this.id, this.parentId});
  final String id;
  final String? parentId;
  final List<TidyTreeNode> children = [];
}

/// Horizontal tidy-tree layout: root on the left, children flowing rightward
/// in columns, siblings stacked vertically.
///
/// The algorithm is a stripped-down Reingold-Tilford: a post-order pass
/// stacks leaves on incrementing y rows, then each parent is positioned at
/// the vertical midpoint of its children. Good enough for our tree shape
/// (≤4 levels deep, separate branches that don't share children). If
/// content grows into a topology where branches overlap, swap in a full
/// Buchheim-Walker — the call sites won't change.
class TidyTreeLayout {
  /// Default vertical row size (label + breathing room).
  static const double defaultRowHeight = 36;

  /// Default column-to-column horizontal spacing.
  static const double defaultColumnSpacing = 200;

  /// Compute (x, y) for every node in the tree.
  ///
  /// Returns a Map keyed by node id. The result rect's top-left is (0, 0);
  /// the caller is expected to add their own padding when rendering.
  static LayoutResult layout(
    TidyTreeNode root, {
    double rowHeight = defaultRowHeight,
    double columnSpacing = defaultColumnSpacing,
  }) {
    final positions = <String, Offset>{};
    final depths = <String, int>{};
    var nextLeafRow = 0.0;
    var maxDepth = 0;

    void place(TidyTreeNode n, int depth) {
      depths[n.id] = depth;
      if (depth > maxDepth) maxDepth = depth;
      if (n.children.isEmpty) {
        positions[n.id] =
            Offset(depth * columnSpacing, nextLeafRow * rowHeight);
        nextLeafRow += 1;
        return;
      }
      for (final child in n.children) {
        place(child, depth + 1);
      }
      final firstY = positions[n.children.first.id]!.dy;
      final lastY = positions[n.children.last.id]!.dy;
      positions[n.id] =
          Offset(depth * columnSpacing, (firstY + lastY) / 2);
    }

    place(root, 0);

    // Compute bounds for the caller (so InteractiveViewer can pick a sensible
    // initial scale or center).
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final p in positions.values) {
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final width = (maxDepth + 1) * columnSpacing;
    final height = (maxY - minY) + rowHeight;

    return LayoutResult(
      positions: positions,
      depths: depths,
      size: Size(width, height),
      maxDepth: maxDepth,
    );
  }
}

class LayoutResult {
  const LayoutResult({
    required this.positions,
    required this.depths,
    required this.size,
    required this.maxDepth,
  });

  /// Node id → top-left offset (before any padding).
  final Map<String, Offset> positions;

  /// Node id → depth from root (0 = root).
  final Map<String, int> depths;

  /// Overall bounding box of the laid-out tree.
  final Size size;

  /// Deepest level present in the tree (root = 0).
  final int maxDepth;
}
