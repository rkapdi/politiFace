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
    required this.label, required this.branchColor, required this.state, required this.tiers, super.key,
    this.labelOnLeft = false,
    this.size = 18,
    this.onTap,
    this.onLongPress,
    this.pulseT = 0.0,
    this.unlockFlashT = 0.0,
    this.hasChildren = false,
    this.isCollapsed = false,
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

  /// Long-press handler — used by real-parent nodes (e.g. President) so the
  /// user can open the tier sheet even though tap toggles collapse for any
  /// node that has children.
  final VoidCallback? onLongPress;

  /// 0..1 phase for the "available" pulse animation. Caller drives this.
  final double pulseT;

  /// 0..1 reveal — 0 = no flash, 1 = peak. The map sets this on nodes that
  /// just unlocked and runs it down to 0 with a curve. Paints a transient
  /// halo overlay no matter what the state is, so the user can SEE the
  /// thing they earned.
  final double unlockFlashT;

  /// Whether this node has any children — drives the expand/collapse
  /// chevron rendering and changes the tap-target semantics.
  final bool hasChildren;

  /// True when the user has collapsed this node's subtree. Chevron points
  /// right when collapsed (▶), down when expanded (▼).
  final bool isCollapsed;

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
          unlockFlashT: unlockFlashT,
          isDark: isDark,
        ),
      ),
    );

    final text = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            labelOnLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
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
          // Tier pips — three small dots showing per-tier mastery state.
          // Hidden on synthetic / locked nodes (nothing to convey) and on
          // nodes with no authored tiers.
          if (state != NodeState.locked &&
              tiers.any((t) => !t.isEmpty)) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in tiers) ...[
                  _TierPip(tier: t, branchColor: branchColor, isDark: isDark),
                  const SizedBox(width: 3),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    // Chevron — only shown when this node has children. Rotates 0° when
    // expanded (▼) and -90° when collapsed (▶) so the affordance reads as
    // a folder-style disclosure indicator.
    final chevron = hasChildren
        ? Padding(
            padding: const EdgeInsets.only(left: 4),
            child: AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: textColor.withOpacity(0.55),
              ),
            ),
          )
        : null;

    final children = labelOnLeft
        ? [
            if (chevron != null) chevron,
            text,
            const SizedBox(width: 6),
            marker,
          ]
        : [
            marker,
            const SizedBox(width: 6),
            text,
            if (chevron != null) chevron,
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
    required this.unlockFlashT,
    required this.isDark,
  });

  final Color branchColor;
  final NodeState state;
  final List<TierMasteryStatus> tiers;
  final double pulseT;
  final double unlockFlashT;
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

    // Transient unlock flash — branch-color halo that grows from the marker
    // and fades out. Drawn last so it sits on top of the base state paint.
    if (unlockFlashT > 0) {
      final t = unlockFlashT.clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius + 4 + t * 18,
        Paint()
          ..color = branchColor.withOpacity(0.55 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        center,
        radius + 1 + t * 6,
        Paint()
          ..color = Colors.white.withOpacity(0.7 * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
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
      Canvas canvas, Offset center, double radius, Paint paint,) {
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
      old.unlockFlashT != unlockFlashT ||
      old.branchColor != branchColor ||
      old.tiers != tiers ||
      old.isDark != isDark;
}

/// One of the three tier dots below the marker label. Empty when the tier
/// has no content; partially filled by progressFraction; fully filled when
/// the tier has cleared the demonstrated-recall gate.
class _TierPip extends StatelessWidget {
  const _TierPip({
    required this.tier,
    required this.branchColor,
    required this.isDark,
  });

  final TierMasteryStatus tier;
  final Color branchColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const size = 6.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PipPainter(
          branchColor: branchColor,
          fillFraction: tier.isEmpty ? 0 : tier.progressFraction.clamp(0.0, 1.0),
          isMastered: tier.isMastered,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  _PipPainter({
    required this.branchColor,
    required this.fillFraction,
    required this.isMastered,
    required this.isDark,
  });

  final Color branchColor;
  final double fillFraction;
  final bool isMastered;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final outline = (isDark ? Colors.white : Colors.black).withOpacity(0.22);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    if (isMastered) {
      canvas.drawCircle(center, radius, Paint()..color = branchColor);
      return;
    }
    if (fillFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 0.3),
        -math.pi / 2,
        2 * math.pi * fillFraction,
        true,
        Paint()..color = branchColor.withOpacity(0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) =>
      old.fillFraction != fillFraction ||
      old.isMastered != isMastered ||
      old.branchColor != branchColor ||
      old.isDark != isDark;
}
