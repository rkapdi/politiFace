import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../round/application/daily_round_controller.dart';
import '../../session/application/session_controller.dart';

/// Library-style detail sheet for a chapter in the season spine. Opens when
/// the user taps a chapter row. Mirrors the visual language of
/// [BranchInfoSheet] in the Atlas — drag handle, colored top strip,
/// eyebrow + display title, sections, CTA — so the two feel like siblings.
class ChapterInfoSheet extends ConsumerWidget {
  const ChapterInfoSheet({
    super.key,
    required this.chapter,
    required this.entry,
    required this.currentOrder,
    this.scrollController,
  });

  final Chapter chapter;
  final ChapterProgressEntry? entry;

  /// The order of the chapter the player is on right now. Lets the sheet
  /// distinguish "not yet started but next up" (current) from "blocked by
  /// earlier chapters" (locked) without depending on entry presence alone.
  final int currentOrder;

  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required Chapter chapter,
    required ChapterProgressEntry? entry,
    required int currentOrder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => ChapterInfoSheet(
            chapter: chapter,
            entry: entry,
            currentOrder: currentOrder,
            scrollController: controller,
          ),
        );
      },
    );
  }

  bool get _isCompleted => entry?.completedAt != null;
  bool get _isCurrent => chapter.order == currentOrder && !_isCompleted;
  bool get _isLocked => chapter.order > currentOrder;

  Color _statusColor(ThemeData theme) {
    if (_isCompleted) return theme.colorScheme.brandGreen;
    if (_isCurrent) return theme.colorScheme.brandOchre;
    return theme.colorScheme.outlineVariant;
  }

  String get _statusLabel {
    if (_isCompleted) return 'COMPLETED';
    if (_isCurrent) return 'IN PROGRESS';
    return 'LOCKED';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculum = ref.watch(curriculumProvider).valueOrNull;
    final branchIds = curriculum == null
        ? const <String>[]
        : curriculum.branchIdsForChapter(chapter);
    final branches = <Branch>[];
    if (curriculum != null) {
      for (final id in branchIds) {
        final b = curriculum.branchById(id);
        if (b != null) branches.add(b);
      }
    }

    final accent = _statusColor(theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle.
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Status color strip — matches the season spine glyph color.
        Container(
          height: 4,
          color: accent,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Eyebrow: CH N · STATUS
                Row(
                  children: [
                    Text(
                      'CH ${chapter.order}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  chapter.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapter.subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeader(label: 'PROGRESS'),
                const SizedBox(height: 10),
                _ProgressRow(
                  total: chapter.days,
                  filled: _isCompleted
                      ? chapter.days
                      : _isCurrent && entry != null
                          ? (entry!.dayInChapter - 1).clamp(0, chapter.days)
                          : 0,
                  accent: accent,
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _SectionHeader(label: 'TOUCHES'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in branches)
                        _BranchChip(
                          title: b.title,
                          color: _branchColor(b.color),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                _ChapterCta(
                  isCompleted: _isCompleted,
                  isCurrent: _isCurrent,
                  isLocked: _isLocked,
                  onContinue: () {
                    Navigator.of(context).pop();
                    HapticFeedback.lightImpact();
                    context.go('/round');
                  },
                  onReplay: () => _startReplay(context, ref),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Replay a completed chapter as a practice session over its card pool.
  /// Grading rides the normal FSRS pipeline: due cards get real reviews,
  /// same-day repeats route to the practice path, so replaying is always
  /// safe for the memory model (and still earns XP).
  Future<void> _startReplay(BuildContext context, WidgetRef ref) async {
    final sampler = ref.read(chapterContentSamplerProvider);
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final sample = await sampler.sampleCards(
      chapter: chapter,
      count: DailyRoundController.cardsPerRound * 2,
      // Distinct seed salt from today's round so a replay right after the
      // daily round isn't the identical card set.
      dateIso: '$today/replay',
    );
    if (!context.mounted) return;
    if (sample.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No cards available to replay yet.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    HapticFeedback.lightImpact();
    ref.read(activeSessionDeckIdProvider.notifier).state = null;
    ref.read(activeSessionCardIdsProvider.notifier).state =
        sample.cards.map((c) => c.id).toList();
    ref.read(sessionControllerProvider.notifier).reset();
    Navigator.of(context).pop();
    context.go('/session');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.total,
    required this.filled,
    required this.accent,
  });
  final int total;
  final int filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < filled
                    ? accent
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 4),
        ],
        const SizedBox(width: 12),
        Text(
          '$filled/$total',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterCta extends StatelessWidget {
  const _ChapterCta({
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    required this.onContinue,
    required this.onReplay,
  });
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onContinue;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline,
                color: theme.colorScheme.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete earlier chapters to unlock.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (isCompleted) {
      final green = theme.colorScheme.brandGreen;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: green.withOpacity(0.10),
              border: Border.all(color: green.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Completed. Replay anytime — reviews always count.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onReplay,
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            icon: const Icon(Icons.replay_rounded),
            label: const Text(
              'REPLAY THIS CHAPTER',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      );
    }
    // Current chapter — primary CTA into today's round.
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onContinue,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text(
          "CONTINUE TODAY'S ROUND",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Resolve curriculum YAML color tokens to concrete editorial-palette
/// colors. Matches the token vocabulary in `curriculum.dart` Branch.color.
/// `civicLight` is declared in the YAML for State & Local but has no
/// dedicated palette entry — fall through to a muted ink tone so the chip
/// reads as "neutral" rather than crashing.
Color _branchColor(String token) {
  switch (token) {
    case 'ochre':
      return EditorialPalette.ochre;
    case 'civicNavy':
      return EditorialPalette.civicNavy;
    case 'actionRed':
      return EditorialPalette.actionRed;
    case 'civicGreen':
      return EditorialPalette.civicGreen;
    case 'civicLight':
    default:
      return EditorialPalette.inkSubdued;
  }
}
