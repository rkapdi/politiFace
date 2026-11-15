import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'meta_dao.g.dart';

@DriftAccessor(tables: [AppMeta])
class MetaDao extends DatabaseAccessor<AppDatabase> with _$MetaDaoMixin {
  MetaDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(appMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      into(appMeta).insertOnConflictUpdate(
        AppMetaCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (delete(appMeta)..where((m) => m.key.equals(key))).go();

  /// Every row whose key starts with [prefix], as key -> value. The prefix
  /// is compared literally (no wildcard meaning for % or _).
  Future<Map<String, String>> withPrefix(String prefix) async {
    final rows = await customSelect(
      'SELECT "key", "value" FROM app_meta WHERE substr("key", 1, ?1) = ?2',
      variables: [
        Variable.withInt(prefix.length),
        Variable.withString(prefix),
      ],
      readsFrom: {appMeta},
    ).get();
    return {
      for (final r in rows) r.read<String>('key'): r.read<String>('value'),
    };
  }

  /// Removes [key] only while it still holds exactly [value], so a holder
  /// can give back what it claimed without ever deleting someone else's
  /// newer claim.
  Future<void> removeIfValue(String key, String value) =>
      (delete(appMeta)..where((m) => m.key.equals(key) & m.value.equals(value)))
          .go();

  /// Atomically claims [key] as a stamp.
  ///
  /// The stored value always begins with an integer (a millisecond stamp),
  /// optionally followed by `|owner`. The claim succeeds when no row
  /// exists, or when the existing row's leading integer is below
  /// [staleBelow] (an expired lease, a dedupe entry past its cooldown).
  ///
  /// With [requireKey] / [requireValue] the claim additionally succeeds
  /// only while that other row still holds exactly that value: a sweep
  /// passes its own lease here, so a sent-key is recorded only by the
  /// sweep that still holds the lock.
  ///
  /// It is ONE SQLite statement, so the check and the write cannot be
  /// interleaved by another caller: not by another future on this
  /// connection, and not by the background isolate's separate connection
  /// to the same file (SQLite serializes writers). Returns whether this
  /// caller won.
  Future<bool> claimStamp(
    String key, {
    required String value,
    required int staleBelow,
    String? requireKey,
    String? requireValue,
  }) async {
    assert(
      (requireKey == null) == (requireValue == null),
      'requireKey and requireValue go together',
    );
    final guarded = requireKey != null;
    final changed = await customUpdate(
      'INSERT INTO app_meta ("key", "value") '
      'SELECT ?1, ?2 WHERE ${guarded ? 'EXISTS (SELECT 1 FROM app_meta '
          'WHERE "key" = ?4 AND "value" = ?5)' : 'true'} '
      'ON CONFLICT("key") DO UPDATE SET "value" = excluded."value" '
      'WHERE CAST(app_meta."value" AS INTEGER) < ?3',
      variables: [
        Variable.withString(key),
        Variable.withString(value),
        Variable.withInt(staleBelow),
        if (guarded) Variable.withString(requireKey),
        if (guarded) Variable.withString(requireValue!),
      ],
      updates: {appMeta},
      updateKind: UpdateKind.insert,
    );
    return changed > 0;
  }
}
