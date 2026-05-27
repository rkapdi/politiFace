import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../curriculum/domain/curriculum.dart';

/// The primary home-screen CTA in the chapter-aware world. Replaces the
/// old DailyChallengeCard. Three top-level states:
///
///   - **Active chapter, not played**: "Play today's round" (filled red).
///   - **Active chapter, already played today**: muted "Played" state with
///     "Next round in X" countdown.
///   - **Season complete**: muted "Season complete" with no CTA — new
///     chapters will land later.
///
/// Reads:
///   - [curriculumProvider] for chapter metadata (title, subtitle, days).
///   - [currentChapterProgressProvider] for which chapter the player is on
///     and which day inside it.
///   - [todayRoundPlayedProvider] for the played-today gate.
///
/// Deliberately does NOT watch [dailyRoundControllerProvider] — that
/// would sample + persist today's round just from visiting home, which
/// we want to defer until the user actually taps Play.
class ChapterRoundCard extends ConsumerWidget {
  const ChapterRoundCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(currentChapterProgressProvider);
    final playedAsync = ref.watch(todayRoundPlayedProvider);

    if (curriculumAsync.isLoading || progressAsync.isLoading) {
      return const _PlaceholderCard();
    }
    final curriculum = curriculumAsync.value;
    if (curriculum == null) {
      // Error loading curriculum — hide gracefully (don't block home).
      return const SizedBox.shrink();
    }

    final progress = progressAsync.value;
    if (progress == null) {
      return const _SeasonCompleteCard();
    }

    final chapter = curriculum.chapterById(progress.chapterId);
    if (chapter == null) {
      // Persisted chapterId not in curriculum — should not happen but
      // surface as season-complete rather than crashing home.
      return const _SeasonCompleteCard();
    }

    final played = playedAsync.value ?? false;
    return _ActiveChapterCard(
      chapter: chapter,
      dayInChapter: progress.dayInChapter,
      playedToday: played,
      totalChapters: curriculum.season.totalChapters,
    );
  }
}

// ── Active chapter (the dominant state) ─────────────────────────────────────

class _ActiveChapterCard extends StatelessWidget {
  const _ActiveChapterCard({
    required this.chapter,
    required this.dayInChapter,
    required this.playedToday,
    required this.totalChapters,
  });

  final Chapter chapter;
  final int dayInChapter;
  final bool playedToday;
  final int totalChapters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPct = chapter.days == 0
        ? 0.0
        : ((dayInChapter - (playedToday ? 0 : 1)) / chapter.days)
            .clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: EditorialPalette.ochre),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'CHAPTER ${chapter.order} OF $totalChapters',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (playedToday)
                      Text(
                        'PLAYED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: EditorialPalette.civicGreen,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  chapter.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  chapter.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'DAY $dayInChapter OF ${chapter.days}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progressPct * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    valueColor:
                        const AlwaysStoppedAnimation(EditorialPalette.ochre),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  playedToday
                      ? 'Round complete. Next chapter day unlocks tomorrow.'
                      : "Today's round · 5 cards + 10-question trivia · ≈ 4 min",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: playedToday
                      ? OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/round');
                          },
                          child: const Text('REVIEW TODAY'),
                        )
                      : FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/round');
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text("PLAY TODAY'S ROUND"),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Season complete (terminal but rare) ─────────────────────────────────────

class _SeasonCompleteCard extends StatelessWidget {
  const _SeasonCompleteCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: EditorialPalette.civicGreen),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEASON COMPLETE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: EditorialPalette.civicGreen,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You've walked the season.",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'New chapters land soon — your streak is safe until then.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading placeholder (matches card geometry to avoid layout jump) ───────

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: theme.colorScheme.outlineVariant),
          const Expanded(
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
