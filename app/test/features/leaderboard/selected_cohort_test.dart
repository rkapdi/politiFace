import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/leaderboard/application/leaderboard_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() => ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

  test('starts null for a fresh install', () async {
    final c = container();
    addTearDown(c.dispose);
    expect(await c.read(selectedCohortIdProvider.future), isNull);
  });

  test('selection persists across containers (app restarts)', () async {
    final c1 = container();
    await c1.read(selectedCohortIdProvider.notifier).select('cohort-b');
    expect(await c1.read(selectedCohortIdProvider.future), 'cohort-b');
    c1.dispose();

    final c2 = container();
    addTearDown(c2.dispose);
    expect(
      await c2.read(selectedCohortIdProvider.future),
      'cohort-b',
      reason: 'the pick is stored in AppMeta, not widget state',
    );
  });
}
