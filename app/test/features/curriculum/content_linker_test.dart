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

  test('resolves a card when externalId matches curriculum item id',
      () async {
    // Future contract: a concept-deck card with externalId equal to a
    // curriculum item id should auto-resolve. Validate the wiring works
    // by seeding a fake card.
    const itemId = 'const.supreme-law';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'deck_test',
          externalId: 'test-deck',
          name: 'Test deck',
          updatedAt: now,
        ),);
    await db.into(db.localCards).insert(LocalCardsCompanion.insert(
          id: 'card_test',
          deckId: 'deck_test',
          externalId: itemId,
          politicianName: 'n/a',
          title: 'The Constitution is supreme',
          sourceUrl: '',
          updatedAt: now,
        ),);

    final item = curriculum.itemById(itemId)!;
    final card = await linker.cardFor(item);
    expect(card, isNotNull);
    expect(card!.externalId, itemId);
  });

  test('cardsFor bulk-resolves; missing items omitted', () async {
    const present = 'const.supreme-law';
    const missing = 'decl.purpose';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'deck_test',
          externalId: 'test-deck',
          name: 'Test deck',
          updatedAt: now,
        ),);
    await db.into(db.localCards).insert(LocalCardsCompanion.insert(
          id: 'card_present',
          deckId: 'deck_test',
          externalId: present,
          politicianName: 'n/a',
          title: 'Present card',
          sourceUrl: '',
          updatedAt: now,
        ),);

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
}
