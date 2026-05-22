import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/state_views.dart';
import '../application/progression_map_data.dart';
import '../domain/node_state.dart';
import '../domain/tier_mastery.dart';
import '../presentation/concept_node_marker.dart';

/// OSINT Framework-style top-down government map. Root anchored on the left,
/// children fanning rightward, siblings stacked vertically. Pinch-zoom + pan
/// via [InteractiveViewer]; one canvas across the whole tab — no Path /
/// System mode toggle.
class OrgChartMap extends ConsumerStatefulWidget {
  const OrgChartMap({super.key, this.onNodeTap});

  /// Called when the user taps a real (non-synthetic) node. Sheet wiring
  /// arrives in Phase 2; for now the host screen can just navigate to the
  /// existing node detail.
  final void Function(String nodeId)? onNodeTap;

  @override
  ConsumerState<OrgChartMap> createState() => _OrgChartMapState();
}

class _OrgChartMapState extends ConsumerState<OrgChartMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // 2-second loop drives the available-state pulse halo.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(progressionMapDataProvider);
    return async.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorView(
        title: 'Failed to load progression map',
        message: '$e',
        onRetry: () => ref.invalidate(progressionMapDataProvider),
      ),
      data: (model) => _MapCanvas(
        model: model,
        pulse: _pulse,
        onNodeTap: widget.onNodeTap,
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.model,
    required this.pulse,
    this.onNodeTap,
  });

  final ProgressionMapModel model;
  final Animation<double> pulse;
  final void Function(String nodeId)? onNodeTap;

  static const double _markerSize = 18;
  static const double _padding = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canvasSize = Size(
      model.layout.size.width + _padding * 2,
      model.layout.size.height + _padding * 2,
    );

    final positionedNodes = <Widget>[];
    for (final node in model.visibleNodes) {
      final pos = model.layout.positions[node.id];
      if (pos == null) continue;
      final state = node.isSynthetic
          ? NodeState.available
          : model.snapshot.stateFor(node.id);
      final tiers = node.isSynthetic
          ? const <TierMasteryStatus>[]
          : model.snapshot.tiersFor(node.id);
      // Marker centered vertically on the row, label flowing right.
      positionedNodes.add(Positioned(
        left: pos.dx + _padding,
        top: pos.dy + _padding - _markerSize / 2,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) => ConceptNodeMarker(
            label: node.label,
            branchColor: node.branchColor,
            state: state,
            tiers: tiers,
            size: _markerSize,
            pulseT: pulse.value,
            onTap: node.isSynthetic ? null : () => onNodeTap?.call(node.id),
          ),
        ),
      ));
    }

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(400),
      child: SizedBox(
        width: canvasSize.width,
        height: canvasSize.height,
        child: Stack(
          children: [
            // Subtle dotted star-field background — sets the constellation
            // tone without overpowering the markers.
            Positioned.fill(
              child: CustomPaint(
                painter: _StarFieldPainter(isDark: isDark),
              ),
            ),
            // Curved connectors between every visible parent → child pair.
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectorPainter(
                  model: model,
                  padding: _padding,
                  markerSize: _markerSize,
                  isDark: isDark,
                ),
              ),
            ),
            ...positionedNodes,
          ],
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.model,
    required this.padding,
    required this.markerSize,
    required this.isDark,
  });

  final ProgressionMapModel model;
  final double padding;
  final double markerSize;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in model.visibleNodes) {
      final parentId = node.parentId;
      if (parentId == null) continue;
      final parent = model.nodes[parentId];
      if (parent == null) continue;
      // Skip if parent is locked-and-hidden (shouldn't happen since real
      // hidden parents already filter their subtree out of layout).
      if (!parent.isSynthetic &&
          model.snapshot.stateFor(parent.id) == NodeState.locked) {
        continue;
      }
      final pPos = model.layout.positions[parent.id];
      final cPos = model.layout.positions[node.id];
      if (pPos == null || cPos == null) continue;

      final parentMarker = Offset(
        pPos.dx + padding + markerSize / 2,
        pPos.dy + padding,
      );
      final childMarker = Offset(
        cPos.dx + padding + markerSize / 2,
        cPos.dy + padding,
      );

      // The line should go from the right edge of parent's marker to the
      // left edge of child's marker so it visually attaches to the rings.
      final p0 = Offset(parentMarker.dx + markerSize / 2, parentMarker.dy);
      final p3 = Offset(childMarker.dx - markerSize / 2, childMarker.dy);
      final midX = (p0.dx + p3.dx) / 2;
      final p1 = Offset(midX, p0.dy);
      final p2 = Offset(midX, p3.dy);

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

      final childState = node.isSynthetic
          ? NodeState.available
          : model.snapshot.stateFor(node.id);
      final isLit = childState == NodeState.mastered ||
          childState == NodeState.progress;
      final color = isLit
          ? node.branchColor.withOpacity(0.65)
          : (isDark ? Colors.white : Colors.black).withOpacity(0.20);
      final strokeWidth = isLit ? 1.6 : 1.0;

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.model != model || old.isDark != isDark;
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic pseudo-random dot field — no animation, just texture.
    // Seeded so the pattern is stable across rebuilds.
    final rng = math.Random(42);
    final dotColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.06);
    final paint = Paint()..color = dotColor;
    final count = (size.width * size.height / 8000).clamp(40, 400).toInt();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) =>
      old.isDark != isDark;
}

/// Hide the InteractiveViewer's default scrollbar styling — keeps the
/// canvas clean. Use [HapticFeedback.selectionClick] from the host screen
/// when a node is tapped.
class OrgChartMapEvents {
  const OrgChartMapEvents._();
  static void haptic() => HapticFeedback.selectionClick();
}
