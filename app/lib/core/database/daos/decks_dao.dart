import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'decks_dao.g.dart';

@DriftAccessor(tables: [LocalDecks])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  DecksDao(super.db);

  Future<List<LocalDeck>> allDecks() => select(localDecks).get();

  Future<List<LocalDeck>> decksByNodeId(String nodeId) =>
      (select(localDecks)..where((d) => d.nodeId.equals(nodeId))).get();

  Future<LocalDeck?> deckByExternalId(String externalId) =>
      (select(localDecks)..where((d) => d.externalId.equals(externalId)))
          .getSingleOrNull();

  Future<LocalDeck?> deckById(String id) =>
      (select(localDecks)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<List<LocalDeck>> decksByCategory(String category) =>
      (select(localDecks)
            ..where((d) => d.category.equals(category))
            ..orderBy([(d) => OrderingTerm.asc(d.name)]))
          .get();

  /// Flip a deck's subscription flag. Pure preference write: card rows and
  /// FSRS memory state are untouched, so unsubscribe pauses (never deletes).
  Future<int> setSubscribed({
    required String deckId,
    required bool subscribed,
  }) =>
      (update(localDecks)..where((d) => d.id.equals(deckId)))
          .write(LocalDecksCompanion(isSubscribed: Value(subscribed)));

  Future<void> upsertDeck(LocalDecksCompanion deck) =>
      into(localDecks).insertOnConflictUpdate(deck);

  Future<int> setDeckNodeId({required String deckId, required String nodeId}) =>
      (update(localDecks)..where((d) => d.id.equals(deckId)))
          .write(LocalDecksCompanion(nodeId: Value(nodeId)));
}
