import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/daily_challenge/data/daily_challenge_service.dart';

Future<void> _seedCards(AppDatabase db, int n) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: 'd', externalId: 'd', name: 'd', updatedAt: 0,
  ));
  for (var i = 0; i < n; i++) {
    await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
      id: 'card-${i.toString().padLeft(3, '0')}',
      deckId: 'd',
      externalId: 'card-$i',
      politicianName: 'Person $i',
      title: 'T',
      sourceUrl: 'about:blank',
      updatedAt: 0,
    ));
  }
}

void main() {
  late AppDatabase db;
  late DailyChallengeService svc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = DailyChallengeService(db);
  });

  tearDown(() => db.close());

  test('empty DB → null challenge', () async {
    final c = await svc.challengeFor();
    expect(c, isNull);
  });

  test('fewer cards than challenge size returns all cards', () async {
    await _seedCards(db, 3);
    final c = await svc.challengeFor();
    expect(c, isNotNull);
    expect(c!.cardIds.length, 3);
  });

  test('picks 5 unique cards from a larger pool', () async {
    await _seedCards(db, 20);
    final c = await svc.challengeFor();
    expect(c!.cardIds.length, 5);
    expect(c.cardIds.toSet().length, 5, reason: 'no duplicates');
  });

  test('same date → same cards (deterministic)', () async {
    await _seedCards(db, 20);
    final a = await svc.challengeFor(when: DateTime(2026, 5, 19));
    final b = await svc.challengeFor(when: DateTime(2026, 5, 19));
    expect(a!.cardIds, b!.cardIds);
  });

  test('different dates → different cards (usually)', () async {
    await _seedCards(db, 30);
    final a = await svc.challengeFor(when: DateTime(2026, 5, 19));
    // Reset cache so day 2 picks fresh:
    final b = await svc.challengeFor(when: DateTime(2026, 5, 20));
    expect(a!.cardIds, isNot(equals(b!.cardIds)));
  });

  test('recordResult stores grades + share text', () async {
    await _seedCards(db, 10);
    final c = await svc.challengeFor();
    final share = await svc.recordResult(
      date: c!.date,
      grades: const [2, 2, 0, 3, 1],
    );
    expect(share, contains('4/5'),
        reason: '4 of 5 graded above Again (hard/good/good/easy)');
    expect(share, contains('🟩🟩🟥🟦🟧'));

    final played = await svc.challengeFor();
    expect(played!.isPlayed, isTrue);
    expect(played.shareText, share);
    expect(played.grades, const [2, 2, 0, 3, 1]);
  });
}
