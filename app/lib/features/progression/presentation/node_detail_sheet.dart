import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../session/application/session_controller.dart';
import '../application/progression_map_data.dart';
import '../domain/node_state.dart';
import '../domain/tier_mastery.dart';

/// Bottom sheet shown when the user taps a real node on [OrgChartMap].
/// Lists the node's decks grouped by tier (1 = recognition, 2 = understanding,
/// 3 = mastery) with state-aware Start/Continue/Mastered actions per tier.
/// Tier T is locked until tier T-1 is mastered.
class NodeDetailSheet extends ConsumerWidget {
  const NodeDetailSheet({super.key, required this.nodeId});

  final String nodeId;

  /// Convenience launcher — handles the modal scaffolding so callers just
  /// say `NodeDetailSheet.show(context, ref, nodeId)`.
  static Future<void> show(BuildContext context, String nodeId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NodeDetailSheet(nodeId: nodeId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(progressionMapDataProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: mapAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load node: $e'),
            ),
            data: (model) {
              final node = model.nodes[nodeId];
              if (node == null || node.govNode == null) {
                return const _Empty(
                  message: 'Node not found.',
                );
              }
              return _NodeSheetBody(
                node: node,
                state: model.snapshot.stateFor(nodeId),
                tiers: model.snapshot.tiersFor(nodeId),
                scrollController: scrollController,
              );
            },
          ),
        );
      },
    );
  }
}

class _NodeSheetBody extends ConsumerWidget {
  const _NodeSheetBody({
    required this.node,
    required this.state,
    required this.tiers,
    required this.scrollController,
  });

  final ProgressionMapNode node;
  final NodeState state;
  final List<TierMasteryStatus> tiers;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gov = node.govNode!;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Drag handle.
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            _BranchChip(color: node.branchColor, label: _branchLabel(gov.nodeType)),
            const Spacer(),
            _StatePill(state: state, branchColor: node.branchColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(gov.name, style: theme.textTheme.headlineSmall),
        if (gov.description != null && gov.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            gov.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        for (var i = 0; i < tiers.length; i++) ...[
          _TierRow(
            nodeId: node.id,
            tier: tiers[i],
            previousTierMastered:
                i == 0 ? true : tiers[i - 1].isMastered,
            branchColor: node.branchColor,
          ),
          if (i != tiers.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _branchLabel(String nodeType) {
    switch (nodeType) {
      case 'executive':
        return 'EXECUTIVE';
      case 'legislature':
        return 'LEGISLATIVE';
      case 'judicial':
        return 'JUDICIAL';
      case 'political-party':
        return 'POLITICAL';
      default:
        return nodeType.toUpperCase();
    }
  }
}

class _TierRow extends ConsumerWidget {
  const _TierRow({
    required this.nodeId,
    required this.tier,
    required this.previousTierMastered,
    required this.branchColor,
  });

  final String nodeId;
  final TierMasteryStatus tier;
  final bool previousTierMastered;
  final Color branchColor;

  static const _tierNames = ['Recognition', 'Understanding', 'Mastery'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tierIdx = (tier.tier - 1).clamp(0, _tierNames.length - 1);
    final tierName = _tierNames[tierIdx];
    final isLocked = !previousTierMastered;
    final isEmpty = tier.isEmpty;
    final isMastered = tier.isMastered;

    final statusLabel = isEmpty
        ? 'Coming soon'
        : isMastered
            ? 'Mastered'
            : '${tier.passingCards} / ${tier.totalCards} demonstrated';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isMastered
            ? Border.all(color: branchColor.withOpacity(0.7), width: 1.4)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Tier ${tier.tier}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                statusLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isMastered
                      ? branchColor
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tierName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar (soft, continuous; fills before tier flips mastered).
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isEmpty ? 0 : tier.progressFraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
              valueColor: AlwaysStoppedAnimation(
                isMastered
                    ? branchColor
                    : branchColor.withOpacity(0.85),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TierActionButton(
            nodeId: nodeId,
            tier: tier,
            isLocked: isLocked,
            branchColor: branchColor,
          ),
        ],
      ),
    );
  }
}

class _TierActionButton extends ConsumerWidget {
  const _TierActionButton({
    required this.nodeId,
    required this.tier,
    required this.isLocked,
    required this.branchColor,
  });

  final String nodeId;
  final TierMasteryStatus tier;
  final bool isLocked;
  final Color branchColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tier.isEmpty) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('No content yet'),
      );
    }
    if (isLocked) {
      return OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Master the previous tier first.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.lock_outline, size: 18),
        label: const Text('Locked'),
      );
    }
    if (tier.isMastered) {
      return FilledButton.tonal(
        onPressed: () => _startTier(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: branchColor.withOpacity(0.18),
          foregroundColor: branchColor,
        ),
        child: const Text('Practice'),
      );
    }
    final label = tier.passingCards > 0 ? 'Continue' : 'Start';
    return FilledButton(
      onPressed: () => _startTier(context, ref),
      style: FilledButton.styleFrom(
        backgroundColor: branchColor,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Future<void> _startTier(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    // Pick the first deck attached to this node + tier — for v1 each tier
    // has at most one deck. If we ever ship multiple decks per tier we'll
    // surface them as a chooser in the sheet.
    final decks = await (db.select(db.localDecks)
          ..where((d) =>
              d.nodeId.equals(nodeId) & d.tierOrder.equals(tier.tier))
          ..orderBy([(d) => drift.OrderingTerm.asc(d.id)]))
        .get();
    if (decks.isEmpty) return;
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close the sheet first
    ref.read(activeSessionDeckIdProvider.notifier).state = decks.first.id;
    ref.read(activeSessionCardIdsProvider.notifier).state = null;
    ref.invalidate(sessionControllerProvider);
    GoRouter.of(context).go('/session');
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, required this.branchColor});
  final NodeState state;
  final Color branchColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final String label;
    late final Color fg;
    late final Color bg;
    switch (state) {
      case NodeState.locked:
        label = 'Locked';
        fg = theme.colorScheme.onSurfaceVariant;
        bg = theme.colorScheme.surfaceContainerHighest;
      case NodeState.available:
        label = 'Available';
        fg = branchColor;
        bg = branchColor.withOpacity(0.15);
      case NodeState.progress:
        label = 'In progress';
        fg = branchColor;
        bg = branchColor.withOpacity(0.18);
      case NodeState.mastered:
        label = 'Mastered';
        fg = Colors.white;
        bg = branchColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      );
}
