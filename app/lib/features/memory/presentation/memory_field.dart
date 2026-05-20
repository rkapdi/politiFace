import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/memory_service.dart';

/// Orbital visualization of every reviewed card.
///
///  - Each card = a glowing dot at radius proportional to log(stability)
///  - The whole field rotates slowly (60s/turn)
///  - Each dot breathes on a desynced cycle (3s)
///  - A radar sweep beam scans the field (10s/turn); cards brighten as it
///    passes
///  - Each dot wears a thin retrievability arc — full circle = 100% recall
///    probability; sliver = about to be forgotten
///  - Tier rings labeled ★1..★5 for orientation
///  - Long-press an orb to freeze the field and inspect that card
class MemoryField extends StatefulWidget {
  const MemoryField({super.key, required this.orbits});
  final List<OrbitalCard> orbits;

  @override
  State<MemoryField> createState() => _MemoryFieldState();
}

const _tierColors = <Color>[
  Color(0xFFE57373), // ★1 red
  Color(0xFFFFB74D), // ★2 orange
  Color(0xFF64B5F6), // ★3 blue
  Color(0xFF81C784), // ★4 green
  Color(0xFFFFD54F), // ★5 gold
];

double _stabilityRadiusFactor(double s) {
  final clamped = s.clamp(0.5, 365.0);
  final log = math.log(clamped + 1) / math.log(366);
  return 0.18 + log * 0.74;
}

double _orbRetrievability(OrbitalCard o, int nowSeconds) {
  if (o.lastReviewedAtUnix == 0) return 1.0;
  final elapsedDays = (nowSeconds - o.lastReviewedAtUnix) / 86400.0;
  final s = math.max(0.1, o.stability);
  return 1.0 / (1.0 + elapsedDays / (9.0 * s));
}

class _OrbHit {
  const _OrbHit(this.card, this.pos);
  final OrbitalCard card;
  final Offset pos;
}

class _MemoryFieldState extends State<MemoryField>
    with TickerProviderStateMixin {
  late final AnimationController _rotation;
  late final AnimationController _breath;
  late final AnimationController _sweep;

  OrbitalCard? _selected;
  Offset? _selectedPos;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    _breath.dispose();
    _sweep.dispose();
    super.dispose();
  }

  _OrbHit? _hitTest(Offset tap, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final orbitAngle = _rotation.value * 2 * math.pi;
    OrbitalCard? best;
    Offset? bestPos;
    double bestDist = 32; // generous touch tolerance for moving orbs
    for (final o in widget.orbits) {
      final hash = o.id.hashCode;
      final baseAngle = (hash % 360) * math.pi / 180;
      final worldAngle = baseAngle + orbitAngle;
      final r = _stabilityRadiusFactor(o.stability) * radius;
      final pos = Offset(
        center.dx + math.cos(worldAngle) * r,
        center.dy + math.sin(worldAngle) * r,
      );
      final dist = (pos - tap).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = o;
        bestPos = pos;
      }
    }
    if (best == null || bestPos == null) return null;
    return _OrbHit(best, bestPos);
  }

  void _handleLongPress(LongPressStartDetails details, Size size) {
    final hit = _hitTest(details.localPosition, size);
    if (hit == null) return;
    setState(() {
      _selected = hit.card;
      _selectedPos = hit.pos;
    });
    _rotation.stop(canceled: false);
    _breath.stop(canceled: false);
    _sweep.stop(canceled: false);
  }

  void _dismiss() {
    if (_selected == null) return;
    setState(() {
      _selected = null;
      _selectedPos = null;
    });
    _rotation.repeat();
    _breath.repeat();
    _sweep.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotation, _breath, _sweep]),
                  builder: (context, _) => CustomPaint(
                    painter: _MemoryFieldPainter(
                      orbits: widget.orbits,
                      rotation: _rotation.value,
                      breath: _breath.value,
                      sweep: _sweep.value,
                      brightness: theme.brightness,
                      primary: theme.colorScheme.primary,
                      outlineVariant: theme.colorScheme.outlineVariant,
                      selectedId: _selected?.id,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: (d) => _handleLongPress(d, size),
                  onTap: _selected != null ? _dismiss : null,
                ),
              ),
              if (_selected != null && _selectedPos != null)
                _OrbPopover(
                  card: _selected!,
                  orbPos: _selectedPos!,
                  fieldSize: size,
                  onDismiss: _dismiss,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbPopover extends StatelessWidget {
  const _OrbPopover({
    required this.card,
    required this.orbPos,
    required this.fieldSize,
    required this.onDismiss,
  });

  final OrbitalCard card;
  final Offset orbPos;
  final Size fieldSize;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const popoverWidth = 224.0;
    const popoverHeight = 116.0;
    const margin = 8.0;
    const orbGap = 14.0;

    final preferredAbove = orbPos.dy - popoverHeight - orbGap;
    final useAbove = preferredAbove >= margin;
    final y = useAbove
        ? preferredAbove
        : math.min(orbPos.dy + orbGap, fieldSize.height - popoverHeight - margin);
    final x = (orbPos.dx - popoverWidth / 2)
        .clamp(margin, fieldSize.width - popoverWidth - margin)
        .toDouble();

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final retrievability = _orbRetrievability(card, nowSeconds);
    final elapsedDays = card.lastReviewedAtUnix == 0
        ? 0.0
        : (nowSeconds - card.lastReviewedAtUnix) / 86400.0;
    final tierColor = _tierColors[(card.level - 1).clamp(0, 4)];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      left: x,
      top: y,
      width: popoverWidth,
      height: popoverHeight,
      child: IgnorePointer(
        // Tapping the popover should dismiss too — pass taps through to the
        // gesture detector below. Long-press elsewhere still re-targets.
        ignoring: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            alignment:
                useAbove ? Alignment.bottomCenter : Alignment.topCenter,
            child: Opacity(opacity: math.min(1.0, scale), child: child),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2330).withOpacity(0.96)
                    : Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: tierColor.withOpacity(0.55), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★${card.level}',
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.politicianName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Recall',
                          value: '${(retrievability * 100).round()}%',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatChip(
                          label: 'Stability',
                          value: _formatDays(card.stability),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatChip(
                          label: 'Seen',
                          value: _formatElapsed(
                              elapsedDays, card.lastReviewedAtUnix),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDays(double d) {
    if (d < 1) {
      final hours = (d * 24).round();
      return '${hours}h';
    }
    if (d < 10) return '${d.toStringAsFixed(1)}d';
    return '${d.round()}d';
  }

  String _formatElapsed(double d, int lastReviewedAt) {
    if (lastReviewedAt == 0) return 'just now';
    if (d < 1 / 24) return 'just now';
    if (d < 1) return '${(d * 24).round()}h ago';
    if (d < 10) return '${d.toStringAsFixed(1)}d ago';
    return '${d.round()}d ago';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.55),
            letterSpacing: 0.6,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            fontFeatures: const [ui.FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _MemoryFieldPainter extends CustomPainter {
  _MemoryFieldPainter({
    required this.orbits,
    required this.rotation,
    required this.breath,
    required this.sweep,
    required this.brightness,
    required this.primary,
    required this.outlineVariant,
    required this.selectedId,
  }) : nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final List<OrbitalCard> orbits;
  final double rotation; // 0..1, repeats (60s)
  final double breath;   // 0..1, repeats (3s)
  final double sweep;    // 0..1, repeats (10s)
  final Brightness brightness;
  final Color primary;
  final Color outlineVariant;
  final String? selectedId;
  final int nowSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final sweepAngle = sweep * 2 * math.pi;
    final orbitAngle = rotation * 2 * math.pi;
    final breathAngle = breath * 2 * math.pi;

    _drawRings(canvas, center, radius);
    _drawRadarSweep(canvas, center, radius, sweepAngle);
    _drawCore(canvas, center);

    if (orbits.isEmpty) {
      _drawEmptyHint(canvas, center, size);
      return;
    }

    for (final o in orbits) {
      final hash = o.id.hashCode;
      final baseAngle = (hash % 360) * math.pi / 180;
      final worldAngle = baseAngle + orbitAngle;
      final r = _stabilityRadiusFactor(o.stability) * radius;
      final pos = Offset(
        center.dx + math.cos(worldAngle) * r,
        center.dy + math.sin(worldAngle) * r,
      );

      // Per-card desynced breath.
      final phase = (hash % 100) / 100;
      final localBreath = math.sin(breathAngle + phase * 2 * math.pi);
      final pulse = 1.0 + 0.12 * localBreath;

      // Sweep brightness boost: 1.0 when sweep line is on top of card,
      // fades to 0 within ~30° behind it. Trailing only — feels like radar.
      final delta = _normAngle(sweepAngle - worldAngle);
      const sweepWidth = math.pi / 4; // 45° trail
      final sweepBoost =
          delta < sweepWidth ? (1.0 - delta / sweepWidth) : 0.0;
      final selected = o.id == selectedId;

      final color = _tierColors[(o.level - 1).clamp(0, 4)];
      _drawOrb(canvas, pos, color, pulse, o.stability, sweepBoost, selected);
      _drawRetrievabilityArc(
          canvas, pos, color, _orbRetrievability(o, nowSeconds), pulse, o.stability);
    }
  }

  void _drawRings(Canvas canvas, Offset center, double radius) {
    final isDark = brightness == Brightness.dark;
    final ringColor = (isDark ? Colors.white : Colors.black).withOpacity(0.14);
    final labelColor = (isDark ? Colors.white : Colors.black).withOpacity(0.40);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ringColor;

    for (var tier = 1; tier <= 5; tier++) {
      final r = _stabilityRadiusFactor(_stabilityForTierStart(tier)) * radius;
      canvas.drawCircle(center, r, ringPaint);
      // Label at ~4 o'clock so it stays out of the sweep starting position.
      final labelAngle = 1.05; // ~60° below horizontal
      final tp = TextPainter(
        text: TextSpan(
          text: '★$tier',
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final labelOffset = Offset(
        center.dx + math.cos(labelAngle) * r - tp.width / 2,
        center.dy + math.sin(labelAngle) * r - tp.height / 2,
      );
      // Pad the label with a small backdrop so it stays legible over rings.
      final pad = const EdgeInsets.symmetric(horizontal: 3, vertical: 1);
      final rect = Rect.fromLTWH(
        labelOffset.dx - pad.left,
        labelOffset.dy - pad.top,
        tp.width + pad.horizontal,
        tp.height + pad.vertical,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..color = (isDark ? Colors.black : Colors.white).withOpacity(0.40),
      );
      tp.paint(canvas, labelOffset);
    }
  }

  void _drawRadarSweep(
      Canvas canvas, Offset center, double radius, double angle) {
    // Trailing wedge — angular fade so it reads like a radar sweep.
    const wedge = math.pi / 3; // 60° tail
    final start = angle - wedge;
    final rect = Rect.fromCircle(center: center, radius: radius * 0.95);

    // Sweep gradient from transparent (tail) to bright (leading edge).
    canvas.drawArc(
      rect,
      start,
      wedge,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: angle,
          colors: [
            primary.withOpacity(0.0),
            primary.withOpacity(0.18),
          ],
        ).createShader(rect),
    );

    // Crisp leading line.
    final end = Offset(
      center.dx + math.cos(angle) * radius * 0.95,
      center.dy + math.sin(angle) * radius * 0.95,
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = primary.withOpacity(0.55)
        ..strokeWidth = 1.3,
    );
  }

  double _stabilityForTierStart(int tier) {
    switch (tier) {
      case 1:
        return 0.5;
      case 2:
        return 3;
      case 3:
        return 7;
      case 4:
        return 14;
      case 5:
        return 30;
      default:
        return 0.5;
    }
  }

  void _drawCore(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = primary.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = primary.withOpacity(0.55),
    );
    canvas.drawCircle(
      center,
      3,
      Paint()..color = primary,
    );
  }

  void _drawOrb(
    Canvas canvas,
    Offset pos,
    Color color,
    double pulse,
    double stability,
    double sweepBoost,
    bool selected,
  ) {
    final base = 4.0 + math.log(stability.clamp(0.5, 365)) * 0.6;
    final r = base * pulse;

    // Selection halo — soft outer glow + crisp white ring so the picked orb
    // is unmistakable while the field is frozen.
    if (selected) {
      canvas.drawCircle(
        pos,
        r * 5.5,
        Paint()
          ..color = color.withOpacity(0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        pos,
        r + 6,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Sweep boost makes glow grow and dot intensify briefly.
    final glowR = r * (3.2 + sweepBoost * 1.8);
    final glowOpacity = 0.16 + sweepBoost * 0.30;

    canvas.drawCircle(
      pos,
      glowR,
      Paint()
        ..color = color.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = Color.lerp(color, Colors.white, sweepBoost * 0.3) ?? color,
    );
    canvas.drawCircle(
      Offset(pos.dx - r * 0.3, pos.dy - r * 0.3),
      r * 0.35,
      Paint()..color = Colors.white.withOpacity(0.30 + sweepBoost * 0.30),
    );
  }

  /// Thin ring around the dot — full circle when R≈1, shrinks to a sliver
  /// as memory decays. The "live" part of the algorithm made visible.
  void _drawRetrievabilityArc(
    Canvas canvas,
    Offset pos,
    Color color,
    double retrievability,
    double pulse,
    double stability,
  ) {
    final base = 4.0 + math.log(stability.clamp(0.5, 365)) * 0.6;
    final dotR = base * pulse;
    final arcR = dotR + 4;
    final rect = Rect.fromCircle(center: pos, radius: arcR);
    final r = retrievability.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * r, false, paint);
  }

  /// Returns the smallest positive angle between two angles ∈ [0, 2π).
  double _normAngle(double delta) {
    var d = delta % (2 * math.pi);
    if (d < 0) d += 2 * math.pi;
    return d;
  }

  void _drawEmptyHint(Canvas canvas, Offset center, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Review a card to see your memory field come alive.',
        style: TextStyle(
          color: outlineVariant,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: size.width * 0.7);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy + 40),
    );
  }

  @override
  bool shouldRepaint(covariant _MemoryFieldPainter old) =>
      old.rotation != rotation ||
      old.breath != breath ||
      old.sweep != sweep ||
      old.orbits != orbits ||
      old.brightness != brightness ||
      old.selectedId != selectedId;
}
