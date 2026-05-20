import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/government/data/node_unlock_service.dart';
import 'package:politiface/features/profile/data/profile_service.dart';
import 'package:politiface/features/session/data/card_review_repository.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

Future<void> _seedNode(
  AppDatabase db, {
  required String id,
  required List<String> requires,
  String status = 'locked',
}) async {
  await db.governmentDao.upsertNode(GovNodesCompanion.insert(
    id: id,
    governmentId: 'g1',
    externalId: id,
    name: id,
    nodeType: 'executive',
    tierOrder: 1,
    unlockRequires: Value(_encodeList(requires)),
  ));
  await db.progressDao.upsert(UserNodeProgressCompanion.insert(
    nodeId: id,
    governmentId: 'g1',
    status: Value(status),
  ));
}

String _encodeList(List<String> items) {
  if (items.isEmpty) return '[]';
  return '[${items.map((s) => '"$s"').join(',')}]';
}

Future<void> _seedDeckWithOneCard(
  AppDatabase db, {
  required String deckId,
  required String nodeId,
  required String cardId,
}) async {
  await db.decksDao.upsertDeck(LocalDecksCompanion.insert(
    id: deckId,
    externalId: deckId,
    name: deckId,
    nodeId: Value(nodeId),
    updatedAt: 0,
  ));
  await db.cardsDao.upsertCard(LocalCardsCompanion.insert(
    id: cardId,
    deckId: deckId,
    externalId: cardId,
    politicianName: cardId,
    title: 'title',
    sourceUrl: 'about:blank',
    updatedAt: 0,
  ));
  await db.reviewsDao.upsertState(
    CardMemoryStatesCompanion(cardId: Value(cardId), isNew: const Value(true)),
  );
}

void main() {
  late AppDatabase db;
  late NodeUnlockService unlock;
  late CardReviewRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    unlock = NodeUnlockService(db);
    repo = CardReviewRepository(db, const FSRS(), ProfileService(db));
  });

  tearDown(() => db.close());

  test('node with all cards reviewed flips to completed', () async {
    await _seedNode(db, id: 'n1', requires: const [], status: 'unlocked');
    await _seedDeckWithOneCard(db, deckId: 'd1', nodeId: 'n1', cardId: 'c1');

    var result = await unlock.recalculate();
    expect(result.completed, isEmpty,
        reason: 'card not yet reviewed → node stays unlocked');

    await repo.recordReview(cardId: 'c1', grade: FSRSGrade.good);
    result = await unlock.recalculate();
    expect(result.completed, ['n1']);
    final p = await db.progressDao.forNode('n1');
    expect(p!.status, 'completed');
  });

  test('locked dependent node unlocks when prereq completes', () async {
    await _seedNode(db, id: 'n1', requires: const [], status: 'unlocked');
    await _seedNode(db, id: 'n2', requires: const ['n1'], status: 'locked');
    await _seedDeckWithOneCard(db, deckId: 'd1', nodeId: 'n1', cardId: 'c1');

    await repo.recordReview(cardId: 'c1', grade: FSRSGrade.good);
    final result = await unlock.recalculate();
    expect(result.completed, contains('n1'));
    expect(result.unlocked, contains('n2'));
    final n2 = await db.progressDao.forNode('n2');
    expect(n2!.status, 'unlocked');
  });

  test('dependent stays locked when only one of two prereqs completes',
      () async {
    await _seedNode(db, id: 'a', requires: const [], status: 'unlocked');
    await _seedNode(db, id: 'b', requires: const [], status: 'unlocked');
    await _seedNode(db, id: 'c', requires: const ['a', 'b'], status: 'locked');
    await _seedDeckWithOneCard(db, deckId: 'da', nodeId: 'a', cardId: 'ca');
    await _seedDeckWithOneCard(db, deckId: 'db', nodeId: 'b', cardId: 'cb');

    await repo.recordReview(cardId: 'ca', grade: FSRSGrade.good);
    final r = await unlock.recalculate();
    expect(r.completed, ['a']);
    expect(r.unlocked, isEmpty,
        reason: 'c has two prereqs; b still incomplete');
  });

  test('node with no decks does not auto-complete', () async {
    await _seedNode(db, id: 'n1', requires: const [], status: 'unlocked');
    final result = await unlock.recalculate();
    expect(result.completed, isEmpty);
  });
}
