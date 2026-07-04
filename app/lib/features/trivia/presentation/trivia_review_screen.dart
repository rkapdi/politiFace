import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../application/trivia_controller.dart';
import '../domain/trivia_question.dart';

/// Review of a trivia run. Two read paths:
///   - No [runId]: live controller state (just-finished run reached from
///     the result screen).
///   - With [runId]: hydrate from the persisted [CompletedRuns] payload so
///     the History tab can deep-link into past runs.
///
/// Each question is shown with the user's pick, the correct answer (if
/// missed), their confidence, and a one-line calibration insight. A header
/// surfaces aggregate calibration across the three confidence buckets.
///
/// TODO(post-leaderboards): hydrate population stats from Supabase
/// aggregates. Pattern: "You got this right when 73% of players got it
/// wrong" — highest dopamine payoff when you're in the minority of
/// right-answers. The [_PopulationInsight] slot below the personal insight
/// is reserved for this.
class TriviaReviewScreen extends ConsumerWidget {
  const TriviaReviewScreen({super.key, this.runId});

  final String? runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (runId != null) {
      return Scaffold(
        appBar: scaffold.appBar,
        body: FutureBuilder<List<TriviaAnswer>?>(
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
            final answers = snap.data!;
            if (answers.isEmpty) {
              return const AppEmptyView(
                icon: Icons.fact_check_outlined,
                title: 'Nothing to review',
                body: 'This run had no answers stored.',
              );
            }
            return _ReviewBody(answers: answers);
          },
        ),
      );
    }

    final async = ref.watch(triviaControllerProvider);
    return Scaffold(
      appBar: scaffold.appBar,
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load review',
          message: '$e',
          onRetry: () => ref.invalidate(triviaControllerProvider),
        ),
        data: (state) {
          if (state.answers.isEmpty) {
            return const AppEmptyView(
              icon: Icons.fact_check_outlined,
              title: 'Nothing to review yet',
              body: 'Finish a daily trivia run to see your answers here.',
            );
          }
          return _ReviewBody(answers: state.answers);
        },
      ),
    );
  }

  Future<List<TriviaAnswer>?> _loadFromRunId(
    WidgetRef ref,
    String id,
  ) async {
    final db = ref.read(databaseProvider);
    final row = await db.completedRunsDao.byId(id);
    if (row == null) return null;
    try {
      final raw = jsonDecode(row.payload) as List<dynamic>;
      return [
        for (final e in raw)
          _parseAnswer(e as Map<dynamic, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  TriviaAnswer _parseAnswer(Map<dynamic, dynamic> m) {
    final q = m['question'] as Map<dynamic, dynamic>;
    return TriviaAnswer(
      question: TriviaQuestion(
        cardId: q['cardId'] as String,
        format: TriviaFormat.values.firstWhere(
          (f) => f.name == q['format'],
          orElse: () => TriviaFormat.photoToName,
        ),
        prompt: q['prompt'] as String,
        photoUrl: q['photoUrl'] as String?,
        options: (q['options'] as List<dynamic>).cast<String>(),
        correctIndex: q['correctIndex'] as int,
      ),
      answerIndex: m['answerIndex'] as int,
      confidence: TriviaConfidence.values.firstWhere(
        (c) => c.name == m['confidence'],
        orElse: () => TriviaConfidence.guess,
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.answers});
  final List<TriviaAnswer> answers;

  @override
  Widget build(BuildContext context) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _CalibrationHeader(answers: answers),
        const SizedBox(height: 16),
        for (var i = 0; i < answers.length; i++) ...[
          _AnswerCard(index: i, answer: answers[i]),
          if (i != answers.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
}

class _CalibrationHeader extends StatelessWidget {
  const _CalibrationHeader({required this.answers});
  final List<TriviaAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var certainTotal = 0, certainRight = 0;
    var sureTotal = 0, sureRight = 0;
    var guessTotal = 0, guessRight = 0;
    for (final a in answers) {
      switch (a.confidence) {
        case TriviaConfidence.certain:
          certainTotal++;
          if (a.isCorrect) certainRight++;
        case TriviaConfidence.prettySure:
          sureTotal++;
          if (a.isCorrect) sureRight++;
        case TriviaConfidence.guess:
          guessTotal++;
          if (a.isCorrect) guessRight++;
      }
    }

    final headline = _calibrationHeadline(
      certainTotal: certainTotal,
      certainRight: certainRight,
      sureTotal: sureTotal,
      sureRight: sureRight,
      guessTotal: guessTotal,
      guessRight: guessRight,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CALIBRATION',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BucketStat(
                label: '100%',
                total: certainTotal,
                right: certainRight,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _BucketStat(
                label: 'Pretty Sure',
                total: sureTotal,
                right: sureRight,
                color: const Color(0xFF60A5FA),
              ),
              const SizedBox(width: 8),
              _BucketStat(
                label: 'Guess',
                total: guessTotal,
                right: guessRight,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _calibrationHeadline({
  required int certainTotal,
  required int certainRight,
  required int sureTotal,
  required int sureRight,
  required int guessTotal,
  required int guessRight,
}) {
  if (certainTotal >= 2) {
    final pct = (certainRight / certainTotal * 100).round();
    return "You were right $pct% of the time you said '100%'.";
  }
  if (sureTotal >= 2) {
    final pct = (sureRight / sureTotal * 100).round();
    return "You were right $pct% of the time you said 'Pretty Sure'.";
  }
  if (guessTotal >= 1) {
    return 'You guessed your way through ${guessTotal == 1 ? 'a question' : '$guessTotal questions'}.';
  }
  return 'Nicely played.';
}

class _BucketStat extends StatelessWidget {
  const _BucketStat({
    required this.label,
    required this.total,
    required this.right,
    required this.color,
  });
  final String label;
  final int total;
  final int right;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0 : ((right / total) * 100).round();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.45)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0 ? '—' : '$pct%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '$right/$total right',
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

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.index, required this.answer});
  final int index;
  final TriviaAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = answer.question;
    final isCorrect = answer.isCorrect;
    final accent = isCorrect ? Colors.green.shade400 : Colors.red.shade400;

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
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isCorrect ? 'CORRECT' : 'WRONG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _ConfidencePill(confidence: answer.confidence),
            ],
          ),
          const SizedBox(height: 10),
          if (q.photoUrl != null) ...[
            Center(
              child: SizedBox(
                width: 96,
                height: 96,
                child: CardAvatar(
                  name: q.options[q.correctIndex],
                  radius: 48,
                  photoUrl: q.photoUrl,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            q.prompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _AnswerLine(
            label: 'YOU',
            value: q.options[answer.answerIndex],
            accent: accent,
            bold: true,
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 4),
            _AnswerLine(
              label: 'ANSWER',
              value: q.options[q.correctIndex],
              accent: Colors.green.shade400,
              bold: true,
            ),
          ],
          const SizedBox(height: 10),
          _InsightTag(
            insight: _insightFor(
              isCorrect: isCorrect,
              confidence: answer.confidence,
            ),
          ),
          // TODO(post-leaderboards): population stat slot lives here.
          // const _PopulationInsight(),
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.accent,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color accent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.confidence});
  final TriviaConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (confidence) {
      TriviaConfidence.certain => const Color(0xFFEF4444),
      TriviaConfidence.prettySure => const Color(0xFF60A5FA),
      TriviaConfidence.guess => const Color(0xFFF59E0B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        confidence.label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InsightTag extends StatelessWidget {
  const _InsightTag({required this.insight});
  final _Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: insight.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(insight.icon, color: insight.color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: insight.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight {
  const _Insight({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String text;
  final IconData icon;
  final Color color;
}

_Insight _insightFor({
  required bool isCorrect,
  required TriviaConfidence confidence,
}) {
  if (isCorrect && confidence == TriviaConfidence.certain) {
    return const _Insight(
      text: 'Certain and right — calibration validated.',
      icon: Icons.verified_outlined,
      color: Color(0xFF34D399),
    );
  }
  if (isCorrect &&
      (confidence == TriviaConfidence.guess ||
          confidence == TriviaConfidence.prettySure)) {
    return const _Insight(
      text: 'Lucky — you hedged and it landed.',
      icon: Icons.casino_outlined,
      color: Color(0xFF60A5FA),
    );
  }
  if (!isCorrect && confidence == TriviaConfidence.certain) {
    return const _Insight(
      text: 'Overconfident miss — Dunning-Kruger says hi.',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF4444),
    );
  }
  return const _Insight(
    text: "Honest miss — you said you didn't know.",
    icon: Icons.sentiment_neutral_outlined,
    color: Color(0xFFF59E0B),
  );
}
