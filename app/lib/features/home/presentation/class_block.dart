import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../leaderboard/application/leaderboard_providers.dart';
import '../../shared/widgets/neo/neo_kit.dart';

/// The classroom on Home (Move 9). Cohort members get the MY CLASS card.
/// Everyone else gets one slim "Joining a class?" row instead of class
/// scaffolding, which keeps Home quiet for solo students (persona P2) while
/// still giving a student whose phone already finished onboarding a way to
/// reach the class code screen.
class ClassBlock extends ConsumerWidget {
  const ClassBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myCohortsProvider);
    // No flash of the join row while membership is still loading.
    if (!async.hasValue) return const SizedBox.shrink();
    final cohorts = async.value ?? const [];
    if (cohorts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: _ClassRow(
          label: 'Joining a class? Enter your class code',
          onTap: () => context.push('/leaderboard'),
        ),
      );
    }
    // Honor the class picked on the leaderboard; newest-joined otherwise.
    final selectedId = ref.watch(selectedCohortIdProvider).valueOrNull;
    final cohort = cohorts.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => cohorts.first,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(
          color: neoCardBg(context),
          border: Border.all(color: neoLine(context), width: 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MY CLASS · ${cohort.name.toUpperCase()}',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            _ClassRow(
              label: 'Class messages',
              onTap: () => context.push('/class'),
            ),
            _ClassRow(
              label: 'Leaderboard and live games',
              onTap: () => context.push('/leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: neoLineDim(context)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '→',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
