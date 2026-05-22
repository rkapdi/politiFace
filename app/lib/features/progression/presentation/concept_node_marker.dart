import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/node_state.dart';
import '../domain/tier_mastery.dart';

/// OSINT-style node marker: a circle + a text label. Circle is the "active
/// side" (parent connection); label sits on the opposite side and reads
/// outward. Visual state encodes [NodeState]:
///
///   locked     — dashed grey ring, label dim
///   available  — branch-color ring + soft pulse halo
///   progress   — branch-color ring + partial-fill arc (per-tier average)
///   mastered   — branch-color filled circle + branch-color outer glow
class ConceptNodeMarker extends StatelessWidget {
  const ConceptNodeMarker({
    super.key,
    required this.label,
    required this.branchColor,
    required this.state,
    required this.tiers,
    this.labelOnLeft = false,
    this.size = 18,
    this.onTap,
    this.pulseT = 0.0,
  });

  final String label;
  final Color branchColor;
  final NodeState state;
  final List<TierMasteryStatus> tiers;

  /// True when this node is on the LEFT half of the tree (parent on right):
  /// label renders to the LEFT of the circle, reading right-to-the-circle.
  /// In our tree everything fans rightward from the root, so this is false
  /// for almost every node — except optionally the root.
  final bool labelOnLeft;

  final double size;
  final VoidCallback? onTap;

  /// 0..1 phase for the "available" pulse animation. Caller drives this.
  final double pulseT;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = state == NodeState.locked
        ? theme.colorScheme.onSurface.withOpacity(0.45)
        : theme.colorScheme.onSurface;

    final marker = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkerPainter(
          branchColor: branchColor,
          state: state,
          tiers: tiers,
          pulseT: pulseT,
          isDark: isDark,
        ),
      ),
    );

    final text = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: labelOnLeft ? TextAlign.right : TextAlign.left,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: state == NodeState.mastered
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    );

    final children = labelOnLeft
        ? [text, const SizedBox(width: 6), marker]
        : [marker, const SizedBox(width: 6), text];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter({
    required this.branchColor,
    required this.state,
    required this.tiers,
    required this.pulseT,
    required this.isDark,
  });

  final Color branchColor;
  final NodeState state;
  final List<TierMasteryStatus> tiers;
  final double pulseT;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    switch (state) {
      case NodeState.locked:
        _drawLocked(canvas, center, radius);
      case NodeState.available:
        _drawAvailable(canvas, center, radius);
      case NodeState.progress:
        _drawProgress(canvas, center, radius);
      case NodeState.mastered:
        _drawMastered(canvas, center, radius);
    }
  }

  void _drawLocked(Canvas canvas, Offset center, double radius) {
    final color = (isDark ? Colors.white : Colors.black).withOpacity(0.25);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawDashedCircle(canvas, center, radius - 1, paint);
  }

  void _drawAvailable(Canvas canvas, Offset center, double radius) {
    // Soft halo whose strength oscillates with pulseT (sine wave in [0, 1]).
    final pulse = 0.5 + 0.5 * math.sin(pulseT * 2 * math.pi);
    canvas.drawCircle(
      center,
      radius + 2 + pulse * 4,
      Paint()
        ..color = branchColor.withOpacity(0.18 + pulse * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Solid branch-color ring, no fill.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = branchColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _drawProgress(Canvas canvas, Offset center, double radius) {
    // Background ring (faint).
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = branchColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Foreground arc starting at 12 o'clock, sweeping clockwise by the mean
    // tier progress. Reads as "you've filled this much of the unlock gate."
    final progress = _meanProgress();
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius - 1);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = branchColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawMastered(Canvas canvas, Offset center, double radius) {
    // Branch-color glow.
    canvas.drawCircle(
      center,
      radius + 5,
      Paint()
        ..color = branchColor.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Filled circle.
    canvas.drawCircle(center, radius - 1, Paint()..color = branchColor);
    // Small white inset for the "lit star" feel.
    canvas.drawCircle(
      center,
      radius * 0.35,
      Paint()..color = Colors.white.withOpacity(0.85),
    );
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    const dashArc = 0.18; // radians per dash
    const gapArc = 0.18;
    for (var theta = 0.0; theta < 2 * math.pi; theta += dashArc + gapArc) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, theta, dashArc, false, paint);
    }
  }

  double _meanProgress() {
    final populated = tiers.where((t) => !t.isEmpty).toList();
    if (populated.isEmpty) return 0;
    var sum = 0.0;
    for (final t in populated) {
      sum += t.progressFraction;
    }
    return sum / populated.length;
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) =>
      old.state != state ||
      old.pulseT != pulseT ||
      old.branchColor != branchColor ||
      old.tiers != tiers ||
      old.isDark != isDark;
}
