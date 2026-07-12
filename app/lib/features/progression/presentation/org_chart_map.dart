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
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _unlockFlash;
  late final AnimationController _camera;
  late final TransformationController _transform;
  Set<String> _flashingNodeIds = const <String>{};
  Matrix4? _pendingTargetTransform;
  Matrix4? _cameraStart;

  @override
  void initState() {
    super.initState();
    // 2-second loop drives the available-state pulse halo.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // One-shot fade for the newly-unlocked flash. Reverses from 1 → 0 so
    // we use it as a decaying intensity multiplier in the marker painter.
    _unlockFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Drives camera pan + zoom to bring the freshly-unlocked frontier into
    // view. Short, easing curve handled at use site.
    _camera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_onCameraTick);
    _transform = TransformationController();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _unlockFlash.dispose();
    _camera
      ..removeListener(_onCameraTick)
      ..dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onCameraTick() {
    final start = _cameraStart;
    final target = _pendingTargetTransform;
    if (start == null || target == null) return;
    final t = Curves.easeInOutCubic.transform(_camera.value);
    _transform.value = _lerpMatrix(start, target, t);
  }

  /// Tween a 4x4 transform component-wise. Cheap and good enough for the
  /// translate+scale matrices the InteractiveViewer uses — the rotational
  /// terms stay zero throughout, so naive lerp doesn't produce nonsense.
  Matrix4 _lerpMatrix(Matrix4 a, Matrix4 b, double t) {
    final out = Matrix4.zero();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = a.storage[i] + (b.storage[i] - a.storage[i]) * t;
    }
    return out;
  }

  /// Compute a Matrix4 that centers [scenePoint] in a viewport of size
  /// [viewport], at scale [scale]. The InteractiveViewer applies
  /// scene→screen as `screen = scale*scene + translate`, so we pick
  /// `translate = viewport.center - scale*scenePoint`.
  Matrix4 _focusOn(
    Offset scenePoint,
    Size viewport,
    double scale,
  ) {
    final tx = viewport.width / 2 - scenePoint.dx * scale;
    final ty = viewport.height / 2 - scenePoint.dy * scale;
    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  /// Centroid of [points], or null if empty.
  Offset? _centroidOf(Iterable<Offset> points) {
    var sumX = 0.0;
    var sumY = 0.0;
    var n = 0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
      n++;
    }
    if (n == 0) return null;
    return Offset(sumX / n, sumY / n);
  }

  /// Kick off the camera animation to bring [scenePoint] to the center of
  /// the viewport at a comfortable zoom level. Called from the post-build
  /// path after we've detected fresh unlocks.
  void _animateCameraTo(Offset scenePoint, Size viewport) {
    final start = _transform.value.clone();
    const targetScale = 1.0;
    final target = _focusOn(scenePoint, viewport, targetScale);
    setState(() {
      _cameraStart = start;
      _pendingTargetTransform = target;
    });
    _camera
      ..reset()
      ..forward();
  }

  /// Compare the freshly loaded snapshot against what we last knew. If any
  /// node flipped locked → not-locked since then, fire the flash on it.
  void _detectUnlocks(ProgressionMapModel model) {
    final currentStates = <String, NodeState>{
      for (final entry in model.snapshot.nodeStates.entries)
        entry.key: entry.value,
    };
    final prev = ref.read(lastKnownNodeStatesProvider);
    // Always update the stored "previous" set so the next render compares
    // against this one.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(lastKnownNodeStatesProvider.notifier).state = currentStates;
    });
    if (prev == null) return; // cold launch — no animation
    final unlocked = <String>{};
    currentStates.forEach((id, state) {
      final wasLocked = (prev[id] ?? NodeState.locked) == NodeState.locked;
      final nowUnlocked = state != NodeState.locked;
      if (wasLocked && nowUnlocked) unlocked.add(id);
    });
    if (unlocked.isEmpty) return;
    _flashingNodeIds = unlocked;
    _unlockFlash
      ..reset()
      ..forward();
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
      data: (model) {
        _detectUnlocks(model);
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            // Schedule the camera pan AFTER this frame settles so the
            // InteractiveViewer is laid out (and our transform target maps
            // to actual screen coords). Only fires when we have flashing
            // nodes to focus on.
            if (_flashingNodeIds.isNotEmpty &&
                _camera.status == AnimationStatus.dismissed) {
              final positions = _flashingNodeIds
                  .map((id) => model.layout.positions[id])
                  .whereType<Offset>()
                  // Same padding offset _MapCanvas uses when placing markers.
                  .map((p) => Offset(
                        p.dx + _MapCanvas._padding + _MapCanvas._markerSize / 2,
                        p.dy + _MapCanvas._padding,
                      ),)
                  .toList();
              final centroid = _centroidOf(positions);
              if (centroid != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _animateCameraTo(centroid, viewport);
                });
              }
            }
            return _MapCanvas(
              model: model,
              pulse: _pulse,
              unlockFlash: _unlockFlash,
              flashingNodeIds: _flashingNodeIds,
              transformationController: _transform,
              onNodeTap: widget.onNodeTap,
            );
          },
        );
      },
    );
  }
}

class _MapCanvas extends ConsumerWidget {
  const _MapCanvas({
    required this.model,
    required this.pulse,
    required this.unlockFlash,
    required this.flashingNodeIds,
    required this.transformationController,
    this.onNodeTap,
  });

  final ProgressionMapModel model;
  final Animation<double> pulse;
  final Animation<double> unlockFlash;
  final Set<String> flashingNodeIds;
  final TransformationController transformationController;
  final void Function(String nodeId)? onNodeTap;

  static const double _markerSize = 18;
  static const double _padding = 80;

  void _toggleCollapse(WidgetRef ref, String nodeId) {
    final current = ref.read(collapsedNodeIdsProvider);
    final next = {...current};
    if (next.contains(nodeId)) {
      next.remove(nodeId);
    } else {
      next.add(nodeId);
    }
    HapticFeedback.selectionClick();
    ref.read(collapsedNodeIdsProvider.notifier).state = next;
  }

  /// Tap behavior, in priority order:
  ///   1. Synthetic branch groupings → toggle expand/collapse (they have
  ///      no sheet to open).
  ///   2. Real node with children → toggle expand/collapse. To play the
  ///      node itself, long-press for the sheet.
  ///   3. Real leaf node, locked → snackbar pointing at the prereq.
  ///   4. Real leaf node, unlocked → open the tier sheet.
  void _handleNodeTap(
    BuildContext context,
    WidgetRef ref,
    ProgressionMapModel model,
    ProgressionMapNode node,
    NodeState state,
    bool hasChildren,
  ) {
    if (node.isSynthetic) {
      if (hasChildren) _toggleCollapse(ref, node.id);
      return;
    }
    if (hasChildren) {
      _toggleCollapse(ref, node.id);
      return;
    }
    if (state == NodeState.locked) {
      HapticFeedback.heavyImpact();
      final prereqLabel = _firstLockedPrereqLabel(model, node);
      final hint = prereqLabel == null
          ? 'Master earlier nodes to unlock this.'
          : 'Master $prereqLabel to unlock ${node.label}.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(hint),
          duration: const Duration(seconds: 2),
        ),);
      return;
    }
    onNodeTap?.call(node.id);
  }

  /// Long-press → open the sheet, regardless of whether the node has
  /// children. Lets the user play a parent node like President without
  /// first having to drill into a leaf.
  void _handleNodeLongPress(
    BuildContext context,
    ProgressionMapModel model,
    ProgressionMapNode node,
    NodeState state,
  ) {
    if (node.isSynthetic) return;
    if (state == NodeState.locked) {
      HapticFeedback.heavyImpact();
      final prereqLabel = _firstLockedPrereqLabel(model, node);
      final hint = prereqLabel == null
          ? 'Master earlier nodes to unlock this.'
          : 'Master $prereqLabel to unlock ${node.label}.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(hint),
          duration: const Duration(seconds: 2),
        ),);
      return;
    }
    HapticFeedback.mediumImpact();
    onNodeTap?.call(node.id);
  }

  /// Look up the label of the first not-yet-mastered prerequisite for
  /// [node] — used to build the "Master X to unlock Y" snackbar.
  String? _firstLockedPrereqLabel(
    ProgressionMapModel model,
    ProgressionMapNode node,
  ) {
    final parentId = node.parentId;
    if (parentId == null) return null;
    final parent = model.nodes[parentId];
    if (parent == null) return null;
    // Synthetic branch groupings (Legislative / Executive / Judicial) aren't
    // real gates — walk up one more step.
    if (parent.isSynthetic) {
      final grand = parent.parentId == null ? null : model.nodes[parent.parentId!];
      return grand?.isSynthetic == false ? grand!.label : null;
    }
    return parent.label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final collapsedIds = ref.watch(collapsedNodeIdsProvider);
    final canvasSize = Size(
      model.layout.size.width + _padding * 2,
      model.layout.size.height + _padding * 2,
    );

    // Precompute "does this node have any children at all?" so the tap
    // handler can route to expand/collapse vs sheet without rescanning.
    final hasChildren = <String, bool>{};
    for (final n in model.nodes.values) {
      if (n.parentId != null) hasChildren[n.parentId!] = true;
    }

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
      final nodeHasChildren = hasChildren[node.id] ?? false;
      final isCollapsed = collapsedIds.contains(node.id);
      // Marker centered vertically on the row, label flowing right.
      final isFlashing = flashingNodeIds.contains(node.id);
      positionedNodes.add(Positioned(
        left: pos.dx + _padding,
        top: pos.dy + _padding - _markerSize / 2,
        child: AnimatedBuilder(
          animation: Listenable.merge([pulse, unlockFlash]),
          builder: (context, _) => ConceptNodeMarker(
            label: node.label,
            branchColor: node.branchColor,
            state: state,
            tiers: tiers,
            pulseT: pulse.value,
            unlockFlashT: isFlashing ? (1.0 - unlockFlash.value) : 0.0,
            hasChildren: nodeHasChildren,
            isCollapsed: isCollapsed,
            onTap: () => _handleNodeTap(
              context,
              ref,
              model,
              node,
              state,
              nodeHasChildren,
            ),
            onLongPress: node.isSynthetic
                ? null
                : () => _handleNodeLongPress(context, model, node, state),
          ),
        ),
      ),);
    }

    return InteractiveViewer(
      constrained: false,
      minScale: 0.4,
      boundaryMargin: const EdgeInsets.all(400),
      transformationController: transformationController,
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
