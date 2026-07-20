import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'cards_dao.g.dart';

@DriftAccessor(tables: [LocalCards, LocalDecks])
class CardsDao extends DatabaseAccessor<AppDatabase> with _$CardsDaoMixin {
  CardsDao(super.db);

  Future<List<LocalCard>> allActiveCards() => (select(localCards)
        ..where((c) => c.isActive.equals(true))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  /// Active face (politician) cards only. The Atlas grid, trivia/endless
  /// MCQ pools, and round fallback sampling must never mix concept cards
  /// into politician name/photo questions or listings.
  Future<List<LocalCard>> allActiveFaceCards() => (select(localCards)
        ..where((c) => c.isActive.equals(true) & c.cardType.equals('face'))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  /// Cheap count of active cards — used as the denominator of the
  /// Memory tab's brain-strength score.
  Future<int> activeCardCount() async {
    final row = await (selectOnly(localCards)
          ..addColumns([localCards.id.count()])
          ..where(localCards.isActive.equals(true)))
        .getSingle();
    return row.read(localCards.id.count()) ?? 0;
  }

  /// Active face cards whose deck is subscribed. THE pool for Endless,
  /// Trivia, and round fallback. Keeps unsubscribed delegation decks
  /// out of every global surface.
  Future<List<LocalCard>> subscribedActiveFaceCards() async {
    final query = select(localCards).join([
      innerJoin(localDecks, localDecks.id.equalsExp(localCards.deckId)),
    ])
      ..where(
        localCards.isActive.equals(true) &
            localCards.cardType.equals('face') &
            localDecks.isSubscribed.equals(true),
      )
      ..orderBy([OrderingTerm.asc(localCards.sortOrder)]);
    final rows = await query.get();
    return rows.map((row) => row.readTable(localCards)).toList();
  }

  /// Count of active cards in subscribed decks: the brain-strength
  /// denominator once delegation decks exist (paused decks must not
  /// deflate the score).
  Future<int> subscribedActiveCardCount() async {
    final countExp = localCards.id.count();
    final query = selectOnly(localCards).join([
      innerJoin(localDecks, localDecks.id.equalsExp(localCards.deckId)),
    ])
      ..addColumns([countExp])
      ..where(
        localCards.isActive.equals(true) & localDecks.isSubscribed.equals(true),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Deactivate cards in [deckIds] whose id is not in [keepCardIds]:
  /// roster departures leave the rotation but keep their FSRS state.
  Future<void> deactivateDeckCardsNotIn({
    required Set<String> deckIds,
    required Set<String> keepCardIds,
  }) =>
      (update(localCards)
            ..where((c) => c.deckId.isIn(deckIds) & c.id.isNotIn(keepCardIds)))
          .write(const LocalCardsCompanion(isActive: Value(false)));

  Future<LocalCard?> cardById(String id) =>
      (select(localCards)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<LocalCard>> cardsByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(localCards)..where((c) => c.id.isIn(ids))).get();
  }

  Future<List<LocalCard>> cardsByDeckId(String deckId) => (select(localCards)
        ..where((c) => c.deckId.equals(deckId) & c.isActive.equals(true))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  Future<void> upsertCard(LocalCardsCompanion card) =>
      into(localCards).insertOnConflictUpdate(card);
}
