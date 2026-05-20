import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'decks_dao.g.dart';

@DriftAccessor(tables: [LocalDecks])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  DecksDao(AppDatabase db) : super(db);

  Future<List<LocalDeck>> allDecks() => select(localDecks).get();

  Future<List<LocalDeck>> decksByNodeId(String nodeId) {
    return (select(localDecks)..where((d) => d.nodeId.equals(nodeId))).get();
  }

  Future<void> upsertDeck(LocalDecksCompanion deck) {
    return into(localDecks).insertOnConflictUpdate(deck);
  }

  Future<int> setDeckNodeId({required String deckId, required String nodeId}) {
    return (update(localDecks)..where((d) => d.id.equals(deckId)))
        .write(LocalDecksCompanion(nodeId: Value(nodeId)));
  }
}
