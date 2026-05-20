import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/profile/data/profile_service.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

void main() {
  late AppDatabase db;
  late ProfileService profile;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profile = ProfileService(db);
  });

  tearDown(() => db.close());

  test('empty profile at start', () async {
    final p = await profile.load();
    expect(p.streakDays, 0);
    expect(p.xpTotal, 0);
    expect(p.level, 1);
  });

  test('first review starts streak at 1 and awards xp', () async {
    final p = await profile.recordReview(grade: FSRSGrade.good);
    expect(p.streakDays, 1);
    expect(p.xpTotal, ProfileService.xpForGood);
  });

  test('two reviews same day → streak stays at 1', () async {
    final t = DateTime(2026, 5, 19, 9);
    await profile.recordReview(grade: FSRSGrade.good, now: t);
    final p = await profile.recordReview(
      grade: FSRSGrade.good,
      now: t.add(const Duration(hours: 3)),
    );
    expect(p.streakDays, 1);
    expect(p.xpTotal, ProfileService.xpForGood * 2);
  });

  test('review yesterday + today → streak = 2', () async {
    await profile.recordReview(
      grade: FSRSGrade.good,
      now: DateTime(2026, 5, 18, 12),
    );
    final p = await profile.recordReview(
      grade: FSRSGrade.good,
      now: DateTime(2026, 5, 19, 9),
    );
    expect(p.streakDays, 2);
  });

  test('skip a day → streak resets to 1', () async {
    await profile.recordReview(
      grade: FSRSGrade.good,
      now: DateTime(2026, 5, 17, 12),
    );
    final p = await profile.recordReview(
      grade: FSRSGrade.good,
      now: DateTime(2026, 5, 19, 9),
    );
    expect(p.streakDays, 1, reason: 'gap of one day resets streak');
  });

  test('xp accumulates and levels up at the right thresholds', () async {
    // Level 1 → 0..100, Level 2 → 100..300, Level 3 → 300..600
    // 5 Easies = 70 xp → still Level 1
    for (var i = 0; i < 5; i++) {
      await profile.recordReview(grade: FSRSGrade.easy);
    }
    var p = await profile.load();
    expect(p.level, 1);

    // 5 more Easies = 140 xp → Level 2 (100..300 means 40 in level)
    for (var i = 0; i < 5; i++) {
      await profile.recordReview(grade: FSRSGrade.easy);
    }
    p = await profile.load();
    expect(p.level, 2);
    expect(p.xpForNextLevel, 200, reason: 'Level 2 → Level 3 costs 200');
  });
}
