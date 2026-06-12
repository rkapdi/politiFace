import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'politician_bios_dao.g.dart';

/// CRUD over [PoliticianBios]. Business logic (Wikidata QID lookup, REST
/// fetch, error handling) lives in WikipediaBioService — this DAO just
/// stores rows.
@DriftAccessor(tables: [PoliticianBios])
class PoliticianBiosDao extends DatabaseAccessor<AppDatabase>
    with _$PoliticianBiosDaoMixin {
  PoliticianBiosDao(super.db);

  Future<PoliticianBio?> get(String cardId) => (select(politicianBios)..where((b) => b.cardId.equals(cardId)))
        .getSingleOrNull();

  Future<List<PoliticianBio>> getAll() => select(politicianBios).get();

  /// Reactive watcher for the politician detail screen — refreshes when
  /// the bio backfills (e.g. fetch completes while the screen is open).
  Stream<PoliticianBio?> watch(String cardId) => (select(politicianBios)..where((b) => b.cardId.equals(cardId)))
        .watchSingleOrNull();

  Future<void> upsert(PoliticianBiosCompanion entry) => into(politicianBios).insertOnConflictUpdate(entry);

  /// Wipe all bios (for testing / forced refresh). Not used in app code.
  Future<int> deleteAll() => delete(politicianBios).go();
}
