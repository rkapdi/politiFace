import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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
  }) {
    return TriviaState(
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      pendingAnswerIndex:
          clearPending ? null : (pendingAnswerIndex ?? this.pendingAnswerIndex),
    );
  }
}

class TriviaController extends AsyncNotifier<TriviaState> {
  @override
  Future<TriviaState> build() async {
    final db = ref.read(databaseProvider);
    final cards = await db.cardsDao.allActiveCards();
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
    state = AsyncData(s.copyWith(
      answers: [...s.answers, answer],
      clearPending: true,
    ));
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
