import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'meta_dao.g.dart';

@DriftAccessor(tables: [AppMeta])
class MetaDao extends DatabaseAccessor<AppDatabase> with _$MetaDaoMixin {
  MetaDao(AppDatabase db) : super(db);

  Future<String?> get(String key) async {
    final row = await (select(appMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return into(appMeta).insertOnConflictUpdate(
      AppMetaCompanion.insert(key: key, value: value),
    );
  }
}
