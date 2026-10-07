import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/audio/streak_sounds.dart';
import 'package:politiface/core/database/drift/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a milestone is claimed once, then stays quiet', () async {
    expect(await claimStreakMilestone(db.metaDao, 7), isTrue);
    expect(await claimStreakMilestone(db.metaDao, 7), isFalse);
  });

  test('non-milestone days never claim', () async {
    expect(await claimStreakMilestone(db.metaDao, 8), isFalse);
  });

  test('the next milestone claims again', () async {
    expect(await claimStreakMilestone(db.metaDao, 7), isTrue);
    expect(await claimStreakMilestone(db.metaDao, 14), isTrue);
  });
}
