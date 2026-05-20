import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/profile/data/profile_service.dart';
import 'package:politiface/features/session/data/card_review_repository.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

Future<void> _seedCard(AppDatabase db, String id, {bool newState = true}) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'deck-$id',
    externalId: 'deck-$id',
    name: 'Deck $id',
    updatedAt: 0,
  ));
  await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
    id: id,
    deckId: 'deck-$id',
    externalId: id,
    politicianName: 'Name $id',
    title: 'Title $id',
    sourceUrl: 'about:blank',
    updatedAt: 0,
  ));
  if (newState) {
    await db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(cardId: Value(id), isNew: const Value(true)),
    );
  }
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

  group('recordReview', () {
    test('new card path uses scheduleNew and flips isNew=false', () async {
      await _seedCard(db, 'c1');
      final next = await repo.recordReview(
        cardId: 'c1',
        grade: FSRSGrade.good,
      );
      expect(next.stability, greaterThan(0));
      expect(next.reviewCount, 1);

      final row = await db.reviewsDao.stateFor('c1');
      expect(row, isNotNull);
      expect(row!.isNew, isFalse, reason: 'first review must clear isNew');
      expect(row.lastReviewedAt, greaterThan(0));
      expect(row.nextReviewAt, greaterThan(row.lastReviewedAt));
    });

    test('writes a review log row in the same transaction', () async {
      await _seedCard(db, 'c1');
      await repo.recordReview(cardId: 'c1', grade: FSRSGrade.good);
      final logs = await db.reviewsDao.unsyncedLogs();
      expect(logs.length, 1);
      expect(logs.first.cardId, 'c1');
      expect(logs.first.grade, FSRSGrade.good.value);
      expect(logs.first.synced, isFalse);
    });

    test('second review goes through schedule path (reviewCount increments)',
        () async {
      await _seedCard(db, 'c1');
      await repo.recordReview(cardId: 'c1', grade: FSRSGrade.good);
      final second = await repo.recordReview(
        cardId: 'c1',
        grade: FSRSGrade.good,
      );
      // FSRS keeps stability flat on zero-elapsed-time reviews by design
      // (perfect recall with no decay teaches nothing). Just verify schedule
      // ran rather than scheduleNew.
      expect(second.reviewCount, 2);
      final row = await db.reviewsDao.stateFor('c1');
      expect(row!.reviewCount, 2);
    });

    test('again increments lapses', () async {
      await _seedCard(db, 'c1');
      await repo.recordReview(cardId: 'c1', grade: FSRSGrade.good);
      final after = await repo.recordReview(
        cardId: 'c1',
        grade: FSRSGrade.again,
      );
      expect(after.lapses, 1);
    });
  });

  group('loadSessionCandidates (global)', () {
    test('returns new + due cards across decks', () async {
      await _seedCard(db, 'a'); // new
      await _seedCard(db, 'b'); // new
      final cands = await repo.loadSessionCandidates();
      expect(cands.fresh.length, 2);
      expect(cands.due, isEmpty);
    });

    test('does not surface cards scheduled into the future', () async {
      await _seedCard(db, 'a');
      // Grade so it becomes due-in-the-future
      await repo.recordReview(cardId: 'a', grade: FSRSGrade.good);
      final cands = await repo.loadSessionCandidates();
      expect(cands.fresh, isEmpty);
      expect(cands.due, isEmpty,
          reason: 'globally-driven session shouldnt include scheduled-out cards');
    });
  });

  group('loadSessionCandidates (deck scope)', () {
    test('only returns cards from the named deck', () async {
      await _seedCard(db, 'in-deck');
      await _seedCard(db, 'other');
      final cands = await repo.loadSessionCandidates(deckId: 'deck-in-deck');
      expect(cands.fresh.length + cands.due.length, 1);
      final all = [...cands.fresh, ...cands.due];
      expect(all.first.cardId, 'in-deck');
    });

    test('surfaces all deck cards even when scheduled into the future (study mode)',
        () async {
      await _seedCard(db, 'a');
      await repo.recordReview(cardId: 'a', grade: FSRSGrade.good);
      // Card 'a' is now scheduled into the future.
      final cands = await repo.loadSessionCandidates(deckId: 'deck-a');
      final all = [...cands.fresh, ...cands.due];
      expect(all.length, 1,
          reason: 'deck scope acts as study mode — include even non-due cards');
      expect(all.first.cardId, 'a');
    });
  });
}
