import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(String id, String mode) => db.completedRunsDao.insert(
        CompletedRunsCompanion.insert(id: id, mode: mode, completedAt: 1),
      );

  test('rows from the removed trivia mode stay stored but are never listed',
      () async {
    await insert('old', 'trivia');
    await insert('round', 'round');
    await insert('endless', 'endless');

    final listed = await db.completedRunsDao.recent();
    expect(listed.map((r) => r.mode).toSet(), {'round', 'endless'});
    expect(await db.completedRunsDao.recent(mode: 'trivia'), isEmpty);
    expect(await db.completedRunsDao.byId('old'), isNotNull);
  });
}
