// Flood prevention: cards in unsubscribed decks stay out of every global
// pool (daily session sampler, Endless/Trivia/round fallback face pool,
// brain-strength denominator) while deck-scoped study and explicit
// card-id loads stay unfiltered. Subscribing flips the same cards back in
// with zero state bookkeeping.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/profile/data/profile_service.dart';
import 'package:politiface/features/session/data/card_review_repository.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

Future<void> _seedDeck(
  AppDatabase db, {
  required String deckId,
  required bool subscribed,
  required String category,
}) =>
    db.decksDao.upsertDeck(
      LocalDecksCompanion.insert(
        id: deckId,
        externalId: deckId,
        name: deckId,
        isSubscribed: Value(subscribed),
        category: Value(category),
        updatedAt: 0,
      ),
    );

Future<void> _seedCard(
  AppDatabase db, {
  required String id,
  required String deckId,
  bool due = false,
}) async {
  await db.cardsDao.upsertCard(
    LocalCardsCompanion.insert(
      id: id,
      deckId: deckId,
      externalId: id,
      politicianName: 'Name $id',
      title: 'Title $id',
      sourceUrl: 'about:blank',
      updatedAt: 0,
    ),
  );
  if (due) {
    // Reviewed once, due far in the past: prime flood material.
    await db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: Value(id),
        isNew: const Value(false),
        nextReviewAt: const Value(1000),
        lastReviewedAt: const Value(500),
      ),
    );
  } else {
    await db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: Value(id),
        isNew: const Value(true),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late CardReviewRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CardReviewRepository(db, const FSRS(), ProfileService(db));

    // A subscribed curated deck and an unsubscribed delegation deck, both
    // holding new AND past-due cards.
    await _seedDeck(
      db,
      deckId: 'deck-core',
      subscribed: true,
      category: 'curated',
    );
    await _seedDeck(
      db,
      deckId: 'deck_delegation-fl',
      subscribed: false,
      category: 'delegation',
    );
    await _seedCard(db, id: 'core-new', deckId: 'deck-core');
    await _seedCard(db, id: 'core-due', deckId: 'deck-core', due: true);
    await _seedCard(db, id: 'fl-new', deckId: 'deck_delegation-fl');
    await _seedCard(db, id: 'fl-due', deckId: 'deck_delegation-fl', due: true);
  });

  tearDown(() async {
    await db.close();
  });

  Set<String> ids(SessionCandidates c) =>
      {...c.due.map((s) => s.cardId), ...c.fresh.map((s) => s.cardId)};

  test('global session excludes unsubscribed deck cards (new and due)',
      () async {
    final cands = await repo.loadSessionCandidates();
    expect(ids(cands), {'core-new', 'core-due'});
  });

  test('deck-scoped study still surfaces unsubscribed deck cards', () async {
    final cands =
        await repo.loadSessionCandidates(deckId: 'deck_delegation-fl');
    expect(
      ids(cands),
      {'fl-new', 'fl-due'},
      reason: 'try-before-subscribe: deck scope is unfiltered',
    );
  });

  test('explicit card-id load (session restore) stays unfiltered', () async {
    final cands =
        await repo.loadSessionCandidates(cardIds: ['fl-new', 'core-new']);
    expect(ids(cands), {'fl-new', 'core-new'});
  });

  test('subscribing brings the cards into the global session', () async {
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: true);
    final cands = await repo.loadSessionCandidates();
    expect(ids(cands), {'core-new', 'core-due', 'fl-new', 'fl-due'});
  });

  test('unsubscribing pauses without touching FSRS state', () async {
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: true);
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: false);
    final cands = await repo.loadSessionCandidates();
    expect(ids(cands), {'core-new', 'core-due'});
    final state = await db.reviewsDao.stateFor('fl-due');
    expect(state, isNotNull);
    expect(
      state!.isNew,
      isFalse,
      reason: 'pause keeps memory state untouched',
    );
  });

  test(
      'face-card pool (Endless, Trivia, round fallback) excludes unsubscribed '
      'decks and includes them after subscribe', () async {
    var pool = await db.cardsDao.subscribedActiveFaceCards();
    expect(pool.map((c) => c.id).toSet(), {'core-new', 'core-due'});

    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: true);
    pool = await db.cardsDao.subscribedActiveFaceCards();
    expect(
      pool.map((c) => c.id).toSet(),
      {'core-new', 'core-due', 'fl-new', 'fl-due'},
    );
  });

  test('brain-strength denominator counts only subscribed decks', () async {
    expect(await db.cardsDao.subscribedActiveCardCount(), 2);
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: true);
    expect(await db.cardsDao.subscribedActiveCardCount(), 4);
  });
}
