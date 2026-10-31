import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/state_views.dart';
import '../domain/round_state.dart';

/// Review of a daily round. Two read paths:
///   - No [runId]: live controller state (just-finished round from the
///     reveal phase).
///   - With [runId]: hydrate from the persisted [CompletedRuns] payload so
///     the History tab can deep-link into past rounds.
class RoundReviewScreen extends ConsumerWidget {
  const RoundReviewScreen({super.key, this.runId});

  final String? runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBar = AppBar(
      title: const Text('Review'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );

    if (runId != null) {
      return Scaffold(
        appBar: appBar,
        body: FutureBuilder<_RoundReviewData?>(
          future: _loadFromRunId(ref, runId!),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const AppLoadingView();
            }
            if (snap.hasError || snap.data == null) {
              return AppErrorView(
                title: 'Run unavailable',
                message: 'That round could not be loaded.',
                onRetry: () => Navigator.of(context).pop(),
              );
            }
            return _Body(data: snap.data!);
          },
        ),
      );
    }

    final async = ref.watch(dailyRoundControllerProvider);
    return Scaffold(
      appBar: appBar,
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load review',
          message: '$e',
          onRetry: () => ref.invalidate(dailyRoundControllerProvider),
        ),
        data: (state) {
          if (state.cards.isEmpty) {
            return const AppEmptyView(
              icon: Icons.fact_check_outlined,
              title: 'Nothing to review yet',
              body: 'Play today\'s round to see your answers here.',
            );
          }
          return _Body(data: _RoundReviewData.fromState(state));
        },
      ),
    );
  }

  Future<_RoundReviewData?> _loadFromRunId(WidgetRef ref, String id) async {
    final db = ref.read(databaseProvider);
    final row = await db.completedRunsDao.byId(id);
    if (row == null) return null;
    try {
      final raw = jsonDecode(row.payload) as Map<dynamic, dynamic>;
      return _RoundReviewData.fromPayload(raw);
    } catch (_) {
      return null;
    }
  }
}

class _RoundReviewData {
  const _RoundReviewData({
    required this.chapterTitle,
    required this.chapterSubtitle,
    required this.cards,
  });

  final String chapterTitle;
  final String chapterSubtitle;
  final List<RoundCard> cards;

  factory _RoundReviewData.fromState(DailyRoundState s) => _RoundReviewData(
        chapterTitle: s.chapterTitle,
        chapterSubtitle: s.chapterSubtitle,
        cards: s.cards,
      );

  factory _RoundReviewData.fromPayload(Map<dynamic, dynamic> m) {
    final cardMaps =
        (m['cards'] as List<dynamic>?)?.cast<Map<dynamic, dynamic>>() ??
            const [];
    final grades = (m['grades'] as List<dynamic>?) ?? const [];
    final cards = <RoundCard>[];
    for (var i = 0; i < cardMaps.length; i++) {
      final cm = cardMaps[i];
      cards.add(
        RoundCard(
          cardId: cm['cardId'] as String? ?? '',
          prompt: cm['prompt'] as String? ?? '',
          answer: cm['answer'] as String? ?? '',
          politicianName: cm['politicianName'] as String?,
          photoUrl: cm['photoUrl'] as String?,
          grade: i < grades.length ? grades[i] as int? : null,
        ),
      );
    }

    return _RoundReviewData(
      chapterTitle: m['chapterTitle'] as String? ?? 'Round',
      chapterSubtitle: '',
      cards: cards,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final _RoundReviewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradedCards = data.cards.where((c) => c.grade != null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          data.chapterTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (data.chapterSubtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            data.chapterSubtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (gradedCards.isNotEmpty) ...[
          const _SectionHeader(label: 'CARDS'),
          const SizedBox(height: 8),
          for (final c in gradedCards) _CardRow(card: c),
          const SizedBox(height: 18),
        ],
      ],
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
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
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

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card});
  final RoundCard card;

  static const _gradeLabels = ['AGAIN', 'HARD', 'GOOD', 'EASY'];
  static const _gradeColors = [
    Color(0xFFD6242C),
    Color(0xFFC9A05B),
    Color(0xFF2F6F4F),
    Color(0xFF1E2A4A),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = card.grade ?? 0;
    final color = _gradeColors[grade.clamp(0, 3)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _gradeLabels[grade.clamp(0, 3)],
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  card.answer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
