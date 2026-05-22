import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../government/application/gov_map_data.dart';

/// Post-session "fly-to" view: zooms the gov map from the full system down
/// to whichever node(s) the user just touched, so every session ends with
/// concrete territorial progress visible. If the reviewed cards don't map to
/// any node (e.g. unattached deck), the widget renders nothing and the
/// summary degrades gracefully.
class SessionMapSummary extends ConsumerStatefulWidget {
  const SessionMapSummary({super.key, required this.reviewedCardIds});

  final List<String> reviewedCardIds;

  @override
  ConsumerState<SessionMapSummary> createState() => _SessionMapSummaryState();
}

class _SessionMapSummaryState extends ConsumerState<SessionMapSummary>
    with TickerProviderStateMixin {
  late final AnimationController _zoom;
  late final AnimationController _pulse;
  late final AnimationController _trail;
  late final Animation<double> _zoomCurve;
  late final Animation<double> _trailCurve;
  Future<_SessionMapData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _zoomCurve = CurvedAnimation(parent: _zoom, curve: Curves.easeInOutCubic);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // The fiery spark trail that flows from each affected node to its
    // downstream children. Fires once after the zoom settles so the user's
    // eye lands first, then watches the energy flow outward. Slow enough
    // that the eye can actually track it — sub-second is too fast.
    _trail = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _trailCurve = CurvedAnimation(parent: _trail, curve: Curves.easeInOutCubic);
    _zoom.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _trail.forward();
        });
      }
    });
    _dataFuture = _loadData();
  }

  Future<_SessionMapData> _loadData() async {
    final db = ref.read(databaseProvider);
    final map = await ref.read(govMapDataProvider.future);
    final affected = await nodeIdsForCardIds(db, widget.reviewedCardIds);
    // Every node whose unlock_requires lists one of the affected nodes —
    // these are the "next step" targets the trail flows toward.
    final downstream = <String, Set<String>>{}; // affectedId → child ids
    for (final n in map.nodes) {
      final reqs = _parseRequires(n.unlockRequires);
      for (final r in reqs) {
        if (!affected.contains(r)) continue;
        downstream.putIfAbsent(r, () => <String>{}).add(n.id);
      }
    }
    return _SessionMapData(
      nodes: map.nodes,
      edges: map.edges,
      mastery: map.masteryByNodeId,
      affectedNodeIds: affected,
      downstreamByParent: downstream,
    );
  }

  void _startZoomAfterFirstFrame() {
    if (_zoom.status != AnimationStatus.dismissed) return;
    // Brief beat at the full-map view so the eye registers "this is the whole
    // government" before we zoom in.
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _zoom.forward();
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _pulse.dispose();
    _trail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionMapData>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done ||
            snap.data == null) {
          return const AspectRatio(
            aspectRatio: 16 / 10,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snap.data!;
        if (data.affectedNodeIds.isEmpty) {
          return const SizedBox.shrink();
        }
        // Kick off the zoom on the first build after data is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startZoomAfterFirstFrame();
        });
        return _MapCard(
          data: data,
          zoom: _zoomCurve,
          pulse: _pulse,
          trail: _trailCurve,
        );
      },
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.data,
    required this.zoom,
    required this.pulse,
    required this.trail,
  });

  final _SessionMapData data;
  final Animation<double> zoom;
  final Animation<double> pulse;
  final Animation<double> trail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF11161F), Color(0xFF1A2230)]
                  : const [Color(0xFFF1F4F9), Color(0xFFE3E9F2)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([zoom, pulse, trail]),
                  builder: (context, _) => CustomPaint(
                    painter: _SessionMapPainter(
                      data: data,
                      zoom: zoom.value,
                      pulse: pulse.value,
                      trail: trail.value,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: _LabelChip(
                  text: 'YOUR PROGRESS',
                  color: theme.colorScheme.primary,
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: AnimatedBuilder(
                  animation: zoom,
                  builder: (context, _) {
                    final fade = ((zoom.value - 0.6) / 0.4).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: fade,
                      child: _Footer(data: data),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.data});
  final _SessionMapData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final count = data.affectedNodeIds.length;
    final names = data.affectedNodeIds
        .map((id) => data.nodes.firstWhere((n) => n.id == id))
        .map((n) => (n.shortName?.isNotEmpty ?? false) ? n.shortName! : n.name)
        .toList();
    final summary = count == 1
        ? 'Strengthened ${names.first}'
        : 'Strengthened $count areas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SessionMapData {
  const _SessionMapData({
    required this.nodes,
    required this.edges,
    required this.mastery,
    required this.affectedNodeIds,
    required this.downstreamByParent,
  });

  final List<GovNode> nodes;
  final List<GovEdge> edges;
  final Map<String, NodeMastery> mastery;
  final Set<String> affectedNodeIds;

  /// affectedNodeId → set of child node ids that list it in their
  /// unlock_requires. The spark trail flows from each affected node to each
  /// of its children.
  final Map<String, Set<String>> downstreamByParent;
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

class _SessionMapPainter extends CustomPainter {
  _SessionMapPainter({
    required this.data,
    required this.zoom,
    required this.pulse,
    required this.trail,
    required this.isDark,
  });

  final _SessionMapData data;
  final double zoom;  // eased 0..1
  final double pulse; // 0..1, reverses
  final double trail; // eased 0..1, one-shot — drives the spark position
  final bool isDark;

  /// Normalized-space viewport (in mapX/mapY coords) we're currently
  /// projecting onto the canvas. Lerps from full map → affected bounding box.
  Rect get _viewport {
    final full = const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
    final target = _affectedBoundingBox();
    if (target == null) return full;
    return Rect.lerp(full, target, zoom)!;
  }

  Rect? _affectedBoundingBox() {
    if (data.affectedNodeIds.isEmpty) return null;
    final affected = data.nodes
        .where((n) => data.affectedNodeIds.contains(n.id))
        .where((n) => n.mapX != null && n.mapY != null);
    if (affected.isEmpty) return null;

    double minX = 1, minY = 1, maxX = 0, maxY = 0;
    for (final n in affected) {
      final cx = n.mapX!;
      final cy = n.mapY!;
      final hw = (n.mapWidth ?? 0.2) * 0.5;
      final hh = (n.mapHeight ?? 0.1) * 0.5;
      minX = math.min(minX, cx - hw);
      maxX = math.max(maxX, cx + hw);
      minY = math.min(minY, cy - hh);
      maxY = math.max(maxY, cy + hh);
    }
    // Padding around the bounding box so labels and mastery chips have room.
    const pad = 0.10;
    minX = (minX - pad).clamp(0.0, 1.0);
    minY = (minY - pad - 0.04).clamp(0.0, 1.0); // extra top room for label
    maxX = (maxX + pad).clamp(0.0, 1.0);
    maxY = (maxY + pad + 0.06).clamp(0.0, 1.0); // extra bottom for mastery chip
    // Avoid degenerate boxes — minimum span 0.35 in each dimension.
    final w = maxX - minX;
    final h = maxY - minY;
    if (w < 0.35) {
      final cx = (minX + maxX) / 2;
      minX = (cx - 0.175).clamp(0.0, 1.0);
      maxX = (cx + 0.175).clamp(0.0, 1.0);
    }
    if (h < 0.35) {
      final cy = (minY + maxY) / 2;
      minY = (cy - 0.175).clamp(0.0, 1.0);
      maxY = (cy + 0.175).clamp(0.0, 1.0);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect _nodeCanvasRect(GovNode n, Size canvas) {
    final cx = (n.mapX ?? 0.5);
    final cy = (n.mapY ?? 0.5);
    final w = (n.mapWidth ?? 0.2);
    final h = (n.mapHeight ?? 0.1);
    final viewport = _viewport;
    final scaleX = canvas.width / viewport.width;
    final scaleY = canvas.height / viewport.height;
    final canvasCx = (cx - viewport.left) * scaleX;
    final canvasCy = (cy - viewport.top) * scaleY;
    final canvasW = math.max(28.0, w * scaleX * 0.85);
    final canvasH = math.max(24.0, h * scaleY * 0.85);
    return Rect.fromCenter(
      center: Offset(canvasCx, canvasCy),
      width: canvasW,
      height: canvasH,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Edges first (always dimmed — they're context only).
    final rects = <String, Rect>{
      for (final n in data.nodes) n.id: _nodeCanvasRect(n, size),
    };
    for (final e in data.edges) {
      if (!e.isVisibleOnMap) continue;
      final from = rects[e.fromNodeId];
      final to = rects[e.toNodeId];
      if (from == null || to == null) continue;
      // Only show edges that touch an affected node, to avoid map clutter
      // when we're zoomed in.
      final touchesAffected = data.affectedNodeIds.contains(e.fromNodeId) ||
          data.affectedNodeIds.contains(e.toNodeId);
      if (!touchesAffected) continue;
      _drawEdge(canvas, from, to);
    }

    // Nodes — affected on top.
    for (final n in data.nodes) {
      if (data.affectedNodeIds.contains(n.id)) continue;
      _drawNode(canvas, rects[n.id]!, n, affected: false);
    }
    for (final n in data.nodes) {
      if (!data.affectedNodeIds.contains(n.id)) continue;
      _drawNode(canvas, rects[n.id]!, n, affected: true);
    }

    // Mastery chips for affected nodes — fade in with the zoom.
    final chipFade = ((zoom - 0.55) / 0.45).clamp(0.0, 1.0);
    if (chipFade > 0) {
      for (final n in data.nodes) {
        if (!data.affectedNodeIds.contains(n.id)) continue;
        final m = data.mastery[n.id];
        if (m == null) continue;
        _drawMasteryChip(canvas, rects[n.id]!, m, chipFade, size);
      }
    }

    // Spark trails — fly from each affected node along its edges to every
    // downstream child. This is the "energy flowing to the next unlock"
    // beat that lands after the zoom settles.
    if (trail > 0) {
      _drawSparkTrails(canvas, rects);
    }
  }

  void _drawSparkTrails(Canvas canvas, Map<String, Rect> rects) {
    data.downstreamByParent.forEach((parentId, children) {
      final parentRect = rects[parentId];
      if (parentRect == null) return;
      final parentNode =
          data.nodes.firstWhere((n) => n.id == parentId, orElse: () => data.nodes.first);
      final color = _parseHex(parentNode.mapColor) ?? const Color(0xFFFFA500);
      for (final childId in children) {
        final childRect = rects[childId];
        if (childRect == null) continue;
        _drawSparkAlong(
          canvas,
          parentRect.center,
          childRect.center,
          color,
        );
      }
    });
  }

  void _drawSparkAlong(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
  ) {
    final t = trail.clamp(0.0, 1.0);
    final lit = Offset.lerp(from, to, t)!;

    // 1. Ignited edge segment — thick, branch-color, with a soft glow that
    // makes the line look like a fuse burning toward the next node.
    canvas.drawLine(
      from,
      lit,
      Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      lit,
      Paint()
        ..color = color.withOpacity(0.45)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 2. Comet tail — fading dots behind the leading orb. More dots, tighter
    // spacing, brighter colors, larger sizes so the trail actually reads as
    // a streaking comet rather than a single dot.
    for (var i = 1; i <= 10; i++) {
      final dotT = (t - i * 0.025).clamp(0.0, 1.0);
      if (dotT <= 0) continue;
      final pos = Offset.lerp(from, to, dotT)!;
      final fade = 1.0 - (i / 10);
      // Outer soft halo dot.
      canvas.drawCircle(
        pos,
        5.0 * fade + 1.5,
        Paint()
          ..color = color.withOpacity(0.35 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Inner bright dot.
      canvas.drawCircle(
        pos,
        2.5 * fade + 0.5,
        Paint()..color = color.withOpacity(0.85 * fade),
      );
    }

    // 3. Leading orb — fireball. Outer blur burst, mid halo, branch-color
    // core, hot white center.
    canvas.drawCircle(
      lit,
      28,
      Paint()
        ..color = color.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      lit,
      16,
      Paint()
        ..color = color.withOpacity(0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(lit, 8, Paint()..color = color);
    canvas.drawCircle(
      lit,
      3.5,
      Paint()..color = Colors.white,
    );

    // 4. Arrival burst — fires when the orb reaches the child node. Bigger,
    // brighter, longer-lived than the in-flight orb so the eye locks onto
    // the destination.
    if (t > 0.80) {
      final burstT = ((t - 0.80) / 0.20).clamp(0.0, 1.0);
      final ease = Curves.easeOutCubic.transform(burstT);
      canvas.drawCircle(
        to,
        12 + ease * 40,
        Paint()
          ..color = color.withOpacity(0.65 * (1 - ease))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        to,
        6 + ease * 18,
        Paint()
          ..color = Colors.white.withOpacity(0.90 * (1 - ease))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.drawCircle(
        to,
        4 + ease * 6,
        Paint()..color = color.withOpacity(0.85 * (1 - ease * 0.6)),
      );
    }
  }

  void _drawEdge(Canvas canvas, Rect from, Rect to) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.20)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from.center, to.center, paint);
  }

  void _drawNode(
    Canvas canvas,
    Rect rect,
    GovNode n, {
    required bool affected,
  }) {
    final base = _parseHex(n.mapColor) ?? const Color(0xFF555555);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    if (affected) {
      // Pulsing halo behind the rect — selection signal.
      final haloAlpha = 0.30 + pulse * 0.25;
      final haloInflate = 4.0 + pulse * 6.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(haloInflate),
          const Radius.circular(14),
        ),
        Paint()
          ..color = base.withOpacity(haloAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawRRect(rrect, Paint()..color = base);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()..color = base.withOpacity(0.22),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Label — only paint on affected nodes (others would be unreadable when
    // dimmed at zoom-in scale).
    if (affected) {
      final label =
          (n.shortName?.isNotEmpty ?? false) ? n.shortName! : n.name;
      final fontSize = math.max(10.0, rect.height * 0.28).clamp(10.0, 16.0);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
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
  }

  void _drawMasteryChip(
    Canvas canvas,
    Rect nodeRect,
    NodeMastery m,
    double fade,
    Size canvasSize,
  ) {
    // Gradient mastery — moves with every grade. The chip's job is to show
    // "your effort counted"; the binary masteredCount only ticks at ★5
    // milestones which can take weeks of reviews to hit.
    final pct = (m.masteryFraction * 100).round();
    final isMastered = m.isFullyMastered;
    final text = isMastered ? '★ MASTERED' : '$pct% mastered';

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(fade),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final chipWidth = tp.width + 14;
    final chipHeight = tp.height + 6;
    // Default: place chip below the node. Flip above if the chip would clip.
    var chipTop = nodeRect.bottom + 6;
    if (chipTop + chipHeight > canvasSize.height - 4) {
      chipTop = nodeRect.top - chipHeight - 6;
    }
    var chipLeft = nodeRect.center.dx - chipWidth / 2;
    chipLeft = chipLeft.clamp(4.0, canvasSize.width - chipWidth - 4);

    final chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);
    final chipColor = isMastered
        ? const Color(0xFFFFC107).withOpacity(fade * 0.95)
        : Colors.black.withOpacity(fade * 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
      Paint()..color = chipColor,
    );
    tp.paint(canvas, Offset(chipLeft + 7, chipTop + 3));
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
  bool shouldRepaint(covariant _SessionMapPainter old) =>
      old.zoom != zoom ||
      old.pulse != pulse ||
      old.trail != trail ||
      old.data != data ||
      old.isDark != isDark;
}
