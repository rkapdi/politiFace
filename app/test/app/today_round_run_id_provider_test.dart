import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';

/// Guards the data path behind "Review today" on the home card. The button
/// deep-links to /round/review?runId=<this provider's value>. Regression
/// context: "Review today" once pointed at /round, which bounces a completed
/// round straight back home ("nothing happens" loop). This provider must
/// resolve the completed round's id so the review screen can hydrate it.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ],);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('null when no round has been completed', () async {
    expect(await container.read(todayRoundRunIdProvider.future), isNull);
  });

  test('returns the id of the most recent completed round run', () async {
    await db.completedRunsDao.insert(CompletedRunsCompanion.insert(
      id: 'round_2026-06-18_ch1_42',
      mode: 'round',
      completedAt: 1000,
    ),);
    await db.completedRunsDao.insert(CompletedRunsCompanion.insert(
      id: 'round_2026-06-18_ch1_99',
      mode: 'round',
      completedAt: 2000, // newer
    ),);
    expect(
      await container.read(todayRoundRunIdProvider.future),
      'round_2026-06-18_ch1_99',
    );
  });

  test('ignores non-round modes so the review link stays round-scoped',
      () async {
    await db.completedRunsDao.insert(CompletedRunsCompanion.insert(
      id: 'endless_x',
      mode: 'endless',
      completedAt: 3000,
    ),);
    expect(await container.read(todayRoundRunIdProvider.future), isNull);
  });
}
