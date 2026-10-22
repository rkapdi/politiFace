import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';

ReviewLogsCompanion _log(String cardId, int reviewedAt, int grade) =>
    ReviewLogsCompanion.insert(
      cardId: cardId,
      reviewedAt: reviewedAt,
      grade: grade,
      stability: 1 + reviewedAt.toDouble(),
      difficulty: 5,
      retrievability: 0.9,
      intervalDays: 1,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('ReviewsDao.logsForCard', () {
    test('returns empty list for a card with no reviews', () async {
      final logs = await db.reviewsDao.logsForCard('nope');
      expect(logs, isEmpty);
    });

    test('returns only the requested card, oldest first', () async {
      // Insert interleaved, out-of-order timestamps for two cards.
      await db.reviewsDao.appendLog(_log('a', 300, 2));
      await db.reviewsDao.appendLog(_log('a', 100, 0));
      await db.reviewsDao.appendLog(_log('b', 150, 3));
      await db.reviewsDao.appendLog(_log('a', 200, 1));

      final logs = await db.reviewsDao.logsForCard('a');
      expect(logs.map((l) => l.cardId).toSet(), {'a'});
      expect(
        logs.map((l) => l.reviewedAt).toList(),
        [100, 200, 300],
        reason: 'history must be chronological for the retention curve',
      );
      expect(logs.map((l) => l.grade).toList(), [0, 1, 2]);
    });
  });
}
