// lib/core/database/daos/people_dao.dart
//
// The people reference layer: read paths for the congress directory
// (search + filters) and person pages, plus the bulk-replace the seed
// service uses. Content data only; no user state lives here.

import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'people_dao.g.dart';

@DriftAccessor(tables: [People])
class PeopleDao extends DatabaseAccessor<AppDatabase> with _$PeopleDaoMixin {
  PeopleDao(super.db);

  Future<Person?> byId(String id) =>
      (select(people)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Directory query. Filters compose; a null means "any". Sorted by
  /// last-name-ish (name suffix) via ORDER BY name for now.
  Future<List<Person>> directory({
    String? chamber,
    String? state,
    String? party,
    String? query,
    int limit = 600,
  }) {
    final q = select(people);
    if (chamber != null) q.where((t) => t.chamber.equals(chamber));
    if (state != null) q.where((t) => t.state.equals(state));
    if (party != null) q.where((t) => t.party.equals(party));
    if (query != null && query.trim().isNotEmpty) {
      final needle = '%${query.trim()}%';
      q.where((t) => t.name.like(needle) | t.state.like(needle));
    }
    q
      ..orderBy([(t) => OrderingTerm.asc(t.name)])
      ..limit(limit);
    return q.get();
  }

  /// Distinct states present, for the state picker.
  Future<List<String>> states() async {
    final rows = await (selectOnly(people, distinct: true)
          ..addColumns([people.state])
          ..where(people.state.isNotNull()))
        .get();
    final out = [
      for (final r in rows)
        if (r.read(people.state) != null) r.read(people.state)!,
    ]..sort();
    return out;
  }

  Future<int> count() async {
    final c = countAll();
    final row = await (selectOnly(people)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  /// Seed path: replace the whole content table in one transaction.
  Future<void> replaceAll(List<PeopleCompanion> rows) => transaction(() async {
        await delete(people).go();
        await batch((b) => b.insertAll(people, rows));
      });
}
