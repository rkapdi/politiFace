import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/mastery_stars.dart';
import '../../shared/widgets/state_views.dart';
import '../data/memory_service.dart';

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(ref.watch(databaseProvider));
});

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
      appBar: AppBar(title: const Text('Memory')),
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
        _HeadlineRow(stats: stats),
        const SizedBox(height: 16),
        _SectionTitle('Mastery distribution'),
        _TierDistribution(distribution: stats.tierDistribution),
        const SizedBox(height: 16),
        _SectionTitle('Your strongest cards'),
        ...stats.topCards.map((c) => _TopCardTile(entry: c)),
        const SizedBox(height: 32),
      ],
    );
  }
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
  const _TierDistribution({required this.distribution});

  /// Indices 1..5 are the tier counts; index 0 (unreviewed) is ignored.
  final List<int> distribution;

  @override
  Widget build(BuildContext context) {
    final maxCount = distribution.skip(1).fold<int>(0, (a, b) => b > a ? b : a);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var level = 5; level >= 1; level--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _TierRow(
                    level: level,
                    count: distribution[level],
                    max: maxCount,
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
    required this.max,
  });
  final int level;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max == 0 ? 0.0 : count / max;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: MasteryStars(level: level, size: 14, compact: true),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation(_levelColor(level, theme)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
        return theme.colorScheme.primary;
      case 2:
        return Colors.orange.shade400;
      default:
        return Colors.red.shade300;
    }
  }
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
