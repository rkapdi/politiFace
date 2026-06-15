import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/mastery_stars.dart';
import '../../shared/widgets/state_views.dart';
import '../data/memory_service.dart';
import 'memory_field.dart';

final memoryServiceProvider = Provider<MemoryService>((ref) => MemoryService(ref.watch(databaseProvider)));

final memoryStatsProvider = FutureProvider<MemoryStats>((ref) async {
  // Refetch after every grade so stats stay current.
  ref.watch(sessionTickProvider);
  return ref.watch(memoryServiceProvider).load();
});

class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memoryStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/memory/history'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load stats',
          message: '$e',
          onRetry: () => ref.invalidate(memoryStatsProvider),
        ),
        data: (stats) => _MemoryView(stats: stats),
      ),
    );
  }
}

class _MemoryView extends StatelessWidget {
  const _MemoryView({required this.stats});
  final MemoryStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.totalReviewed == 0) {
      return const AppEmptyView(
        icon: Icons.memory_outlined,
        title: 'No memory data yet',
        body: "Review a few cards and we'll show you how your memory is "
            'growing.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _BrainStrengthHero(stats: stats),
        const SizedBox(height: 8),
        _HeadlineRow(stats: stats),
        const SizedBox(height: 8),
        const _SectionTitle('Memory field'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MemoryField(
            orbits: stats.orbits,
            onCardTap: (id) => context.push('/memory/card/$id'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _FieldLegend(),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Mastery distribution'),
        _TierDistribution(stats: stats),
        const SizedBox(height: 16),
        const _SectionTitle('Your strongest cards'),
        ...stats.topCards.map((c) => _TopCardTile(entry: c)),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _FieldLegend extends StatelessWidget {
  const _FieldLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      "Each dot is a card you've reviewed. Closer to the core = sooner to "
      'forget. Tap a dot to see its memory curve; long-press to peek.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Hero strip above the headline stats — shows the brain-strength score
/// (0-100), a maturation stage label, and one line of aspirational copy.
/// Animates the score from 0 → current on first mount so the moment
/// reads like a level-up rather than a stale dashboard tile.
class _BrainStrengthHero extends StatelessWidget {
  const _BrainStrengthHero({required this.stats});
  final MemoryStats stats;

  Color _stageColor(BrainStage stage) {
    switch (stage) {
      case BrainStage.forming:
        return const Color(0xFFE57373); // soft red — early growth
      case BrainStage.crystallizing:
        return const Color(0xFF60A5FA); // blue — taking shape
      case BrainStage.solidifying:
        return const Color(0xFF34D399); // green — locking in
      case BrainStage.mastered:
        return const Color(0xFFFFC107); // gold — long-term
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = stats.brainStage;
    final color = _stageColor(stage);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Row(
          children: [
            _StrengthRing(value: stats.brainStrength, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BRAIN STRENGTH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stage.label.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage.copy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthRing extends StatelessWidget {
  const _StrengthRing({required this.value, required this.color});
  final double value;  // 0..100
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 100)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: color,
            background: theme.colorScheme.surfaceContainerHigh,
          ),
          child: SizedBox(
            width: 84,
            height: 84,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${animated.round()}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.background,
  });

  final double value;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    const strokeWidth = 6.0;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = background;
    canvas.drawCircle(center, radius, bg);

    final sweep = (value.clamp(0, 100) / 100) * 2 * 3.141592653589793;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.background != background;
}

class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow({required this.stats});
  final MemoryStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeadlineStat(
                value: '${stats.totalReviewed}',
                label: 'Cards practiced',
                color: theme.colorScheme.primary,
              ),
              _HeadlineStat(
                value: '${stats.masteredCount}',
                label: 'Mastered',
                color: const Color(0xFFFFC107),
              ),
              _HeadlineStat(
                value: stats.avgStabilityDays >= 10
                    ? stats.avgStabilityDays.round().toString()
                    : stats.avgStabilityDays.toStringAsFixed(1),
                label: 'Avg memory (days)',
                color: Colors.green.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TierDistribution extends StatelessWidget {
  const _TierDistribution({required this.stats});
  final MemoryStats stats;

  /// FSRS stability range per tier — matches masteryLevelFromStability.
  static const _tierRanges = <int, ({double lo, double hi})>{
    1: (lo: 0, hi: 3),
    2: (lo: 3, hi: 7),
    3: (lo: 7, hi: 14),
    4: (lo: 14, hi: 30),
    5: (lo: 30, hi: 90), // open-ended, capped for visualization
  };

  @override
  Widget build(BuildContext context) {
    // Bucket the orbital cards by tier so each row has its own list.
    final byTier = <int, List<OrbitalCard>>{};
    for (final o in stats.orbits) {
      byTier.putIfAbsent(o.level, () => []).add(o);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              for (var level = 5; level >= 1; level--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _TierRow(
                    level: level,
                    count: stats.tierDistribution[level],
                    range: _tierRanges[level]!,
                    cards: byTier[level] ?? const [],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.level,
    required this.count,
    required this.range,
    required this.cards,
  });

  final int level;
  final int count;
  final ({double lo, double hi}) range;
  final List<OrbitalCard> cards;

  /// Cards whose stability is ≥ 75% of the way through their tier — about
  /// to graduate to the next.
  int get _readyToAdvance {
    if (level == 5) return 0; // already top tier
    final threshold = range.lo + (range.hi - range.lo) * 0.75;
    return cards.where((c) => c.stability >= threshold).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _levelColor(level, theme);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: MasteryStars(level: level, size: 13, compact: true),
        ),
        Expanded(
          child: _TierTrack(
            level: level,
            range: range,
            cards: cards,
            color: color,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (_readyToAdvance > 0)
                Text(
                  '$_readyToAdvance ready →',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _levelColor(int level, ThemeData theme) {
    switch (level) {
      case 5:
        return const Color(0xFFFFC107);
      case 4:
        return Colors.green.shade400;
      case 3:
        return Colors.blue.shade400;
      case 2:
        return Colors.orange.shade400;
      default:
        return Colors.red.shade300;
    }
  }
}

/// Renders a tier's background bar plus a dot per card positioned along it
/// to show where the card sits within the tier's stability range. Cards
/// near the right edge are "about to graduate" to the next tier.
class _TierTrack extends StatelessWidget {
  const _TierTrack({
    required this.level,
    required this.range,
    required this.cards,
    required this.color,
    required this.backgroundColor,
  });

  final int level;
  final ({double lo, double hi}) range;
  final List<OrbitalCard> cards;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 22,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          painter: _TrackPainter(
            level: level,
            range: range,
            cards: cards,
            color: color,
            background: backgroundColor,
            entrance: t,
          ),
          size: const Size.fromHeight(22),
        ),
      ),
    );
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.level,
    required this.range,
    required this.cards,
    required this.color,
    required this.background,
    required this.entrance,
  });

  final int level;
  final ({double lo, double hi}) range;
  final List<OrbitalCard> cards;
  final Color color;
  final Color background;
  final double entrance; // 0..1 entrance tween

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 3, size.width, 6),
      radius,
    );
    canvas.drawRRect(track, Paint()..color = background);

    // Promotion zone — soft tinted shading in the upper 25% so the user can
    // always see where "about to advance" lives, even on empty tiers. Skip
    // for ★5 which has no next tier.
    if (level != 5) {
      final zoneRect = Rect.fromLTWH(
        size.width * 0.75,
        size.height / 2 - 5,
        size.width * 0.25,
        10,
      );
      final zonePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(zoneRect.left, 0),
          Offset(zoneRect.right, 0),
          [color.withOpacity(0.06), color.withOpacity(0.22)],
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(zoneRect, radius),
        zonePaint,
      );
      // 75% threshold marker.
      final x75 = size.width * 0.75;
      canvas.drawLine(
        Offset(x75, size.height / 2 - 7),
        Offset(x75, size.height / 2 + 7),
        Paint()
          ..color = color.withOpacity(0.35)
          ..strokeWidth = 1.0,
      );
    }

    if (cards.isEmpty) return;

    // Compute (x, y) per card with vertical jitter to keep overlapping dots
    // visible. Sort by progress so we process left-to-right; if a candidate
    // dot would land inside another dot's footprint, deflect it up or down.
    final dotPaint = Paint()..color = color;
    final ringPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final sorted = [...cards]..sort((a, b) => a.stability.compareTo(b.stability));
    final placed = <Offset>[];
    const dotR = 4.0;
    const collisionR = dotR * 2.4;
    final maxJitter = (size.height / 2) - dotR - 1;
    for (final c in sorted) {
      final raw = (c.stability - range.lo) / (range.hi - range.lo);
      final progress = raw.clamp(0.0, 1.0);
      final x = progress * size.width * entrance;
      var y = size.height / 2;
      // Start from base y; alternate up/down with growing offset until no
      // overlap. Cap by track height.
      for (var step = 1; step < 6; step++) {
        final collides = placed.any((p) {
          final dx = p.dx - x;
          final dy = p.dy - y;
          return (dx * dx + dy * dy) < (collisionR * collisionR);
        });
        if (!collides) break;
        final sign = step.isOdd ? 1 : -1;
        final magnitude = ((step + 1) ~/ 2) * 5.0;
        y = (size.height / 2) + sign * magnitude.clamp(0.0, maxJitter);
      }
      placed.add(Offset(x, y));
      canvas.drawCircle(Offset(x, y), 6, ringPaint);
      canvas.drawCircle(Offset(x, y), dotR, dotPaint);
      canvas.drawCircle(
        Offset(x - 1, y - 1),
        1.2,
        Paint()..color = Colors.white.withOpacity(0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.cards != cards ||
      old.color != color ||
      old.entrance != entrance;
}

class _TopCardTile extends StatelessWidget {
  const _TopCardTile({required this.entry});
  final TopCardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysLabel = entry.stability >= 10
        ? '${entry.stability.round()} d'
        : '${entry.stability.toStringAsFixed(1)} d';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onTap: () => context.push('/memory/card/${entry.id}'),
        leading: CardAvatar(
          name: entry.politicianName,
          radius: 22,
          photoUrl: entry.photoUrl,
        ),
        title: Text(
          entry.politicianName,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MasteryStars(level: entry.level, size: 14, compact: true),
            const SizedBox(height: 2),
            Text(
              daysLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
