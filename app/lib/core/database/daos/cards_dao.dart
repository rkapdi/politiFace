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

  /// Cheap count of active cards — used as the denominator of the
  /// Memory tab's brain-strength score.
  Future<int> activeCardCount() async {
    final row = await (selectOnly(localCards)
          ..addColumns([localCards.id.count()])
          ..where(localCards.isActive.equals(true)))
        .getSingle();
    return row.read(localCards.id.count()) ?? 0;
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
