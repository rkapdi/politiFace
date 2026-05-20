import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/endless_engine.dart';
import '../domain/endless_question.dart';

class EndlessState {
  const EndlessState({
    required this.question,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastWasCorrect,
  });

  final EndlessQuestion? question;
  final int totalAnswered;
  final int totalCorrect;
  final int currentStreak;
  final int bestStreak;

  /// True/false right after grading; null between questions. UI uses this to
  /// flash green/red feedback before the next question loads.
  final bool? lastWasCorrect;

  static const empty = EndlessState(
    question: null,
    totalAnswered: 0,
    totalCorrect: 0,
    currentStreak: 0,
    bestStreak: 0,
    lastWasCorrect: null,
  );

  EndlessState copyWith({
    EndlessQuestion? question,
    bool clearQuestion = false,
    int? totalAnswered,
    int? totalCorrect,
    int? currentStreak,
    int? bestStreak,
    bool? lastWasCorrect,
    bool clearLastWasCorrect = false,
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
    );
  }
}

final endlessEngineProvider = Provider<EndlessEngine>((ref) {
  return EndlessEngine(ref.watch(databaseProvider));
});

class EndlessController extends AsyncNotifier<EndlessState> {
  @override
  Future<EndlessState> build() async {
    final q = await ref.read(endlessEngineProvider).nextQuestion();
    return EndlessState.empty.copyWith(question: q);
  }

  Future<void> answer(int optionIndex) async {
    final s = state.value;
    if (s == null || s.question == null) return;
    if (s.lastWasCorrect != null) return; // already answered, awaiting next

    final correct = optionIndex == s.question!.correctIndex;
    final newStreak = correct ? s.currentStreak + 1 : 0;
    state = AsyncData(s.copyWith(
      totalAnswered: s.totalAnswered + 1,
      totalCorrect: s.totalCorrect + (correct ? 1 : 0),
      currentStreak: newStreak,
      bestStreak: newStreak > s.bestStreak ? newStreak : s.bestStreak,
      lastWasCorrect: correct,
    ));
  }

  /// Load the next question and clear the feedback flash.
  Future<void> advance() async {
    final s = state.value;
    if (s == null) return;
    final q = await ref.read(endlessEngineProvider).nextQuestion();
    state = AsyncData(s.copyWith(
      question: q,
      clearLastWasCorrect: true,
    ));
  }

  void reset() => ref.invalidateSelf();
}

final endlessControllerProvider =
    AsyncNotifierProvider<EndlessController, EndlessState>(
  EndlessController.new,
);
