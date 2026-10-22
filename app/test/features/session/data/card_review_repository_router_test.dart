import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/profile/data/profile_service.dart';
import 'package:politiface/features/session/data/card_review_repository.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

Future<void> _seedCard(AppDatabase db, String id) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'deck-$id',
    externalId: 'deck-$id',
    name: 'Deck $id',
    updatedAt: 0,
  ),);
  await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
    id: id,
    deckId: 'deck-$id',
    externalId: id,
    politicianName: 'Name $id',
    title: 'Title $id',
    sourceUrl: 'about:blank',
    updatedAt: 0,
  ),);
  await db.reviewsDao.upsertState(
    CardMemoryStatesCompanion(cardId: Value(id), isNew: const Value(true)),
  );
}

void main() {
  late AppDatabase db;
  late CardReviewRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CardReviewRepository(db, const FSRS(), ProfileService(db));
  });

  tearDown(() async {
    await db.close();
  });

  group('recordGrade router', () {
    test('brand-new card always routes to review (real FSRS update)', () async {
      await _seedCard(db, 'c1');
      final outcome = await repo.recordGrade(
        cardId: 'c1',
        grade: FSRSGrade.good,
      );
      expect(outcome.mode, GradeMode.review);

      final row = await db.reviewsDao.stateFor('c1');
      expect(row!.isNew, isFalse);
      expect(row.reviewCount, 1);
      expect(row.practiceCountSinceReview, 0);
      expect(row.lastGrade, FSRSGrade.good.value);
    });

    test('Again always routes to review, even on a not-due card', () async {
      await _seedCard(db, 'c1');
      // First Good schedules it days into the future.
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      // Now Again — should be treated as a real failure regardless of timing.
      final outcome = await repo.recordGrade(
        cardId: 'c1',
        grade: FSRSGrade.again,
      );
      expect(outcome.mode, GradeMode.review);

      final row = await db.reviewsDao.stateFor('c1');
      expect(row!.lapses, 1, reason: 'Again must propagate to FSRS');
      expect(row.practiceCountSinceReview, 0,
          reason: 'real review resets practice counter',);
    });

    test('not-due card with Good/Hard/Easy routes to practice', () async {
      await _seedCard(db, 'c1');
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      final before = (await db.reviewsDao.stateFor('c1'))!;

      final outcome = await repo.recordGrade(
        cardId: 'c1',
        grade: FSRSGrade.good,
      );
      expect(outcome.mode, GradeMode.practice);

      final after = (await db.reviewsDao.stateFor('c1'))!;
      // FSRS state must NOT have moved.
      expect(after.stability, before.stability);
      expect(after.difficulty, before.difficulty);
      expect(after.lastReviewedAt, before.lastReviewedAt);
      expect(after.nextReviewAt, before.nextReviewAt);
      expect(after.reviewCount, before.reviewCount);
      // Practice counter and lastGrade DO move.
      expect(after.practiceCountSinceReview, 1);
      expect(after.lastGrade, FSRSGrade.good.value);
    });

    test('practice does not write a review log row', () async {
      await _seedCard(db, 'c1');
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      final logsAfterReview = await db.reviewsDao.unsyncedLogs();
      expect(logsAfterReview.length, 1);

      // Same-day re-grade → practice mode, no new log row.
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      final logsAfterPractice = await db.reviewsDao.unsyncedLogs();
      expect(logsAfterPractice.length, 1,
          reason: 'practice mode keeps the review log clean',);
    });

    test('practice counter accumulates across multiple practice taps',
        () async {
      await _seedCard(db, 'c1');
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good); // review
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good); // practice
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.easy); // practice
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.hard); // practice

      final row = await db.reviewsDao.stateFor('c1');
      expect(row!.practiceCountSinceReview, 3);
      expect(row.reviewCount, 1, reason: 'real reviews stay at 1');
      expect(row.lastGrade, FSRSGrade.hard.value);
    });

    test('once card becomes due again, next grade flips back to review mode',
        () async {
      await _seedCard(db, 'c1');
      // First review: schedules forward.
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      // Practice in between.
      await repo.recordGrade(cardId: 'c1', grade: FSRSGrade.good);
      // Simulate clock advancing past nextReviewAt by passing a forced 'now'.
      final fakeNow = DateTime.now().add(const Duration(days: 60));
      final outcome = await repo.recordGrade(
        cardId: 'c1',
        grade: FSRSGrade.good,
        now: fakeNow,
      );
      expect(outcome.mode, GradeMode.review);

      final row = await db.reviewsDao.stateFor('c1');
      expect(row!.reviewCount, 2, reason: 'second real review fires');
      expect(row.practiceCountSinceReview, 0,
          reason: 'real review resets practice counter',);
    });
  });
}
