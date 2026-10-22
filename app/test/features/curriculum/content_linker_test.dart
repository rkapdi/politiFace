import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/curriculum/data/content_linker.dart';
import 'package:politiface/features/curriculum/data/curriculum_loader.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase db;
  late ContentLinker linker;
  late Curriculum curriculum;

  setUpAll(() async {
    curriculum = await CurriculumLoader().load();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    linker = ContentLinker(db);
  });

  tearDown(() => db.close());

  test('returns null for items with no backing card (Phase 1 baseline)',
      () async {
    // Phase 1 stub: no curriculum items have been wired to cards yet, so
    // every lookup should return null cleanly (no exceptions).
    final item = curriculum.itemById('const.supreme-law')!;
    expect(await linker.cardFor(item), isNull);
  });

  test('resolves a card when externalId matches curriculum item id', () async {
    // Future contract: a concept-deck card with externalId equal to a
    // curriculum item id should auto-resolve. Validate the wiring works
    // by seeding a fake card.
    const itemId = 'const.supreme-law';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.into(db.localDecks).insert(
          LocalDecksCompanion.insert(
            id: 'deck_test',
            externalId: 'test-deck',
            name: 'Test deck',
            updatedAt: now,
          ),
        );
    await db.into(db.localCards).insert(
          LocalCardsCompanion.insert(
            id: 'card_test',
            deckId: 'deck_test',
            externalId: itemId,
            politicianName: 'n/a',
            title: 'The Constitution is supreme',
            sourceUrl: '',
            updatedAt: now,
          ),
        );

    final item = curriculum.itemById(itemId)!;
    final card = await linker.cardFor(item);
    expect(card, isNotNull);
    expect(card!.externalId, itemId);
  });

  test('cardsFor bulk-resolves; missing items omitted', () async {
    const present = 'const.supreme-law';
    const missing = 'decl.purpose';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.into(db.localDecks).insert(
          LocalDecksCompanion.insert(
            id: 'deck_test',
            externalId: 'test-deck',
            name: 'Test deck',
            updatedAt: now,
          ),
        );
    await db.into(db.localCards).insert(
          LocalCardsCompanion.insert(
            id: 'card_present',
            deckId: 'deck_test',
            externalId: present,
            politicianName: 'n/a',
            title: 'Present card',
            sourceUrl: '',
            updatedAt: now,
          ),
        );

    final items = [
      curriculum.itemById(present)!,
      curriculum.itemById(missing)!,
    ];
    final result = await linker.cardsFor(items);
    expect(result.keys, contains(present));
    expect(result.keys, isNot(contains(missing)));
  });

  test('resolvedItemCount is 0 for a fresh database', () async {
    expect(await linker.resolvedItemCount(curriculum), 0);
  });

  group('card_ids resolution (face_card items)', () {
    Future<void> seedCard(String id, {bool active = true}) async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.into(db.localDecks).insertOnConflictUpdate(
            LocalDecksCompanion.insert(
              id: 'deck_faces',
              externalId: 'deck-faces',
              name: 'Faces',
              updatedAt: now,
            ),
          );
      await db.into(db.localCards).insert(
            LocalCardsCompanion.insert(
              id: id,
              deckId: 'deck_faces',
              externalId: 'ext-$id',
              politicianName: 'Name $id',
              title: 'Title',
              sourceUrl: '',
              updatedAt: now,
              isActive: Value(active),
            ),
          );
    }

    test('resolves a face_card item to its named card', () async {
      // exec.president-basics names card_ids: [us-exec-president].
      await seedCard('us-exec-president');
      final item = curriculum.itemById('exec.president-basics')!;
      expect(item.cardIds, contains('us-exec-president'));
      final card = await linker.cardFor(item);
      expect(card, isNotNull);
      expect(card!.id, 'us-exec-president');
    });

    test('honors card_ids priority order, skipping the absent first choice',
        () async {
      // exec.cabinet names [us-exec-sec-state, us-cabinet-treasury]. With only
      // the second present, it should resolve to the second.
      await seedCard('us-cabinet-treasury');
      final item = curriculum.itemById('exec.cabinet')!;
      expect(card0(item), 'us-exec-sec-state');
      final card = await linker.cardFor(item);
      expect(card!.id, 'us-cabinet-treasury');

      // Once the first choice exists, it wins.
      await seedCard('us-exec-sec-state');
      final card2 = await linker.cardFor(item);
      expect(card2!.id, 'us-exec-sec-state');
    });

    test('skips inactive cards', () async {
      await seedCard('us-exec-president', active: false);
      final item = curriculum.itemById('exec.president-basics')!;
      expect(await linker.cardFor(item), isNull);
    });
  });
}

String card0(CurriculumItem item) => item.cardIds.first;
