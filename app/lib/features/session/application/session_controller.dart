import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/fsrs_algorithm.dart';
import '../domain/session_queue.dart';

class SessionState {
  const SessionState({
    required this.queue,
    required this.currentCard,
    required this.totalPlanned,
    required this.completed,
    required this.correct,
    required this.again,
    required this.isComplete,
    required this.dailyChallengeDate,
    required this.gradeHistory,
  });

  final SessionQueue queue;
  final SessionCard? currentCard;
  final int totalPlanned;
  final int completed;
  final int correct;
  final int again;
  final bool isComplete;
  final String? dailyChallengeDate; // non-null = daily challenge run
  final List<int> gradeHistory;     // FSRSGrade.value sequence

  double get accuracy =>
      completed == 0 ? 0.0 : correct / completed;

  SessionState copyWith({
    SessionCard? currentCard,
    bool clearCurrentCard = false,
    int? completed,
    int? correct,
    int? again,
    bool? isComplete,
    List<int>? gradeHistory,
  }) {
    return SessionState(
      queue: queue,
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      totalPlanned: totalPlanned,
      completed: completed ?? this.completed,
      correct: correct ?? this.correct,
      again: again ?? this.again,
      isComplete: isComplete ?? this.isComplete,
      dailyChallengeDate: dailyChallengeDate,
      gradeHistory: gradeHistory ?? this.gradeHistory,
    );
  }
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final repo = ref.read(cardReviewRepositoryProvider);
    final deckId = ref.watch(activeSessionDeckIdProvider);
    final challengeDate = ref.watch(activeDailyChallengeDateProvider);

    List<String>? cardIds;
    if (challengeDate != null) {
      final svc = ref.read(dailyChallengeServiceProvider);
      final challenge = await svc.challengeFor(when: DateTime.now());
      cardIds = challenge?.cardIds;
    }

    final candidates = await repo.loadSessionCandidates(
      deckId: deckId,
      cardIds: cardIds,
    );
    final queue = SessionQueue()
      ..buildSession(
        dueCards: candidates.due,
        newCards: candidates.fresh,
        targetSize: 20,
      );
    final first = queue.next();
    final planned = candidates.due.length + candidates.fresh.length;

    return SessionState(
      queue: queue,
      currentCard: first,
      totalPlanned: planned,
      completed: 0,
      correct: 0,
      again: 0,
      isComplete: first == null,
      dailyChallengeDate: challengeDate,
      gradeHistory: const [],
    );
  }

  Future<void> handleGrade(FSRSGrade grade) async {
    final current = state.value;
    if (current == null) return;
    final card = current.currentCard;
    if (card == null) return;

    try {
      await ref.read(cardReviewRepositoryProvider).recordReview(
            cardId: card.cardId,
            grade: grade,
          );
    } catch (e, st) {
      state = AsyncError(e, st);
      return;
    }

    // Force the profile provider to refetch streak/XP.
    ref.read(sessionTickProvider.notifier).state++;
    // Hide the answer for the upcoming card.
    ref.read(cardRevealedProvider.notifier).state = false;

    if (grade == FSRSGrade.again) {
      current.queue.requeueAfterFailure(card);
    }

    final next = current.queue.next();
    final isAgain = grade == FSRSGrade.again;
    final updatedHistory = [...current.gradeHistory, grade.value];
    state = AsyncData(current.copyWith(
      currentCard: next,
      clearCurrentCard: next == null,
      completed: current.completed + 1,
      correct: isAgain ? current.correct : current.correct + 1,
      again: isAgain ? current.again + 1 : current.again,
      isComplete: next == null,
      gradeHistory: updatedHistory,
    ));

    if (next == null) {
      // Session done — recompute node unlocks + persist challenge result.
      // Errors here shouldn't block reaching the summary.
      try {
        await ref.read(nodeUnlockServiceProvider).recalculate();
      } catch (_) {}
      final challengeDate = current.dailyChallengeDate;
      if (challengeDate != null) {
        try {
          await ref.read(dailyChallengeServiceProvider).recordResult(
                date: challengeDate,
                grades: updatedHistory,
              );
        } catch (_) {}
      }
    }
  }

  void reset() => ref.invalidateSelf();
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
