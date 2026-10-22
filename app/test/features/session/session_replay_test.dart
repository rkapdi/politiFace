// Chapter replay: an explicit card list builds a session out of cards that
// are neither new nor due — the case the old "Replay coming with History"
// stub blocked. Completed chapters must be replayable anytime; the FSRS
// practice path (card_review_repository.dart) keeps replays from corrupting
// the memory model, so there is no scheduling reason to gate this.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/session/application/session_controller.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

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

  /// Seeds [count] cards that were all reviewed today and are NOT due again
  /// for weeks — the state of a freshly completed chapter.
  Future<List<String>> seedReviewedCards(int count) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'd',
          externalId: 'd',
          name: 'd',
          updatedAt: now,
        ),);
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      final id = 'c$i';
      ids.add(id);
      await db.into(db.localCards).insert(LocalCardsCompanion.insert(
            id: id,
            deckId: 'd',
            externalId: '${id}_ext',
            politicianName: 'Politician $i',
            title: 'Title $i',
            sourceUrl: '',
            updatedAt: now,
          ),);
      await db.reviewsDao.upsertState(CardMemoryStatesCompanion.insert(
        cardId: id,
        isNew: const Value(false),
        lastReviewedAt: Value(now),
        nextReviewAt: Value(now + 21 * 86400), // due in 3 weeks
        stability: const Value(20),
        reviewCount: const Value(4),
      ),);
    }
    return ids;
  }

  test('replay session loads every requested card even when none are due',
      () async {
    final ids = await seedReviewedCards(3);
    container.read(activeSessionCardIdsProvider.notifier).state = ids;

    final state = await container.read(sessionControllerProvider.future);

    expect(state.totalPlanned, 3,
        reason: 'non-due cards must load for a replay',);
    expect(state.isComplete, false);
    expect(ids, contains(state.currentCard!.cardId));
  });

  test('explicit card list takes precedence over a stale deck scope',
      () async {
    final ids = await seedReviewedCards(2);
    container.read(activeSessionDeckIdProvider.notifier).state = 'd';
    container.read(activeSessionCardIdsProvider.notifier).state = [ids.first];

    final state = await container.read(sessionControllerProvider.future);

    expect(state.totalPlanned, 1);
    expect(state.currentCard!.cardId, ids.first);
  });

  test('replay can be played to completion and grades are recorded',
      () async {
    final ids = await seedReviewedCards(2);
    container.read(activeSessionCardIdsProvider.notifier).state = ids;

    await container.read(sessionControllerProvider.future);
    final controller = container.read(sessionControllerProvider.notifier);

    await controller.handleGrade(FSRSGrade.good);
    await controller.handleGrade(FSRSGrade.good);

    final state = container.read(sessionControllerProvider).value!;
    expect(state.isComplete, true);
    expect(state.completed, 2);
    expect(state.reviewedCardIds.toSet(), ids.toSet());

    // Same-day re-grade of a non-due card routes to the practice path:
    // lastGrade ticks, FSRS stability untouched.
    final memory = await db.reviewsDao.stateFor(ids.first);
    expect(memory!.stability, 20.0,
        reason: 'replay grades must not corrupt FSRS scheduling',);
    expect(memory.lastGrade, FSRSGrade.good.value);
  });
}
