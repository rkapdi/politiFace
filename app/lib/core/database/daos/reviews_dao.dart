import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'reviews_dao.g.dart';

@DriftAccessor(tables: [CardMemoryStates, ReviewLogs])
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
            ..where((s) =>
                s.isNew.equals(false) &
                s.nextReviewAt.isSmallerOrEqualValue(unixSeconds),)
            ..orderBy([(s) => OrderingTerm.asc(s.nextReviewAt)])
            ..limit(limit))
          .get();

  Future<List<CardMemoryState>> newStates({int limit = 20}) =>
      (select(cardMemoryStates)
            ..where((s) => s.isNew.equals(true))
            ..limit(limit))
          .get();

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
