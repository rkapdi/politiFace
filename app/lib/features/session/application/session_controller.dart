import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/sync/app_state_sync.dart';
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
  final String? deckId; // null = global / FSRS-driven
  final List<int> gradeHistory; // FSRSGrade.value sequence
  final List<String>
      reviewedCardIds; // every card graded this session, in order

  double get accuracy => completed == 0 ? 0.0 : correct / completed;

  SessionState copyWith({
    SessionCard? currentCard,
    bool clearCurrentCard = false,
    int? completed,
    int? correct,
    int? again,
    bool? isComplete,
    List<int>? gradeHistory,
    List<String>? reviewedCardIds,
  }) =>
      SessionState(
        queue: queue,
        currentCard:
            clearCurrentCard ? null : (currentCard ?? this.currentCard),
        totalPlanned: totalPlanned,
        completed: completed ?? this.completed,
        correct: correct ?? this.correct,
        again: again ?? this.again,
        isComplete: isComplete ?? this.isComplete,
        deckId: deckId,
        gradeHistory: gradeHistory ?? this.gradeHistory,
        reviewedCardIds: reviewedCardIds ?? this.reviewedCardIds,
      );
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
    final cardIds = ref.watch(activeSessionCardIdsProvider);

    // An explicit card list (chapter replay) is always a fresh session —
    // skip restore so a stale snapshot can't hijack what the user asked for.
    // Otherwise try to restore an in-progress session if one exists and
    // matches the current navigation context; mismatched snapshots get
    // cleared so we never silently launch a different session.
    final pending = cardIds == null ? await pendingStore.load() : null;
    if (pending != null) {
      final matches = pending.deckId == deckId;
      if (matches && pending.pendingCardIds.isNotEmpty) {
        return _restore(pending);
      } else if (!matches) {
        await pendingStore.clear();
      }
    }

    final candidates = await repo.loadSessionCandidates(
      deckId: deckId,
      cardIds: cardIds,
    );
    final queue = SessionQueue()
      ..buildSession(
        dueCards: candidates.due,
        newCards: candidates.fresh,
        targetSize: cardIds?.length ?? 20,
        // Explicit card lists must surface every card, including new ones —
        // no every-Nth interleave cap.
        includeAllNew: cardIds != null,
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
      // recordGrade routes to either a real FSRS update or practice mode
      // based on whether the card is actually due — keeps the science layer
      // clean across same-day grinding while game state still ticks.
      await ref.read(cardReviewRepositoryProvider).recordGrade(
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
      // Session done — recompute node unlocks.
      try {
        await ref.read(nodeUnlockServiceProvider).recalculate();
      } catch (_) {}

      // Cross-device sync: free-explore XP settles at session end, so one
      // app_state upsert per completed session (never per grade). isActive
      // is checked first so signed-out and unconfigured builds do nothing.
      final sync = ref.read(syncEngineProvider);
      if (sync.isActive) {
        try {
          final curriculum = await ref.read(curriculumProvider.future);
          await pushAppState(
            db: ref.read(databaseProvider),
            sync: sync,
            curriculum: curriculum,
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
    await store.save(
      PendingSessionSnapshot(
        deckId: s.deckId,
        pendingCardIds: pending,
        completed: s.completed,
        correct: s.correct,
        again: s.again,
        totalPlanned: s.totalPlanned,
        gradeHistory: s.gradeHistory,
        reviewedCardIds: s.reviewedCardIds,
        savedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
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
