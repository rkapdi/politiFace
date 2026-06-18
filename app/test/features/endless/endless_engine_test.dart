import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/endless/data/endless_engine.dart';
import 'package:politiface/features/endless/domain/endless_question.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  // Pool with many shared-title cards (every Associate Justice shares one
  // title) plus distinct-title fillers, so title-answer questions would be
  // ambiguous unless the engine excludes same-title distractors.
  Future<void> seed() async {
    await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
      id: 'd',
      externalId: 'd',
      name: 'D',
      updatedAt: 0,
    ));
    for (var i = 0; i < 6; i++) {
      await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
        id: 'aj$i',
        deckId: 'd',
        externalId: 'aj$i',
        politicianName: 'Justice $i',
        title: 'Associate Justice of the Supreme Court',
        photoUrl: Value('https://example.com/aj$i.jpg'),
        sourceUrl: 'about:blank',
        sortOrder: Value(i),
        updatedAt: 0,
      ));
    }
    for (var i = 0; i < 6; i++) {
      await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
        id: 'o$i',
        deckId: 'd',
        externalId: 'o$i',
        politicianName: 'Official $i',
        title: 'Distinct Role $i',
        photoUrl: Value('https://example.com/o$i.jpg'),
        sourceUrl: 'about:blank',
        sortOrder: Value(10 + i),
        updatedAt: 0,
      ));
    }
  }

  for (final mode in [QuestionMode.titleToWho, QuestionMode.photoToTitle]) {
    test('$mode never offers two options that hold the same role', () async {
      await seed();
      final engine = EndlessEngine(db, random: Random(7));
      var sawSharedTitleCorrect = 0;
      for (var i = 0; i < 80; i++) {
        final q = await engine.nextQuestion(forceMode: mode);
        expect(q, isNotNull);
        expect(q!.options.length, 4);
        final correctTitle = q.options[q.correctIndex].title;
        final sameTitle =
            q.options.where((c) => c.title == correctTitle).length;
        expect(sameTitle, 1,
            reason: '$mode: only one option may hold "$correctTitle"');
        if (correctTitle.contains('Associate Justice')) sawSharedTitleCorrect++;
      }
      expect(sawSharedTitleCorrect, greaterThan(0),
          reason: 'must exercise a shared-title correct answer');
    });
  }
}
