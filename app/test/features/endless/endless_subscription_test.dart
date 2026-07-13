// EndlessEngine + deck subscriptions:
//   - the question pool draws only from subscribed decks, so generating
//     delegation decks cannot flood Endless until the user opts in
//   - distractors never share a politicianName with the correct answer
//     (the same human can exist as a curated leadership card AND a
//     delegation card once a delegation is subscribed)

import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/endless/data/endless_engine.dart';

Future<void> _seedDeck(AppDatabase db, String id, {required bool subscribed}) =>
    db.decksDao.upsertDeck(
      LocalDecksCompanion.insert(
        id: id,
        externalId: id,
        name: id,
        isSubscribed: Value(subscribed),
        category: Value(subscribed ? 'curated' : 'delegation'),
        updatedAt: 0,
      ),
    );

Future<void> _seedCard(
  AppDatabase db, {
  required String id,
  required String deckId,
  required String name,
  required String title,
}) =>
    db.cardsDao.upsertCard(
      LocalCardsCompanion.insert(
        id: id,
        deckId: deckId,
        externalId: id,
        politicianName: name,
        title: title,
        photoUrl: Value('https://example.com/$id.jpg'),
        sourceUrl: 'about:blank',
        updatedAt: 0,
      ),
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test('pool excludes cards from unsubscribed decks', () async {
    await _seedDeck(db, 'curated', subscribed: true);
    await _seedDeck(db, 'deck_delegation-ia', subscribed: false);
    for (var i = 0; i < 6; i++) {
      await _seedCard(
        db,
        id: 'c$i',
        deckId: 'curated',
        name: 'Person $i',
        title: 'Role $i',
      );
    }
    for (var i = 0; i < 6; i++) {
      await _seedCard(
        db,
        id: 'd$i',
        deckId: 'deck_delegation-ia',
        name: 'Delegate $i',
        title: 'Rep $i',
      );
    }

    final engine = EndlessEngine(db, random: Random(3));
    for (var i = 0; i < 40; i++) {
      final q = await engine.nextQuestion();
      expect(q, isNotNull);
      for (final option in q!.options) {
        expect(
          option.deckId,
          'curated',
          reason: 'unsubscribed delegation cards must never appear',
        );
      }
    }
  });

  test('after subscribing, delegation cards enter the pool', () async {
    await _seedDeck(db, 'curated', subscribed: true);
    await _seedDeck(db, 'deck_delegation-ia', subscribed: false);
    for (var i = 0; i < 4; i++) {
      await _seedCard(
        db,
        id: 'c$i',
        deckId: 'curated',
        name: 'Person $i',
        title: 'Role $i',
      );
    }
    for (var i = 0; i < 4; i++) {
      await _seedCard(
        db,
        id: 'd$i',
        deckId: 'deck_delegation-ia',
        name: 'Delegate $i',
        title: 'Rep $i',
      );
    }
    await db.decksDao
        .setSubscribed(deckId: 'deck_delegation-ia', subscribed: true);

    final engine = EndlessEngine(db, random: Random(5));
    final seenDecks = <String>{};
    for (var i = 0; i < 60; i++) {
      final q = await engine.nextQuestion();
      expect(q, isNotNull);
      seenDecks.addAll(q!.options.map((c) => c.deckId));
    }
    expect(seenDecks, containsAll(['curated', 'deck_delegation-ia']));
  });

  test('distractors never share politicianName with the correct answer',
      () async {
    await _seedDeck(db, 'curated', subscribed: true);
    await _seedDeck(db, 'deck_delegation-ia', subscribed: true);
    // The same senator exists as a curated leadership card and as a
    // delegation card (different card ids, same human).
    await _seedCard(
      db,
      id: 'us-senate-pres-pro-tem',
      deckId: 'curated',
      name: 'Chuck Grassley',
      title: 'President Pro Tempore of the Senate',
    );
    await _seedCard(
      db,
      id: 'G000386',
      deckId: 'deck_delegation-ia',
      name: 'Chuck Grassley',
      title: 'U.S. Senator from Iowa',
    );
    for (var i = 0; i < 8; i++) {
      await _seedCard(
        db,
        id: 'c$i',
        deckId: 'curated',
        name: 'Person $i',
        title: 'Role $i',
      );
    }

    final engine = EndlessEngine(db, random: Random(11));
    for (var i = 0; i < 120; i++) {
      final q = await engine.nextQuestion();
      expect(q, isNotNull);
      final correctName = q!.options[q.correctIndex].politicianName;
      final sameName =
          q.options.where((c) => c.politicianName == correctName).length;
      expect(
        sameName,
        1,
        reason: 'a question must never offer two cards of the same person',
      );
    }
  });
}
