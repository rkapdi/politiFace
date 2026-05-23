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
}
