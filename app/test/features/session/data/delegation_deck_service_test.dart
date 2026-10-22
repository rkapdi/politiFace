// DelegationDeckService: in-app generation of per-state delegation decks
// from the People table.
//
// Contracts under test:
//   - one deck per state, seeded UNSUBSCRIBED, category 'delegation'
//   - card id == person id (bioguide), senators sort before house members
//   - titles cover senate, numbered district, at-large, and territory forms
//   - re-seeding (weekly roster refresh) NEVER resets a user's subscription
//   - roster departures deactivate the card but keep its FSRS state

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/session/data/delegation_deck_service.dart';

import '../../../helpers/fake_asset_bundle.dart';

const _asset = 'assets/content/people/legislators.yaml';

Future<void> _seedPerson(
  AppDatabase db, {
  required String id,
  required String name,
  required String state,
  required String chamber,
  int? district,
  String party = 'Independent',
  String? officialUrl,
  String committees = '[]',
}) =>
    db.into(db.people).insert(
          PeopleCompanion.insert(
            id: id,
            name: name,
            chamber: Value(chamber),
            state: Value(state),
            district: Value(district),
            party: Value(party),
            currentRole: 'Member of Congress',
            officialUrl: Value(officialUrl),
            committees: Value(committees),
          ),
        );

Future<void> _seedRoster(AppDatabase db) async {
  // Florida: two senators + two representatives (out-of-order names and
  // districts to exercise the sort).
  await _seedPerson(
    db,
    id: 'S000002',
    name: 'Zoe Barnes',
    state: 'FL',
    chamber: 'senate',
    committees: json.encode([
      {'name': 'Senate Committee on Finance'},
    ]),
  );
  await _seedPerson(
    db,
    id: 'S000001',
    name: 'Adam Ash',
    state: 'FL',
    chamber: 'senate',
  );
  await _seedPerson(
    db,
    id: 'H000003',
    name: 'Carl Cole',
    state: 'FL',
    chamber: 'house',
    district: 3,
  );
  await _seedPerson(
    db,
    id: 'H000001',
    name: 'Dana Dee',
    state: 'FL',
    chamber: 'house',
    district: 1,
    officialUrl: 'https://dee.house.gov',
  );
  // Alaska: at-large representative (district 0).
  await _seedPerson(
    db,
    id: 'H000009',
    name: 'Al Large',
    state: 'AK',
    chamber: 'house',
    district: 0,
  );
  // Puerto Rico: resident commissioner.
  await _seedPerson(
    db,
    id: 'H000010',
    name: 'Rosa Rico',
    state: 'PR',
    chamber: 'house',
    district: 0,
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedRoster(db);
  });
  tearDown(() async {
    await db.close();
  });

  DelegationDeckService service(String yaml) => DelegationDeckService(
        db,
        bundle: FakeAssetBundle({_asset: yaml}),
      );

  test('generates one unsubscribed deck per state with correct cards',
      () async {
    await service('roster-v1').ensureSeeded();

    final decks = await db.decksDao.decksByCategory('delegation');
    expect(decks.map((d) => d.id).toSet(), {
      'deck_delegation-ak',
      'deck_delegation-fl',
      'deck_delegation-pr',
    });
    for (final deck in decks) {
      expect(
        deck.isSubscribed,
        isFalse,
        reason: 'delegation decks are opt-in',
      );
      expect(deck.category, 'delegation');
      expect(deck.nodeId, isNull);
    }
    final fl = decks.singleWhere((d) => d.id == 'deck_delegation-fl');
    expect(fl.name, 'Florida Delegation');
    expect(
      fl.description,
      'The senators and representatives currently serving Florida.',
    );
    expect(fl.cardCount, 4);

    // Card id == person id; senators alphabetical first, then house by
    // district.
    final flCards = await db.cardsDao.cardsByDeckId('deck_delegation-fl');
    expect(
      flCards.map((c) => c.id).toList(),
      ['S000001', 'S000002', 'H000001', 'H000003'],
    );
    expect(flCards[0].title, 'U.S. Senator from Florida');
    expect(flCards[3].title, 'U.S. Representative, FL-3');
    expect(flCards[1].oneLiner, 'Serves on the Senate Committee on Finance.');
    expect(
      flCards[0].sourceUrl,
      'https://bioguide.congress.gov/search/bio/S000001',
    );
    final dana = flCards.singleWhere((c) => c.id == 'H000001');
    expect(dana.sourceUrl, 'https://dee.house.gov');

    final akCards = await db.cardsDao.cardsByDeckId('deck_delegation-ak');
    expect(akCards.single.title, 'U.S. Representative from Alaska (at large)');
    final prCards = await db.cardsDao.cardsByDeckId('deck_delegation-pr');
    expect(prCards.single.title, 'Resident Commissioner of Puerto Rico');

    // Every delegation card got a fresh isNew memory state.
    for (final c in flCards) {
      final state = await db.reviewsDao.stateFor(c.id);
      expect(state, isNotNull);
      expect(state!.isNew, isTrue);
    }
  });

  test('same content hash is a no-op; re-run does not duplicate', () async {
    await service('roster-v1').ensureSeeded();
    await service('roster-v1').ensureSeeded();
    final decks = await db.decksDao.decksByCategory('delegation');
    expect(decks, hasLength(3));
    final flCards = await db.cardsDao.cardsByDeckId('deck_delegation-fl');
    expect(flCards, hasLength(4));
  });

  test('re-seed with a changed hash never resets a subscription', () async {
    await service('roster-v1').ensureSeeded();
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-fl', subscribed: true);

    // Weekly refresh: content hash changes, seeder runs again.
    await service('roster-v2').ensureSeeded();

    final fl = await db.decksDao.deckById('deck_delegation-fl');
    expect(
      fl!.isSubscribed,
      isTrue,
      reason: 'a roster re-seed must never clobber the user choice',
    );
    // And a still-unsubscribed deck stays unsubscribed.
    final ak = await db.decksDao.deckById('deck_delegation-ak');
    expect(ak!.isSubscribed, isFalse);
  });

  test('roster departure deactivates the card but keeps FSRS state', () async {
    await service('roster-v1').ensureSeeded();
    // Simulate a real review so the FSRS row carries user progress.
    await db.reviewsDao.upsertState(
      const CardMemoryStatesCompanion(
        cardId: Value('H000003'),
        isNew: Value(false),
        stability: Value(12),
        reviewCount: Value(4),
      ),
    );

    // Carl Cole leaves Congress.
    await (db.delete(db.people)..where((p) => p.id.equals('H000003'))).go();
    await service('roster-v2').ensureSeeded();

    final card = await db.cardsDao.cardById('H000003');
    expect(card, isNotNull);
    expect(
      card!.isActive,
      isFalse,
      reason: 'departed members leave the rotation',
    );
    final state = await db.reviewsDao.stateFor('H000003');
    expect(state, isNotNull, reason: 'FSRS state is retained on purpose');
    expect(state!.stability, 12.0);
    expect(state.reviewCount, 4);

    // Deck metadata reflects the new roster size.
    final fl = await db.decksDao.deckById('deck_delegation-fl');
    expect(fl!.cardCount, 3);

    // A member still serving stays active.
    final dana = await db.cardsDao.cardById('H000001');
    expect(dana!.isActive, isTrue);
  });
}
