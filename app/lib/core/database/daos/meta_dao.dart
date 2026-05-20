import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'meta_dao.g.dart';

@DriftAccessor(tables: [SyncMeta])
class MetaDao extends DatabaseAccessor<AppDatabase> with _$MetaDaoMixin {
  MetaDao(AppDatabase db) : super(db);

  Future<String?> get(String key) async {
    final row = await (select(syncMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(key: key, value: value),
    );
  }
}
