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
class MemoryField extends StatefulWidget {
  const MemoryField({super.key, required this.orbits});
  final List<OrbitalCard> orbits;

  @override
  State<MemoryField> createState() => _MemoryFieldState();
}

class _MemoryFieldState extends State<MemoryField>
    with TickerProviderStateMixin {
  late final AnimationController _rotation;
  late final AnimationController _breath;
  late final AnimationController _sweep;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1.0,
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
          ),
        ),
      ),
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
  }) : nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final List<OrbitalCard> orbits;
  final double rotation; // 0..1, repeats (60s)
  final double breath;   // 0..1, repeats (3s)
  final double sweep;    // 0..1, repeats (10s)
  final Brightness brightness;
  final Color primary;
  final Color outlineVariant;
  final int nowSeconds;

  static const _tierColors = <Color>[
    Color(0xFFE57373), // ★1 red
    Color(0xFFFFB74D), // ★2 orange
    Color(0xFF64B5F6), // ★3 blue
    Color(0xFF81C784), // ★4 green
    Color(0xFFFFD54F), // ★5 gold
  ];

  /// Map FSRS stability to an orbital radius factor in [0, 1] (logarithmic so
  /// cards spread out across all tiers).
  double _stabilityRadius(double s) {
    final clamped = s.clamp(0.5, 365.0);
    final log = math.log(clamped + 1) / math.log(366);
    return 0.18 + log * 0.74;
  }

  double _retrievability(OrbitalCard o) {
    if (o.lastReviewedAtUnix == 0) return 1.0;
    final elapsedDays =
        (nowSeconds - o.lastReviewedAtUnix) / 86400.0;
    final s = math.max(0.1, o.stability);
    return 1.0 / (1.0 + elapsedDays / (9.0 * s));
  }

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
      final r = _stabilityRadius(o.stability) * radius;
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

      final color = _tierColors[(o.level - 1).clamp(0, 4)];
      _drawOrb(canvas, pos, color, pulse, o.stability, sweepBoost);
      _drawRetrievabilityArc(canvas, pos, color, _retrievability(o), pulse, o.stability);
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
      final r = _stabilityRadius(_stabilityForTierStart(tier)) * radius;
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
  ) {
    final base = 4.0 + math.log(stability.clamp(0.5, 365)) * 0.6;
    final r = base * pulse;

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
      old.brightness != brightness;
}
