import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'reviews_dao.g.dart';

@DriftAccessor(tables: [CardMemoryStates, ReviewLogs, LocalCards, LocalDecks])
class ReviewsDao extends DatabaseAccessor<AppDatabase> with _$ReviewsDaoMixin {
  ReviewsDao(super.db);

  Future<CardMemoryState?> stateFor(String cardId) =>
      (select(cardMemoryStates)..where((s) => s.cardId.equals(cardId)))
          .getSingleOrNull();

  Future<List<CardMemoryState>> statesForCards(List<String> cardIds) {
    if (cardIds.isEmpty) return Future.value(const []);
    return (select(cardMemoryStates)..where((s) => s.cardId.isIn(cardIds)))
        .get();
  }

  Future<List<CardMemoryState>> dueAt(int unixSeconds, {int limit = 50}) =>
      (select(cardMemoryStates)
            ..where(
              (s) =>
                  s.isNew.equals(false) &
                  s.nextReviewAt.isSmallerOrEqualValue(unixSeconds),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.nextReviewAt)])
            ..limit(limit))
          .get();

  Future<List<CardMemoryState>> newStates({int limit = 20}) =>
      (select(cardMemoryStates)
            ..where((s) => s.isNew.equals(true))
            ..limit(limit))
          .get();

  /// Due states restricted to active cards in subscribed decks. The global
  /// daily session pulls from here so paused (unsubscribed) decks never
  /// flood the rotation. [dueAt] stays for deck-scoped and legacy callers.
  Future<List<CardMemoryState>> dueAtSubscribed(
    int unixSeconds, {
    int limit = 50,
  }) async {
    final query = select(cardMemoryStates).join([
      innerJoin(localCards, localCards.id.equalsExp(cardMemoryStates.cardId)),
      innerJoin(localDecks, localDecks.id.equalsExp(localCards.deckId)),
    ])
      ..where(
        cardMemoryStates.isNew.equals(false) &
            cardMemoryStates.nextReviewAt.isSmallerOrEqualValue(unixSeconds) &
            localCards.isActive.equals(true) &
            localDecks.isSubscribed.equals(true),
      )
      ..orderBy([OrderingTerm.asc(cardMemoryStates.nextReviewAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((row) => row.readTable(cardMemoryStates)).toList();
  }

  /// New (never-reviewed) states restricted to active cards in subscribed
  /// decks, in card sort order. Global-session counterpart of [newStates].
  Future<List<CardMemoryState>> newStatesSubscribed({int limit = 20}) async {
    final query = select(cardMemoryStates).join([
      innerJoin(localCards, localCards.id.equalsExp(cardMemoryStates.cardId)),
      innerJoin(localDecks, localDecks.id.equalsExp(localCards.deckId)),
    ])
      ..where(
        cardMemoryStates.isNew.equals(true) &
            localCards.isActive.equals(true) &
            localDecks.isSubscribed.equals(true),
      )
      ..orderBy([OrderingTerm.asc(localCards.sortOrder)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((row) => row.readTable(cardMemoryStates)).toList();
  }

  Future<void> upsertState(CardMemoryStatesCompanion state) =>
      into(cardMemoryStates).insertOnConflictUpdate(state);

  Future<int> appendLog(ReviewLogsCompanion log) =>
      into(reviewLogs).insert(log);

  Future<List<ReviewLog>> unsyncedLogs({int limit = 100}) => (select(reviewLogs)
        ..where((l) => l.synced.equals(false))
        ..orderBy([(l) => OrderingTerm.asc(l.reviewedAt)])
        ..limit(limit))
      .get();

  /// Full review history for a single card, oldest first. Powers the
  /// per-card retention curve in the Memory section.
  Future<List<ReviewLog>> logsForCard(String cardId) => (select(reviewLogs)
        ..where((l) => l.cardId.equals(cardId))
        ..orderBy([(l) => OrderingTerm.asc(l.reviewedAt)]))
      .get();
}
