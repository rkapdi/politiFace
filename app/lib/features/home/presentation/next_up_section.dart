import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../memory/data/memory_service.dart';
import '../../memory/presentation/memory_screen.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/mastery_stars.dart';

final approachingMasteryProvider =
    FutureProvider<List<TopCardEntry>>((ref) async {
  // Refetch after every grade so the list stays current.
  ref.watch(memoryStatsProvider);
  return ref.watch(memoryServiceProvider).approachingMastery();
});

class NextUpSection extends ConsumerWidget {
  const NextUpSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approachingMasteryProvider);
    final cards = async.valueOrNull ?? const <TopCardEntry>[];
    if (cards.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                'ALMOST THERE',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/memory'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                _CardRow(entry: cards[i]),
                if (i != cards.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.entry});
  final TopCardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stabilityLabel = entry.stability >= 10
        ? '${entry.stability.round()} d'
        : '${entry.stability.toStringAsFixed(1)} d';
    final remaining = 5 - entry.level;
    final progressLabel = remaining == 1
        ? '1 review to ★5'
        : '$remaining reviews to ★5';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CardAvatar(
            name: entry.politicianName,
            radius: 22,
            photoUrl: entry.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.politicianName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  progressLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MasteryStars(level: entry.level, size: 14, compact: true),
              const SizedBox(height: 2),
              Text(
                stabilityLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
