import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../curriculum/data/chapter_deck_progress.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../round/application/daily_round_controller.dart';
import '../../session/application/session_controller.dart';

/// Library-style detail sheet for a chapter in the season spine. Opens when
/// the user taps a chapter row. Mirrors the visual language of
/// [BranchInfoSheet] in the Atlas — drag handle, colored top strip,
/// eyebrow + display title, sections, CTA — so the two feel like siblings.
class ChapterInfoSheet extends ConsumerWidget {
  const ChapterInfoSheet({
    required this.chapter,
    required this.entry,
    required this.currentOrder,
    super.key,
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
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
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
        ),
      );

  bool get _isCompleted => entry?.completedAt != null;
  bool get _isCurrent => chapter.order == currentOrder && !_isCompleted;
  bool get _isLocked => chapter.order > currentOrder;

  Color _statusColor(ThemeData theme) {
    if (_isCompleted) return theme.colorScheme.brandGreen;
    // Text-safe ochre: this color renders the status label text.
    if (_isCurrent) return theme.colorScheme.brandOchreText;
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
    final playedToday =
        ref.watch(todayRoundPlayedProvider).valueOrNull ?? false;
    final reviewRunId = ref.watch(todayRoundRunIdProvider).valueOrNull;

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
                const _SectionHeader(label: 'PROGRESS'),
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
                if (chapter.decks.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionHeader(label: 'DECKS'),
                  const SizedBox(height: 10),
                  _DeckSection(chapterId: chapter.id, isLocked: _isLocked),
                ],
                if (chapter.lessons.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionHeader(label: 'LESSONS'),
                  const SizedBox(height: 10),
                  for (final lesson in chapter.lessons)
                    _LessonRow(
                      lesson: lesson,
                      encountered: _lessonEncountered(lesson),
                    ),
                ],
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionHeader(label: 'TOUCHES'),
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
                  playedToday: playedToday,
                  currentOrder: currentOrder,
                  onContinue: () {
                    Navigator.of(context).pop();
                    HapticFeedback.lightImpact();
                    context.go('/round');
                  },
                  // Today's round is already done — open its review instead of
                  // /round, which would see phase==done and bounce home.
                  onReview: () {
                    Navigator.of(context).pop();
                    HapticFeedback.lightImpact();
                    context.push(
                      reviewRunId != null
                          ? '/round/review?runId=$reviewRunId'
                          : '/round/review',
                    );
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

  /// A lesson is "encountered" once its chapter day has been played:
  /// completed chapters expose everything, the in-progress chapter exposes
  /// days before the current one, locked chapters expose nothing.
  bool _lessonEncountered(Lesson lesson) {
    if (_isCompleted) return true;
    if (_isLocked || entry == null) return false;
    return lesson.day < entry!.dayInChapter;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cards available to replay yet.'),
          duration: Duration(seconds: 3),
        ),
      );
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

/// One lesson title row. Encountered lessons get a check mark and reopen
/// as a readable sheet; future lessons show a day chip and stay locked
/// (no spoilers, and the briefing should be the first read).
class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.encountered});
  final Lesson lesson;
  final bool encountered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = encountered
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: encountered ? () => _read(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              encountered ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: encountered
                  ? theme.colorScheme.brandGreen
                  : theme.colorScheme.outlineVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lesson.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: encountered ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              'DAY ${lesson.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (encountered) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _read(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    lesson.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
              ),
              if (lesson.source != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Source: ${Uri.tryParse(lesson.source!)?.host ?? lesson.source!}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        border: Border.all(color: color.withOpacity(0.55)),
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
    required this.playedToday,
    required this.currentOrder,
    required this.onContinue,
    required this.onReview,
    required this.onReplay,
  });
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final bool playedToday;
  final int currentOrder;
  final VoidCallback onContinue;
  final VoidCallback onReview;
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
            Icon(
              Icons.lock_outline,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Locked. Finish Chapter $currentOrder to unlock this one.',
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
                    'Completed. Replay anytime: reviews always count.',
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
    // Current chapter — review today's round if it's already done, otherwise
    // continue/play it. (Routing to /round when done bounces home.)
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: playedToday ? onReview : onContinue,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        icon: Icon(
          playedToday ? Icons.fact_check_outlined : Icons.play_arrow_rounded,
        ),
        label: Text(
          playedToday ? "REVIEW TODAY'S ROUND" : "CONTINUE TODAY'S ROUND",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Per-deck progress rows: the chapter's constituent decks with studied
/// counts. Locked chapters show names only; planned decks show an
/// IN PRODUCTION chip.
class _DeckSection extends ConsumerWidget {
  const _DeckSection({required this.chapterId, required this.isLocked});
  final String chapterId;
  final bool isLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chapterDeckProgressProvider(chapterId));
    final decks = async.valueOrNull;
    if (decks == null) return const SizedBox(height: 24);
    return Column(
      children: [
        for (final d in decks) _DeckRow(progress: d, isLocked: isLocked),
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.progress, required this.isLocked});
  final ChapterDeckProgress progress;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = progress.ref.planned || !progress.isAvailable;
    final titleColor = planned || isLocked
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.deckName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (planned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'IN PRODUCTION',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!isLocked)
                Text(
                  '${progress.studiedCards} of ${progress.totalCards} studied',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                )
              else
                Text(
                  '${progress.totalCards} cards',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          if (!planned && !isLocked) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.studiedFraction,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  theme.colorScheme.brandOchre,
                ),
              ),
            ),
            if (progress.strongCards > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${progress.strongCards} strong',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.brandGreen,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ],
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
