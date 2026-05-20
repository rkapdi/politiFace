import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'cards_dao.g.dart';

@DriftAccessor(tables: [LocalCards])
class CardsDao extends DatabaseAccessor<AppDatabase> with _$CardsDaoMixin {
  CardsDao(AppDatabase db) : super(db);

  Future<List<LocalCard>> allActiveCards() {
    return (select(localCards)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<LocalCard?> cardById(String id) {
    return (select(localCards)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<List<LocalCard>> cardsByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(localCards)..where((c) => c.id.isIn(ids))).get();
  }

  Future<List<LocalCard>> cardsByDeckId(String deckId) {
    return (select(localCards)
          ..where((c) => c.deckId.equals(deckId) & c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<void> upsertCard(LocalCardsCompanion card) {
    return into(localCards).insertOnConflictUpdate(card);
  }
}
