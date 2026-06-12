// YamlSeedService: checksum-versioned deck seeding.
//
// The contract under test mirrors the government seeder: content edits reach
// existing installs automatically, unchanged content is a no-op, and FSRS
// card memory state survives every re-seed bit-for-bit.

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/session/data/yaml_seed_service.dart';

import '../../../helpers/fake_asset_bundle.dart';

const _deckPath = 'assets/content/decks/test-deck.yaml';

const _deckV1 = '''
meta:
  id: test-deck
  name: "Test Deck"
  node_id: t-node-a
  tier_order: 1
cards:
  - id: card-one
    name: "Jane Doe"
    title: "Secretary of Testing"
    party: "Independent"
    source: "https://example.gov/jane"
''';

// v2: title fixed, second card added.
const _deckV2 = '''
meta:
  id: test-deck
  name: "Test Deck"
  node_id: t-node-a
  tier_order: 1
cards:
  - id: card-one
    name: "Jane Doe"
    title: "Secretary of Better Testing"
    party: "Independent"
    source: "https://example.gov/jane"
  - id: card-two
    name: "John Roe"
    title: "Deputy Secretary"
    party: "Independent"
    source: "https://example.gov/john"
''';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seedWith(String deckYaml) {
    final bundle = FakeAssetBundle({
      'AssetManifest.json': jsonEncode({
        _deckPath: [_deckPath],
      }),
      _deckPath: deckYaml,
    });
    return YamlSeedService(db, bundle: bundle).ensureSeeded();
  }

  test('fresh database: deck and cards seeded with new memory state',
      () async {
    await seedWith(_deckV1);

    final decks = await db.select(db.localDecks).get();
    expect(decks.single.id, 'deck_test-deck');
    expect(decks.single.cardCount, 1);

    final cards = await db.select(db.localCards).get();
    expect(cards.single.id, 'card-one');

    final state = await db.reviewsDao.stateFor('card-one');
    expect(state!.isNew, true);
  });

  test('unchanged content is a no-op (checksum short-circuit)', () async {
    await seedWith(_deckV1);

    await (db.update(db.localCards)..where((c) => c.id.equals('card-one')))
        .write(const LocalCardsCompanion(title: Value('TAMPERED')));

    await seedWith(_deckV1);

    final card = (await db.select(db.localCards).get()).single;
    expect(card.title, 'TAMPERED', reason: 'identical content must not re-seed');
  });

  test('content edit propagates; FSRS memory state survives bit-for-bit',
      () async {
    await seedWith(_deckV1);

    // Simulate a real review history on card-one.
    await db.reviewsDao.upsertState(const CardMemoryStatesCompanion(
      cardId: Value('card-one'),
      difficulty: Value(4.2),
      stability: Value(18.5),
      retrievability: Value(0.93),
      lastReviewedAt: Value(1717000000),
      nextReviewAt: Value(1718600000),
      intervalDays: Value(19),
      lapses: Value(1),
      reviewCount: Value(12),
      isNew: Value(false),
    ),);

    await seedWith(_deckV2);

    // The edit landed…
    final cards = await db.select(db.localCards).get();
    expect(cards, hasLength(2));
    final one = cards.singleWhere((c) => c.id == 'card-one');
    expect(one.title, 'Secretary of Better Testing');

    // …and the memory state is untouched.
    final state = await db.reviewsDao.stateFor('card-one');
    expect(state!.difficulty, 4.2);
    expect(state.stability, 18.5);
    expect(state.retrievability, 0.93);
    expect(state.nextReviewAt, 1718600000);
    expect(state.reviewCount, 12);
    expect(state.isNew, false);

    // The new card starts fresh.
    final two = await db.reviewsDao.stateFor('card-two');
    expect(two!.isNew, true);
  });

  test('legacy run-once flag is cleaned up after first checksum seed',
      () async {
    await db.metaDao.set('yaml_seed_v3_done', '1');
    await seedWith(_deckV1);
    expect(await db.metaDao.get('yaml_seed_v3_done'), isNull);
    expect(await db.metaDao.get('seed.decks_hash'), isNotNull);
  });
}
