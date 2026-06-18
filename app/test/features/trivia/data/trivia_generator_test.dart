import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/trivia/data/trivia_generator.dart';
import 'package:politiface/features/trivia/domain/trivia_question.dart';

Future<List<LocalCard>> _seedPool(AppDatabase db, int count) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'deck-a',
    externalId: 'deck-a',
    name: 'Deck A',
    updatedAt: 0,
  ));
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'deck-b',
    externalId: 'deck-b',
    name: 'Deck B',
    updatedAt: 0,
  ));
  for (var i = 0; i < count; i++) {
    final deckId = i % 2 == 0 ? 'deck-a' : 'deck-b';
    await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
      id: 'card-$i',
      deckId: deckId,
      externalId: 'card-$i',
      politicianName: 'Person $i',
      title: 'Role $i',
      photoUrl: Value('https://example.com/p$i.jpg'),
      sourceUrl: 'about:blank',
      sortOrder: Value(i),
      updatedAt: 0,
    ));
  }
  return db.cardsDao.allActiveCards();
}

/// Pool that reproduces the Associate-Justice ambiguity: many cards share a
/// single title, so "Who holds the role of Associate Justice?" has several
/// valid answers unless the generator excludes same-title distractors.
Future<List<LocalCard>> _seedSharedTitlePool(AppDatabase db) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'scotus',
    externalId: 'scotus',
    name: 'SCOTUS',
    updatedAt: 0,
  ));
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'other',
    externalId: 'other',
    name: 'Other',
    updatedAt: 0,
  ));
  final justices = <String, String>{
    'card-cj': 'Chief Justice of the United States',
    for (var i = 0; i < 8; i++)
      'card-aj$i': 'Associate Justice of the Supreme Court',
  };
  var sort = 0;
  for (final e in justices.entries) {
    await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
      id: e.key,
      deckId: 'scotus',
      externalId: e.key,
      politicianName: 'Justice ${e.key}',
      title: e.value,
      gender: const Value('male'),
      photoUrl: Value('https://example.com/${e.key}.jpg'),
      sourceUrl: 'about:blank',
      sortOrder: Value(sort++),
      updatedAt: 0,
    ));
  }
  // Distinct-title filler so there are always >= 3 unambiguous distractors.
  for (var i = 0; i < 10; i++) {
    await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
      id: 'other-$i',
      deckId: 'other',
      externalId: 'other-$i',
      politicianName: 'Official $i',
      title: 'Distinct Role $i',
      gender: const Value('male'),
      photoUrl: Value('https://example.com/o$i.jpg'),
      sourceUrl: 'about:blank',
      sortOrder: Value(i),
      updatedAt: 0,
    ));
  }
  return db.cardsDao.allActiveCards();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('same date + same pool produces identical question list', () async {
    final pool = await _seedPool(db, 20);
    const gen = TriviaGenerator();
    final date = DateTime(2026, 5, 23);
    final a = gen.generate(date: date, cards: pool);
    final b = gen.generate(date: date, cards: pool);
    expect(a.length, 10);
    expect(b.length, 10);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].cardId, b[i].cardId);
      expect(a[i].format, b[i].format);
      expect(a[i].correctIndex, b[i].correctIndex);
      expect(a[i].options, b[i].options);
    }
  });

  test('different dates produce different runs', () async {
    final pool = await _seedPool(db, 20);
    const gen = TriviaGenerator();
    final a = gen.generate(date: DateTime(2026, 5, 23), cards: pool);
    final b = gen.generate(date: DateTime(2026, 5, 24), cards: pool);
    // Card ID sequence should differ across days.
    final aIds = a.map((q) => q.cardId).toList();
    final bIds = b.map((q) => q.cardId).toList();
    expect(aIds, isNot(equals(bIds)));
  });

  test('formats cycle through all four', () async {
    final pool = await _seedPool(db, 20);
    const gen = TriviaGenerator();
    final qs = gen.generate(date: DateTime(2026, 5, 23), cards: pool);
    final formats = qs.map((q) => q.format).toSet();
    expect(formats, TriviaFormat.values.toSet());
  });

  test('each question has 4 options and a valid correctIndex', () async {
    final pool = await _seedPool(db, 20);
    const gen = TriviaGenerator();
    final qs = gen.generate(date: DateTime(2026, 5, 23), cards: pool);
    for (final q in qs) {
      expect(q.options.length, 4);
      expect(q.correctIndex, inInclusiveRange(0, 3));
      expect(q.options[q.correctIndex], isNotEmpty);
    }
  });

  test('returns empty list when pool is too small for 4 options', () async {
    final pool = await _seedPool(db, 3);
    const gen = TriviaGenerator();
    final qs = gen.generate(date: DateTime(2026, 5, 23), cards: pool);
    expect(qs, isEmpty);
  });

  test('no card is reused across a single run', () async {
    final pool = await _seedPool(db, 20);
    const gen = TriviaGenerator();
    final qs = gen.generate(date: DateTime(2026, 5, 23), cards: pool);
    final ids = qs.map((q) => q.cardId).toList();
    expect(ids.toSet().length, ids.length, reason: 'each card once per run');
  });

  test('"who holds role X" never offers two people with that same role',
      () async {
    final pool = await _seedSharedTitlePool(db);
    final byName = {for (final c in pool) c.politicianName: c};
    final byId = {for (final c in pool) c.id: c};
    const gen = TriviaGenerator();
    var exercisedSharedTitle = 0;
    // Sweep many dates so we hit Associate-Justice titleToName questions.
    for (var d = 1; d <= 60; d++) {
      final qs = gen.generate(date: DateTime(2026, 1, d), cards: pool);
      for (final q in qs) {
        if (q.format != TriviaFormat.titleToName) continue;
        final asked = byId[q.cardId]!;
        final matching = q.options
            .where((name) => byName[name]?.title == asked.title)
            .length;
        expect(matching, 1,
            reason: 'only the correct holder of "${asked.title}" '
                'should be an option, got $matching');
        if (asked.title.contains('Associate Justice')) exercisedSharedTitle++;
      }
    }
    expect(exercisedSharedTitle, greaterThan(0),
        reason: 'guard must actually exercise the shared-title (ambiguous) case');
  });
}
