import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/drift/app_database.dart';
import '../application/gov_map_data.dart';

/// Eagle-eye view: all nodes positioned spatially, edges drawn between them
/// with relationship-typed styling, and small dots flowing along each edge in
/// the direction of the relationship — so the user can see appoints / confirms
/// / checks as live arrows of activity rather than static lines.
class SystemView extends StatefulWidget {
  const SystemView({super.key, required this.data});
  final GovMapData data;

  @override
  State<SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends State<SystemView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  String? _highlightedNodeId;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTapUp: (details) {
                  final node = _hitTest(details.localPosition, canvasSize);
                  if (node == null) {
                    setState(() => _highlightedNodeId = null);
                    return;
                  }
                  HapticFeedback.lightImpact();
                  if (!widget.data.isUnlocked(node.id)) {
                    setState(() => _highlightedNodeId = node.id);
                    return;
                  }
                  if (_highlightedNodeId == node.id) {
                    // Second tap on already-highlighted node: open detail.
                    GoRouter.of(ctx).go('/node/${node.id}');
                  } else {
                    setState(() => _highlightedNodeId = node.id);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) => CustomPaint(
                    size: canvasSize,
                    painter: _SystemPainter(
                      data: widget.data,
                      flowProgress: _flow.value,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerLowest,
                      highlightedNodeId: _highlightedNodeId,
                      theme: theme,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          _Legend(highlightedNodeId: _highlightedNodeId, data: widget.data),
        ],
      ),
    );
  }

  GovNode? _hitTest(Offset point, Size canvasSize) {
    for (final n in widget.data.nodes) {
      final rect = _SystemPainter._rectFor(n, canvasSize);
      if (rect.inflate(8).contains(point)) return n;
    }
    return null;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.highlightedNodeId, required this.data});
  final String? highlightedNodeId;
  final GovMapData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (highlightedNodeId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          'Tap a node to see how it connects. Tap again to open it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    final node = data.nodes.firstWhere((n) => n.id == highlightedNodeId);
    final outbound = data.edges
        .where((e) => e.fromNodeId == node.id)
        .map((e) => '→ ${e.relationshipType} ${_shortName(e.toNodeId)}')
        .toList();
    final inbound = data.edges
        .where((e) => e.toNodeId == node.id)
        .map((e) => '${_shortName(e.fromNodeId)} ${e.relationshipType} →')
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...outbound.map((s) => Text(
                s,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
          ...inbound.map((s) => Text(
                s,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
        ],
      ),
    );
  }

  String _shortName(String nodeId) {
    final node = data.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => data.nodes.first,
    );
    return (node.shortName?.isNotEmpty ?? false) ? node.shortName! : node.name;
  }
}

class _SystemPainter extends CustomPainter {
  _SystemPainter({
    required this.data,
    required this.flowProgress,
    required this.backgroundColor,
    required this.highlightedNodeId,
    required this.theme,
  });

  final GovMapData data;
  final double flowProgress; // 0..1, repeats
  final Color backgroundColor;
  final String? highlightedNodeId;
  final ThemeData theme;

  static Rect _rectFor(GovNode n, Size size) {
    final cx = (n.mapX ?? 0.5) * size.width;
    final cy = (n.mapY ?? 0.5) * size.height;
    final w = math.max(46.0, (n.mapWidth ?? 0.2) * size.width * 0.85);
    final h = math.max(44.0, (n.mapHeight ?? 0.1) * size.height * 0.85);
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final rects = <String, Rect>{};
    for (final n in data.nodes) {
      rects[n.id] = _rectFor(n, size);
    }

    // Draw edges first so nodes sit on top.
    for (final e in data.edges) {
      if (!e.isVisibleOnMap) continue;
      final from = rects[e.fromNodeId];
      final to = rects[e.toNodeId];
      if (from == null || to == null) continue;

      final involvesHighlight = highlightedNodeId == null ||
          e.fromNodeId == highlightedNodeId ||
          e.toNodeId == highlightedNodeId;
      _drawEdge(canvas, from, to, e, dimmed: !involvesHighlight);
    }

    // Nodes on top of edges.
    for (final n in data.nodes) {
      final rect = rects[n.id]!;
      final dimmed = highlightedNodeId != null && highlightedNodeId != n.id;
      _drawNode(canvas, rect, n, dimmed: dimmed);
    }
  }

  void _drawNode(Canvas canvas, Rect rect, GovNode n, {required bool dimmed}) {
    final base = _parseHex(n.mapColor) ?? const Color(0xFF555555);
    final fill = data.isUnlocked(n.id)
        ? base
        : base.withOpacity(0.30);
    final alpha = dimmed ? 0.45 : 1.0;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()..color = fill.withOpacity(fill.opacity * alpha),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withOpacity(0.18 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final label = (n.shortName?.isNotEmpty ?? false) ? n.shortName! : n.name;
    final fontSize = math.max(9.0, rect.height * 0.26);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withOpacity(alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 6);
    tp.paint(
      canvas,
      Offset(
        rect.center.dx - tp.width / 2,
        rect.center.dy - tp.height / 2,
      ),
    );
  }

  void _drawEdge(Canvas canvas, Rect from, Rect to, GovEdge e,
      {required bool dimmed}) {
    final start = _edgePoint(from, to.center);
    final end = _edgePoint(to, from.center);
    final color = _parseHex(e.lineColor) ?? Colors.grey.shade600;
    final alpha = dimmed ? 0.18 : 0.85;
    final paint = Paint()
      ..color = color.withOpacity(alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (e.lineStyle) {
      case 'dashed':
        _drawDashed(canvas, start, end, paint, dash: 8, gap: 5);
      case 'dotted':
        _drawDashed(canvas, start, end, paint, dash: 2, gap: 4);
      default:
        canvas.drawLine(start, end, paint);
    }

    // Arrowhead at destination.
    _drawArrow(canvas, start, end,
        Paint()..color = color.withOpacity(alpha));

    // Flow dot — only when not dimmed, otherwise it adds noise.
    if (!dimmed) {
      final t = flowProgress;
      final pos = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      canvas.drawCircle(
        pos,
        3.5,
        Paint()..color = color.withOpacity(0.95),
      );
      // Trailing soft glow.
      canvas.drawCircle(
        pos,
        7,
        Paint()
          ..color = color.withOpacity(0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  Offset _edgePoint(Rect rect, Offset toward) {
    final dx = toward.dx - rect.center.dx;
    final dy = toward.dy - rect.center.dy;
    if (dx == 0 && dy == 0) return rect.center;
    final hw = rect.width / 2;
    final hh = rect.height / 2;
    final scale = math.min(
      hw / dx.abs().clamp(0.0001, double.infinity),
      hh / dy.abs().clamp(0.0001, double.infinity),
    );
    return Offset(
      rect.center.dx + dx * scale,
      rect.center.dy + dy * scale,
    );
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint,
      {required double dash, required double gap}) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    final step = dash + gap;
    var travelled = 0.0;
    while (travelled < dist) {
      final segEnd = math.min(travelled + dash, dist);
      final p1 = Offset(a.dx + ux * travelled, a.dy + uy * travelled);
      final p2 = Offset(a.dx + ux * segEnd, a.dy + uy * segEnd);
      canvas.drawLine(p1, p2, paint);
      travelled += step;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const headLen = 8.0;
    const halfW = 4.0;
    final base = Offset(
      end.dx - math.cos(angle) * headLen,
      end.dy - math.sin(angle) * headLen,
    );
    final left = Offset(
      base.dx - math.sin(angle) * halfW,
      base.dy + math.cos(angle) * halfW,
    );
    final right = Offset(
      base.dx + math.sin(angle) * halfW,
      base.dy - math.cos(angle) * halfW,
    );
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  @override
  bool shouldRepaint(covariant _SystemPainter old) =>
      old.flowProgress != flowProgress ||
      old.highlightedNodeId != highlightedNodeId ||
      old.data != data;
}
