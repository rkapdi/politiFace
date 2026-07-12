// Teach-first concept cards in the session flow: the first encounter is a
// lesson (teachFirst), and after the "Got it" grade the card becomes a
// normal FSRS recall card. FSRS itself is untouched — "Got it" is just
// grade=good through the existing pipeline.

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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ],);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'd',
          externalId: 'd',
          name: 'd',
          updatedAt: now,
        ),);
    await db.into(db.localCards).insert(LocalCardsCompanion.insert(
          id: 'concept-1',
          deckId: 'd',
          externalId: 'concept-1',
          politicianName: 'The Filibuster',
          title: 'Senate procedure',
          cardType: const Value('concept'),
          body: const Value('Teaching prose about the filibuster.'),
          recallPrompt: const Value('What does cloture end?'),
          sourceUrl: '',
          updatedAt: now,
        ),);
    await db.reviewsDao.upsertState(const CardMemoryStatesCompanion(
      cardId: Value('concept-1'),
      isNew: Value(true),
    ),);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('first encounter teaches; after Got It it becomes a recall card',
      () async {
    container.read(activeSessionCardIdsProvider.notifier).state = [
      'concept-1',
    ];

    final state = await container.read(sessionControllerProvider.future);
    final card = state.currentCard!;
    expect(card.isConcept, true);
    expect(card.teachFirst, true,
        reason: 'never-reviewed concept renders as a lesson',);
    expect(card.body, 'Teaching prose about the filibuster.');

    // "Got it" = grade good through the normal pipeline.
    await container
        .read(sessionControllerProvider.notifier)
        .handleGrade(FSRSGrade.good);

    final memory = await db.reviewsDao.stateFor('concept-1');
    expect(memory!.isNew, false, reason: 'first review schedules the card');
    expect(memory.reviewCount, 1);

    // Next session: same card now loads as a recall card, not a lesson.
    container.read(activeSessionCardIdsProvider.notifier).state = [
      'concept-1',
    ];
    container.read(sessionControllerProvider.notifier).reset();
    final next = await container.read(sessionControllerProvider.future);
    expect(next.currentCard!.isConcept, true);
    expect(next.currentCard!.teachFirst, false,
        reason: 'reviewed concepts quiz via recallPrompt',);
    expect(next.currentCard!.recallPrompt, 'What does cloture end?');
  });
}
