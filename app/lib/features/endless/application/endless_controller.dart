import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../data/endless_engine.dart';
import '../domain/endless_answer.dart';
import '../domain/endless_question.dart';

class EndlessState {
  const EndlessState({
    required this.question,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastWasCorrect,
    required this.answers,
    required this.startedAtMs,
    required this.runEnded,
  });

  final EndlessQuestion? question;
  final int totalAnswered;
  final int totalCorrect;
  final int currentStreak;
  final int bestStreak;

  /// True/false right after grading; null between questions. UI uses this to
  /// flash green/red feedback before the next question loads.
  final bool? lastWasCorrect;

  /// Trailing log of answered questions for the in-session review screen.
  /// Capped at [_answerLogCap] entries so the list doesn't grow unbounded
  /// during long runs.
  final List<EndlessAnswer> answers;

  /// Epoch milliseconds when the run started — drives durationMs on the
  /// history row written when the user ends the run.
  final int startedAtMs;

  /// Latched true when [endRun] is called. The result screen reads this to
  /// avoid re-routing the user mid-rebuild.
  final bool runEnded;

  static EndlessState initial() {
    return EndlessState(
      question: null,
      totalAnswered: 0,
      totalCorrect: 0,
      currentStreak: 0,
      bestStreak: 0,
      lastWasCorrect: null,
      answers: const [],
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      runEnded: false,
    );
  }

  EndlessState copyWith({
    EndlessQuestion? question,
    bool clearQuestion = false,
    int? totalAnswered,
    int? totalCorrect,
    int? currentStreak,
    int? bestStreak,
    bool? lastWasCorrect,
    bool clearLastWasCorrect = false,
    List<EndlessAnswer>? answers,
    int? startedAtMs,
    bool? runEnded,
  }) {
    return EndlessState(
      question: clearQuestion ? null : (question ?? this.question),
      totalAnswered: totalAnswered ?? this.totalAnswered,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastWasCorrect: clearLastWasCorrect
          ? null
          : (lastWasCorrect ?? this.lastWasCorrect),
      answers: answers ?? this.answers,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      runEnded: runEnded ?? this.runEnded,
    );
  }
}

final endlessEngineProvider = Provider<EndlessEngine>((ref) {
  return EndlessEngine(ref.watch(databaseProvider));
});

/// Persisted `bestStreak` storage key on the [MetaDao] keystore.
const _bestStreakKey = 'endless_best_streak';

/// Hard cap on how many trailing answers we keep in [EndlessState.answers].
/// 50 covers the longest plausible review without blowing up memory.
const int _answerLogCap = 50;

class EndlessController extends AsyncNotifier<EndlessState> {
  @override
  Future<EndlessState> build() async {
    final db = ref.read(databaseProvider);
    final storedBest =
        int.tryParse(await db.metaDao.get(_bestStreakKey) ?? '') ?? 0;
    final q = await ref.read(endlessEngineProvider).nextQuestion();
    return EndlessState.initial().copyWith(
      question: q,
      bestStreak: storedBest,
    );
  }

  Future<void> answer(int optionIndex) async {
    final s = state.value;
    if (s == null || s.question == null) return;
    if (s.lastWasCorrect != null) return; // already answered, awaiting next
    if (s.runEnded) return;

    final q = s.question!;
    final correct = optionIndex == q.correctIndex;
    final newStreak = correct ? s.currentStreak + 1 : 0;
    final newBest = newStreak > s.bestStreak ? newStreak : s.bestStreak;

    final logged = [
      ...s.answers,
      EndlessAnswer(question: q, pickedIndex: optionIndex),
    ];
    final trimmed = logged.length > _answerLogCap
        ? logged.sublist(logged.length - _answerLogCap)
        : logged;

    state = AsyncData(s.copyWith(
      totalAnswered: s.totalAnswered + 1,
      totalCorrect: s.totalCorrect + (correct ? 1 : 0),
      currentStreak: newStreak,
      bestStreak: newBest,
      lastWasCorrect: correct,
      answers: trimmed,
    ));

    // Persist best streak on every improvement — cheap (single row upsert),
    // and means the chip and result screen always reflect a real value.
    if (newBest > s.bestStreak) {
      unawaited(_persistBestStreak(newBest));
    }
  }

  /// Load the next question and clear the feedback flash.
  Future<void> advance() async {
    final s = state.value;
    if (s == null || s.runEnded) return;
    final q = await ref.read(endlessEngineProvider).nextQuestion();
    state = AsyncData(s.copyWith(
      question: q,
      clearLastWasCorrect: true,
    ));
  }

  /// End the current run, mark it ended, and persist the history row. The
  /// UI navigates to /endless/result after this returns.
  Future<void> endRun() async {
    final s = state.value;
    if (s == null || s.runEnded) return;
    state = AsyncData(s.copyWith(runEnded: true, clearQuestion: true));
    await _persistBestStreak(s.bestStreak);
    await _writeHistoryRow(s);
  }

  void reset() => ref.invalidateSelf();

  Future<void> _persistBestStreak(int best) async {
    try {
      await ref.read(databaseProvider).metaDao.set(_bestStreakKey, '$best');
    } catch (_) {
      // non-fatal: in-memory streak still works for the current run.
    }
  }

  Future<void> _writeHistoryRow(EndlessState s) async {
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.completedRunsDao.insert(CompletedRunsCompanion.insert(
        id: _newRunId('endless'),
        mode: 'endless',
        completedAt: now ~/ 1000,
        durationMs: Value(now - s.startedAtMs),
        score: Value(s.bestStreak),
        correctCount: Value(s.totalCorrect),
        totalCount: Value(s.totalAnswered),
        summary: Value('Streak ${s.bestStreak}'),
        payload: Value(jsonEncode({
          'bestStreak': s.bestStreak,
          'totalAnswered': s.totalAnswered,
          'totalCorrect': s.totalCorrect,
          'answers': [
            for (final a in s.answers)
              {
                'cardId': a.question.correct.id,
                'mode': a.question.mode.name,
                'correctName': a.question.correct.politicianName,
                'correctTitle': a.question.correct.title,
                'photoUrl': a.question.correct.photoUrl,
                'pickedIndex': a.pickedIndex,
                'correctIndex': a.question.correctIndex,
                'pickedName':
                    a.question.options[a.pickedIndex].politicianName,
                'pickedTitle':
                    a.question.options[a.pickedIndex].title,
              },
          ],
        })),
      ));
    } catch (_) {
      // Swallow — history writes never block the end-run flow.
    }
  }

  String _newRunId(String mode) {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final salt = math.Random().nextInt(1 << 32);
    return '${mode}_${epoch}_$salt';
  }
}

final endlessControllerProvider =
    AsyncNotifierProvider<EndlessController, EndlessState>(
  EndlessController.new,
);
