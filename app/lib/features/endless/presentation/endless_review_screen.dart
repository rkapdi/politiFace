import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../application/endless_controller.dart';
import '../domain/endless_question.dart';

/// Per-question review of an Endless run. Two read paths:
///   - No [runId]: read live [EndlessState.answers] (just-ended run).
///   - With [runId]: hydrate from the persisted [CompletedRuns] payload so
///     the History tab can deep-link into past runs.
class EndlessReviewScreen extends ConsumerWidget {
  const EndlessReviewScreen({super.key, this.runId});

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
        body: FutureBuilder<List<_ReviewEntry>?>(
          future: _loadFromRunId(ref, runId!),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const AppLoadingView();
            }
            if (snap.hasError || snap.data == null) {
              return AppErrorView(
                title: 'Run unavailable',
                message: 'That run could not be loaded.',
                onRetry: () => Navigator.of(context).pop(),
              );
            }
            return _Body(entries: snap.data!);
          },
        ),
      );
    }

    final async = ref.watch(endlessControllerProvider);
    return Scaffold(
      appBar: appBar,
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load review',
          message: '$e',
          onRetry: () => ref.invalidate(endlessControllerProvider),
        ),
        data: (state) {
          if (state.answers.isEmpty) {
            return const AppEmptyView(
              icon: Icons.fact_check_outlined,
              title: 'Nothing to review yet',
              body: 'Answer a few endless questions, then end the run.',
            );
          }
          final entries = [
            for (final a in state.answers) _ReviewEntry.fromLive(a),
          ];
          return _Body(entries: entries);
        },
      ),
    );
  }

  Future<List<_ReviewEntry>?> _loadFromRunId(
    WidgetRef ref,
    String id,
  ) async {
    final db = ref.read(databaseProvider);
    final row = await db.completedRunsDao.byId(id);
    if (row == null) return null;
    try {
      final raw = jsonDecode(row.payload) as Map<dynamic, dynamic>;
      final answers = (raw['answers'] as List<dynamic>?) ?? const [];
      return [
        for (final a in answers)
          _ReviewEntry.fromPayload(a as Map<dynamic, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.entries});
  final List<_ReviewEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyView(
        icon: Icons.fact_check_outlined,
        title: 'Nothing to review',
        body: 'This run had no answers stored.',
      );
    }
    // Most-recent first matches the order users naturally think about
    // ("what did I just see?").
    final reversed = entries.reversed.toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: reversed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _EntryCard(
          index: entries.length - i,
          entry: reversed[i],
        ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.index, required this.entry});
  final int index;
  final _ReviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        entry.isCorrect ? Colors.green.shade400 : Colors.red.shade400;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '#$index',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                entry.isCorrect ? Icons.check_circle : Icons.cancel,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.isCorrect ? 'CORRECT' : 'WRONG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                entry.modeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CardAvatar(
                  name: entry.correctName,
                  radius: 32,
                  photoUrl: entry.correctPhotoUrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.correctName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      entry.correctTitle,
                      maxLines: 1,
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
          if (!entry.isCorrect && entry.pickedLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You picked: ${entry.pickedLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Unified review-row payload — same shape whether we're reading from the
/// live controller or the persisted CompletedRuns blob. Keeps the
/// presentation layer indifferent to source.
class _ReviewEntry {
  const _ReviewEntry({
    required this.isCorrect,
    required this.modeLabel,
    required this.correctName,
    required this.correctTitle,
    required this.correctPhotoUrl,
    required this.pickedLabel,
  });

  final bool isCorrect;
  final String modeLabel;
  final String correctName;
  final String correctTitle;
  final String? correctPhotoUrl;

  /// The user's pick rendered as the "wrong" line — null when they got it
  /// right. The label is whichever field the mode showed (name for
  /// photo→name; title for photo→title; etc.).
  final String? pickedLabel;

  factory _ReviewEntry.fromLive(dynamic answer) {
    // EndlessAnswer fields, typed dynamic so this file doesn't need to
    // re-import the domain class — `answer.question` and the rest are
    // duck-typed via direct member access.
    final q = answer.question;
    final modeLabel = _modeLabel(q.mode as QuestionMode);
    final showsName = q.mode == QuestionMode.photoToName ||
        q.mode == QuestionMode.titleToWho ||
        q.mode == QuestionMode.nameToPhoto;
    final picked = q.options[answer.pickedIndex];
    final pickedLabel = (answer.isCorrect as bool)
        ? null
        : (showsName ? picked.politicianName as String : picked.title as String);
    return _ReviewEntry(
      isCorrect: answer.isCorrect as bool,
      modeLabel: modeLabel,
      correctName: q.correct.politicianName as String,
      correctTitle: q.correct.title as String,
      correctPhotoUrl: q.correct.photoUrl as String?,
      pickedLabel: pickedLabel,
    );
  }

  factory _ReviewEntry.fromPayload(Map<dynamic, dynamic> m) {
    final mode = QuestionMode.values.firstWhere(
      (v) => v.name == m['mode'],
      orElse: () => QuestionMode.photoToName,
    );
    final pickedIndex = m['pickedIndex'] as int;
    final correctIndex = m['correctIndex'] as int;
    final isCorrect = pickedIndex == correctIndex;
    final showsName = mode == QuestionMode.photoToName ||
        mode == QuestionMode.titleToWho ||
        mode == QuestionMode.nameToPhoto;
    final pickedLabel = isCorrect
        ? null
        : (showsName
            ? m['pickedName'] as String?
            : m['pickedTitle'] as String?);
    return _ReviewEntry(
      isCorrect: isCorrect,
      modeLabel: _modeLabel(mode),
      correctName: m['correctName'] as String? ?? '?',
      correctTitle: m['correctTitle'] as String? ?? '?',
      correctPhotoUrl: m['photoUrl'] as String?,
      pickedLabel: pickedLabel,
    );
  }

  static String _modeLabel(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.photoToName:
        return 'PHOTO → NAME';
      case QuestionMode.nameToPhoto:
        return 'NAME → PHOTO';
      case QuestionMode.titleToWho:
        return 'TITLE → PERSON';
      case QuestionMode.photoToTitle:
        return 'PHOTO → TITLE';
    }
  }
}
