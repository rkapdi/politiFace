import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/pending_session_store.dart';
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
    required this.deckId,
    required this.dailyChallengeDate,
    required this.gradeHistory,
    required this.reviewedCardIds,
  });

  final SessionQueue queue;
  final SessionCard? currentCard;
  final int totalPlanned;
  final int completed;
  final int correct;
  final int again;
  final bool isComplete;
  final String? deckId;             // null = global / FSRS-driven
  final String? dailyChallengeDate; // null = not a daily challenge
  final List<int> gradeHistory;     // FSRSGrade.value sequence
  final List<String> reviewedCardIds; // every card graded this session, in order

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
    List<String>? reviewedCardIds,
  }) {
    return SessionState(
      queue: queue,
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      totalPlanned: totalPlanned,
      completed: completed ?? this.completed,
      correct: correct ?? this.correct,
      again: again ?? this.again,
      isComplete: isComplete ?? this.isComplete,
      deckId: deckId,
      dailyChallengeDate: dailyChallengeDate,
      gradeHistory: gradeHistory ?? this.gradeHistory,
      reviewedCardIds: reviewedCardIds ?? this.reviewedCardIds,
    );
  }
}

class SessionController extends AsyncNotifier<SessionState> {
  /// Prevents the same grade tap from being processed twice if the user
  /// double-taps before recordReview() resolves.
  bool _gradeInFlight = false;

  @override
  Future<SessionState> build() async {
    final repo = ref.read(cardReviewRepositoryProvider);
    final pendingStore = ref.read(pendingSessionStoreProvider);
    final deckId = ref.watch(activeSessionDeckIdProvider);
    final challengeDate = ref.watch(activeDailyChallengeDateProvider);

    // Try to restore an in-progress session if one exists and matches the
    // current navigation context. Mismatched pending snapshots get cleared
    // so we never silently launch a different session than the user asked for.
    final pending = await pendingStore.load();
    if (pending != null) {
      final matches = pending.deckId == deckId &&
          pending.dailyChallengeDate == challengeDate;
      if (matches && pending.pendingCardIds.isNotEmpty) {
        return _restore(pending);
      } else if (!matches) {
        await pendingStore.clear();
      }
    }

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
      deckId: deckId,
      dailyChallengeDate: challengeDate,
      gradeHistory: const [],
      reviewedCardIds: const [],
    );
  }

  /// Rebuild the session from a persisted snapshot. Cards are reloaded from
  /// the DB so we pick up any photo/title updates that landed since.
  Future<SessionState> _restore(PendingSessionSnapshot pending) async {
    final cardIds = pending.pendingCardIds;
    final candidates = await ref
        .read(cardReviewRepositoryProvider)
        .loadSessionCandidates(cardIds: cardIds);
    final queue = SessionQueue()
      ..buildSession(
        dueCards: candidates.due,
        newCards: candidates.fresh,
        targetSize: cardIds.length + 1,
      );
    final first = queue.next();
    return SessionState(
      queue: queue,
      currentCard: first,
      totalPlanned: pending.totalPlanned,
      completed: pending.completed,
      correct: pending.correct,
      again: pending.again,
      isComplete: first == null,
      deckId: pending.deckId,
      dailyChallengeDate: pending.dailyChallengeDate,
      gradeHistory: pending.gradeHistory,
      reviewedCardIds: pending.reviewedCardIds,
    );
  }

  Future<void> handleGrade(FSRSGrade grade) async {
    if (_gradeInFlight) return; // ignore concurrent taps
    final current = state.value;
    if (current == null) return;
    final card = current.currentCard;
    if (card == null) return;

    _gradeInFlight = true;
    try {
      await ref.read(cardReviewRepositoryProvider).recordReview(
            cardId: card.cardId,
            grade: grade,
          );
    } catch (e, st) {
      _gradeInFlight = false;
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
    final updatedReviewedIds = [...current.reviewedCardIds, card.cardId];
    final newState = current.copyWith(
      currentCard: next,
      clearCurrentCard: next == null,
      completed: current.completed + 1,
      correct: isAgain ? current.correct : current.correct + 1,
      again: isAgain ? current.again + 1 : current.again,
      isComplete: next == null,
      gradeHistory: updatedHistory,
      reviewedCardIds: updatedReviewedIds,
    );
    state = AsyncData(newState);

    // Persist for resume-after-crash. Best-effort — failures don't block UI.
    try {
      await _persistOrClear(newState);
    } catch (_) {}

    if (next == null) {
      // Session done — recompute node unlocks + persist challenge result.
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

    _gradeInFlight = false;
  }

  Future<void> _persistOrClear(SessionState s) async {
    final store = ref.read(pendingSessionStoreProvider);
    if (s.isComplete || s.currentCard == null) {
      await store.clear();
      return;
    }
    final pending = <String>[
      s.currentCard!.cardId,
      ...s.queue.snapshot().map((c) => c.cardId),
    ];
    await store.save(PendingSessionSnapshot(
      deckId: s.deckId,
      dailyChallengeDate: s.dailyChallengeDate,
      pendingCardIds: pending,
      completed: s.completed,
      correct: s.correct,
      again: s.again,
      totalPlanned: s.totalPlanned,
      gradeHistory: s.gradeHistory,
      reviewedCardIds: s.reviewedCardIds,
      savedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
  }

  void reset() {
    // Discard any persisted snapshot so the next session starts fresh.
    ref.read(pendingSessionStoreProvider).clear();
    ref.invalidateSelf();
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
