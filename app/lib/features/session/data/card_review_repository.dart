import 'package:drift/drift.dart' show Value;

import '../../../core/database/drift/app_database.dart';
import '../../profile/data/profile_service.dart';
import '../domain/fsrs_algorithm.dart';
import '../domain/session_queue.dart';
import 'mappers.dart';

class SessionCandidates {
  const SessionCandidates({required this.due, required this.fresh});
  final List<SessionCard> due;
  final List<SessionCard> fresh;
}

/// Whether a grade tap was treated as a real FSRS-updating review or a
/// practice-mode re-grind that left the science layer untouched.
enum GradeMode { review, practice }

class GradeOutcome {
  const GradeOutcome({required this.state, required this.mode});
  final MemoryState state;
  final GradeMode mode;
}

class CardReviewRepository {
  CardReviewRepository(this._db, this._fsrs, this._profile);

  final AppDatabase _db;
  final FSRS _fsrs;
  final ProfileService _profile;

  /// Route a user grade to either the real-FSRS path or the practice path.
  ///
  /// We push to FSRS when the signal is meaningful:
  ///   - the card is brand new (no row yet, or isNew)
  ///   - the grade is `again` (forgetting is real signal regardless of timing)
  ///   - the card is past its scheduled `nextReviewAt` (real spaced retrieval)
  ///
  /// Otherwise it's a same-day re-grind — game state (practice count, last
  /// grade, profile XP) updates, but stability / difficulty / nextReviewAt
  /// stay untouched so we never inflate the science with un-spaced repeats.
  Future<GradeOutcome> recordGrade({
    required String cardId,
    required FSRSGrade grade,
    DateTime? now,
  }) async {
    final reviewAt = now ?? DateTime.now();
    final row = await _db.reviewsDao.stateFor(cardId);
    final isMeaningful = row == null ||
        row.isNew ||
        grade == FSRSGrade.again ||
        reviewAt.millisecondsSinceEpoch ~/ 1000 >= row.nextReviewAt;
    if (isMeaningful) {
      final state = await recordReview(
        cardId: cardId,
        grade: grade,
        now: reviewAt,
      );
      return GradeOutcome(state: state, mode: GradeMode.review);
    }
    final state = await recordPractice(
      cardId: cardId,
      grade: grade,
      now: reviewAt,
    );
    return GradeOutcome(state: state, mode: GradeMode.practice);
  }

  /// Full FSRS update — stability, difficulty, schedule. The hot path for
  /// brand-new cards, scheduled-due cards, and explicit forgettings (Again).
  /// Resets practiceCountSinceReview as a side effect.
  Future<MemoryState> recordReview({
    required String cardId,
    required FSRSGrade grade,
    DateTime? now,
  }) async {
    final reviewAt = now ?? DateTime.now();

    final memoryState = await _db.transaction(() async {
      final row = await _db.reviewsDao.stateFor(cardId);

      final FSRSResult result;
      if (row == null || row.isNew) {
        result = _fsrs.scheduleNew(grade: grade);
      } else {
        final lastReviewedAt = DateTime.fromMillisecondsSinceEpoch(
          row.lastReviewedAt * 1000,
        );
        result = _fsrs.schedule(
          current: memoryStateFromRow(row),
          grade: grade,
          lastReviewedAt: lastReviewedAt,
        );
      }

      await _db.reviewsDao.upsertState(memoryStateToCompanion(
        cardId: cardId,
        result: result,
        grade: grade,
        now: reviewAt,
      ));

      await _db.reviewsDao.appendLog(ReviewLogsCompanion.insert(
        cardId: cardId,
        reviewedAt: reviewAt.millisecondsSinceEpoch ~/ 1000,
        grade: grade.value,
        stability: result.nextState.stability,
        difficulty: result.nextState.difficulty,
        retrievability: result.nextState.retrievability,
        intervalDays: result.intervalDays,
      ));

      return result.nextState;
    });

    // Profile update lives outside the FSRS transaction — gamification state
    // is independent of card-memory state and isn't critical-path.
    await _profile.recordReview(grade: grade, now: reviewAt);

    return memoryState;
  }

  /// Practice mode: bump practice counter, update lastGrade, award XP.
  /// FSRS state (stability, difficulty, nextReviewAt) stays frozen — we're
  /// not lying to the algorithm about a spaced recall we didn't actually
  /// have to do.
  Future<MemoryState> recordPractice({
    required String cardId,
    required FSRSGrade grade,
    DateTime? now,
  }) async {
    final reviewAt = now ?? DateTime.now();
    final row = await _db.reviewsDao.stateFor(cardId);
    if (row == null) {
      // Defensive: should be unreachable (router pushes new cards to FSRS).
      return recordReview(cardId: cardId, grade: grade, now: reviewAt);
    }
    await _db.reviewsDao.upsertState(CardMemoryStatesCompanion(
      cardId: Value(cardId),
      practiceCountSinceReview: Value(row.practiceCountSinceReview + 1),
      lastGrade: Value(grade.value),
    ));
    await _profile.recordReview(grade: grade, now: reviewAt);
    return memoryStateFromRow(row);
  }

  Future<SessionCandidates> loadSessionCandidates({
    int dueLimit = 20,
    int newLimit = 5,
    DateTime? now,
    String? deckId,
    List<String>? cardIds,
  }) async {
    final asOf = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;

    if (cardIds != null) {
      return _loadForCardIds(cardIds);
    }
    if (deckId != null) {
      return _loadForDeck(deckId, asOf, dueLimit, newLimit);
    }

    final dueStates = await _db.reviewsDao.dueAt(asOf, limit: dueLimit);
    final newStates = await _db.reviewsDao.newStates(limit: newLimit);

    final allIds = {
      ...dueStates.map((s) => s.cardId),
      ...newStates.map((s) => s.cardId),
    }.toList();
    final cards = await _db.cardsDao.cardsByIds(allIds);
    final cardsById = {for (final c in cards) c.id: c};

    final due = <SessionCard>[];
    for (final s in dueStates) {
      final card = cardsById[s.cardId];
      if (card == null || !card.isActive) continue;
      due.add(sessionCardFromRows(
        card: card,
        state: s,
        phase: CardPhase.dueReview,
      ));
    }

    final fresh = <SessionCard>[];
    for (final s in newStates) {
      final card = cardsById[s.cardId];
      if (card == null || !card.isActive) continue;
      fresh.add(sessionCardFromRows(
        card: card,
        state: s,
        phase: CardPhase.newCard,
      ));
    }

    return SessionCandidates(due: due, fresh: fresh);
  }

  Future<SessionCandidates> _loadForDeck(
    String deckId,
    int asOf,
    int dueLimit,
    int newLimit,
  ) async {
    final cards = await _db.cardsDao.cardsByDeckId(deckId);
    if (cards.isEmpty) {
      return const SessionCandidates(due: [], fresh: []);
    }
    final ids = cards.map((c) => c.id).toList();
    final states = await _statesByCardIds(ids);
    final statesById = {for (final s in states) s.cardId: s};

    // Deck-scope = study mode: surface every card in the deck regardless of
    // FSRS due-ness. Grading still updates memory state, so the daily
    // FSRS-driven session at / stays accurate.
    final due = <SessionCard>[];
    final fresh = <SessionCard>[];
    for (final card in cards) {
      final state = statesById[card.id];
      if (state == null || state.isNew) {
        if (fresh.length < newLimit) {
          fresh.add(sessionCardFromRows(
            card: card,
            state: state,
            phase: CardPhase.newCard,
          ));
        }
      } else {
        if (due.length < dueLimit) {
          due.add(sessionCardFromRows(
            card: card,
            state: state,
            phase: CardPhase.dueReview,
          ));
        }
      }
    }
    return SessionCandidates(due: due, fresh: fresh);
  }

  Future<List<CardMemoryState>> _statesByCardIds(List<String> ids) async {
    final out = <CardMemoryState>[];
    for (final id in ids) {
      final state = await _db.reviewsDao.stateFor(id);
      if (state != null) out.add(state);
    }
    return out;
  }

  Future<SessionCandidates> _loadForCardIds(List<String> ids) async {
    if (ids.isEmpty) return const SessionCandidates(due: [], fresh: []);
    final cards = await _db.cardsDao.cardsByIds(ids);
    final cardsById = {for (final c in cards) c.id: c};
    final states = await _statesByCardIds(ids);
    final statesById = {for (final s in states) s.cardId: s};
    // Preserve the caller's ordering by walking ids; daily challenge wants
    // its 5 cards in their picked order, not by stability.
    final due = <SessionCard>[];
    final fresh = <SessionCard>[];
    for (final id in ids) {
      final card = cardsById[id];
      if (card == null) continue;
      final state = statesById[id];
      if (state == null || state.isNew) {
        fresh.add(sessionCardFromRows(
          card: card,
          state: state,
          phase: CardPhase.newCard,
        ));
      } else {
        due.add(sessionCardFromRows(
          card: card,
          state: state,
          phase: CardPhase.dueReview,
        ));
      }
    }
    return SessionCandidates(due: due, fresh: fresh);
  }
}
