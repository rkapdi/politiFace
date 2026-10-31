import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../benchmark/domain/benchmark.dart';
import '../domain/round_state.dart';

/// Reveal phase of the daily round: the day-complete summary, with a review
/// link and the action that advances the chapter.
class RoundRevealPhase extends ConsumerWidget {
  const RoundRevealPhase({
    required this.state,
    required this.onDone,
    super.key,
  });

  final DailyRoundState state;
  final VoidCallback onDone;

  void _onDone(WidgetRef ref) {
    HapticFeedback.lightImpact();
    ref.read(soundServiceProvider).play(SoundEffect.complete);
    onDone();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewed = state.cards.where((c) => c.grade != null).length;
    // Grades run 0..3; Good and Easy count as recalled.
    final recalled = state.cards.any((c) => (c.grade ?? 0) >= 2);
    // A national stat keyed to the chapter just played, shown only when the
    // player recalled at least one card, so it reads as encouragement.
    final benchmarks = ref.watch(benchmarksProvider).valueOrNull;
    final benchmark = (benchmarks != null && recalled)
        ? benchmarks.forChapter(state.chapterId, dateIso: state.dateIso)
        : null;

    return SafeArea(
      // Scrollable with fixed gaps so content never clips on short screens;
      // the bottom padding keeps the last CTA clear of the home indicator.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChapterCompletionStrip(state: state),
            const SizedBox(height: 32),
            Center(
              child: Icon(
                Icons.check_circle_rounded,
                size: 88,
                color: theme.colorScheme.brandGreen,
                semanticLabel: 'Day complete',
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    duration: 520.ms,
                    curve: Curves.elasticOut,
                  )
                  .fade(duration: 300.ms),
            ),
            const SizedBox(height: 16),
            Text(
              reviewed == 1 ? '1 card reviewed' : '$reviewed cards reviewed',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 240.ms, duration: 360.ms),
            const SizedBox(height: 6),
            Text(
              'Your memory schedule is updated.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 400.ms, duration: 360.ms),
            if (benchmark != null) ...[
              const SizedBox(height: 24),
              _BenchmarkCallout(benchmark: benchmark)
                  .animate()
                  .fade(delay: 560.ms, duration: 420.ms),
            ],
            const SizedBox(height: 24),
            if (state.isFinalDay)
              _ChapterCompleteBanner(
                chapterTitle: state.chapterTitle,
                nextChapterTitle: state.nextChapterTitle,
              ),
            FilledButton.icon(
              onPressed: () => _onDone(ref),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/round/review');
              },
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Chapter 2 · Day 2 of 3 complete" strip above the summary.
class _ChapterCompletionStrip extends StatelessWidget {
  const _ChapterCompletionStrip({required this.state});
  final DailyRoundState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(height: 3, color: EditorialPalette.ochre),
        const SizedBox(height: 10),
        Text(
          'CHAPTER ${state.chapterTitle.toUpperCase()} · '
          'DAY ${state.dayInChapter} OF ${state.daysInChapter} COMPLETE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// "Did you know" stat block on the reveal — a national survey figure for
/// the chapter just played, plus a short encouragement and the attribution.
class _BenchmarkCallout extends StatelessWidget {
  const _BenchmarkCallout({required this.benchmark});
  final Benchmark benchmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: EditorialPalette.ochre.withOpacity(0.10),
        border: Border.all(color: EditorialPalette.ochre.withOpacity(0.5)),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          Text(
            'DID YOU KNOW',
            style: theme.textTheme.labelSmall?.copyWith(
              // Text-safe ochre; the plain accent fails AA on light paper.
              color: theme.colorScheme.brandOchreText,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            benchmark.stat,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            benchmark.youLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            benchmark.attribution,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shown only on a chapter's final day: the unlock moment that makes the
/// season feel sequential instead of silently rolling over.
class _ChapterCompleteBanner extends StatelessWidget {
  const _ChapterCompleteBanner({
    required this.chapterTitle,
    required this.nextChapterTitle,
  });
  final String chapterTitle;
  final String? nextChapterTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    final body = nextChapterTitle != null
        ? 'You closed out $chapterTitle. $nextChapterTitle unlocks with tomorrow\'s round.'
        : 'You closed out $chapterTitle. That was the final chapter of the season.';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: green.withOpacity(0.10),
        border: Border.all(color: green.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHAPTER COMPLETE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: green,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
