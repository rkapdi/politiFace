import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../data/trivia_generator.dart';
import '../domain/trivia_question.dart';
import '../domain/trivia_scoring.dart';

/// Top-level state for an in-progress (or just-finished) daily trivia run.
class TriviaState {
  const TriviaState({
    required this.questions,
    required this.answers,
    required this.pendingAnswerIndex,
  });

  /// All 10 questions for the day. Empty list while loading or if the card
  /// pool is too small to generate a run.
  final List<TriviaQuestion> questions;

  /// Answers committed so far — one per question in order. Length grows
  /// from 0 → questions.length as the user plays.
  final List<TriviaAnswer> answers;

  /// When the user has tapped an option but not yet locked in confidence,
  /// the tapped option's index lives here. Drives the two-tap UX:
  /// tap answer → (this gets set) → tap confidence → answer committed.
  /// null = no pending answer (i.e., showing the question for the first
  /// time, or between questions).
  final int? pendingAnswerIndex;

  bool get isLoaded => questions.isNotEmpty;
  bool get isComplete =>
      questions.isNotEmpty && answers.length == questions.length;
  int get currentQuestionIndex => answers.length;
  TriviaQuestion? get currentQuestion =>
      isComplete || !isLoaded ? null : questions[currentQuestionIndex];

  TriviaResult get result => summarize(answers);

  TriviaState copyWith({
    List<TriviaQuestion>? questions,
    List<TriviaAnswer>? answers,
    int? pendingAnswerIndex,
    bool clearPending = false,
  }) => TriviaState(
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      pendingAnswerIndex:
          clearPending ? null : (pendingAnswerIndex ?? this.pendingAnswerIndex),
    );
}

class TriviaController extends AsyncNotifier<TriviaState> {
  @override
  Future<TriviaState> build() async {
    final db = ref.read(databaseProvider);
    final cards = await db.cardsDao.allActiveFaceCards();
    final questions = const TriviaGenerator()
        .generate(date: DateTime.now(), cards: cards);
    return TriviaState(
      questions: questions,
      answers: const [],
      pendingAnswerIndex: null,
    );
  }

  /// Tap an answer option. Doesn't commit — the user still has to pick a
  /// confidence level next. Tapping a different option before confirming
  /// just replaces the pending pick.
  void selectAnswer(int optionIndex) {
    final s = state.value;
    if (s == null || s.isComplete) return;
    state = AsyncData(s.copyWith(pendingAnswerIndex: optionIndex));
  }

  /// Commit the current question with [confidence]. Advances the run.
  void confirmConfidence(TriviaConfidence confidence) {
    final s = state.value;
    if (s == null || s.isComplete) return;
    final pending = s.pendingAnswerIndex;
    final q = s.currentQuestion;
    if (pending == null || q == null) return;
    final answer = TriviaAnswer(
      question: q,
      answerIndex: pending,
      confidence: confidence,
    );
    final nextState = s.copyWith(
      answers: [...s.answers, answer],
      clearPending: true,
    );
    state = AsyncData(nextState);
    if (nextState.isComplete) {
      // Fire-and-forget persistence — failure is non-fatal (the run result
      // is still computed live in memory for the active result screen).
      Future.microtask(() => _persistCompletedRun(nextState));
    }
  }

  Future<void> _persistCompletedRun(TriviaState s) async {
    try {
      final db = ref.read(databaseProvider);
      final result = s.result;
      await db.completedRunsDao.insert(CompletedRunsCompanion.insert(
        id: _newRunId('trivia'),
        mode: 'trivia',
        completedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        score: Value(result.totalScore),
        correctCount: Value(result.correctCount),
        totalCount: Value(result.totalQuestions),
        summary: Value(result.archetype.name),
        payload: Value(jsonEncode(_serializeAnswers(s.answers))),
      ),);
    } catch (_) {
      // Swallow — we never want a history-write to crash the result screen.
    }
  }

  List<Map<String, dynamic>> _serializeAnswers(List<TriviaAnswer> answers) => [
      for (final a in answers)
        {
          'question': {
            'cardId': a.question.cardId,
            'format': a.question.format.name,
            'prompt': a.question.prompt,
            'photoUrl': a.question.photoUrl,
            'options': a.question.options,
            'correctIndex': a.question.correctIndex,
          },
          'answerIndex': a.answerIndex,
          'confidence': a.confidence.name,
        },
    ];

  String _newRunId(String mode) {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final salt = math.Random().nextInt(1 << 32);
    return '${mode}_${epoch}_$salt';
  }

  /// Restart from scratch — used by the result screen's "play tomorrow's"
  /// CTA (currently routes to today's run again since v1 has no per-day
  /// guard yet).
  void reset() {
    ref.invalidateSelf();
  }
}

final triviaControllerProvider =
    AsyncNotifierProvider<TriviaController, TriviaState>(
  TriviaController.new,
);
