import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/curriculum/data/chapter_deck_progress.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase db;
  late ChapterDeckProgressService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ChapterDeckProgressService(db);
  });

  tearDown(() => db.close());

  Chapter chapterWithDecks(List<ChapterDeckRef> decks) => Chapter(
        id: 'chX',
        order: 1,
        title: 'Test Chapter',
        subtitle: 'Sub',
        days: 1,
        itemIds: const [],
        decks: decks,
      );

  Future<void> seedDeck() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(
          LocalDecksCompanion.insert(
            id: 'deck_test',
            externalId: 'test-deck',
            name: 'Test Deck',
            updatedAt: now,
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db.into(db.localCards).insert(
            LocalCardsCompanion.insert(
              id: 'card_$i',
              deckId: 'deck_test',
              externalId: 'card_ext_$i',
              politicianName: 'Name $i',
              title: 'Title $i',
              sourceUrl: '',
              updatedAt: now,
            ),
          );
    }
  }

  test('counts studied and strong cards over the whole deck', () async {
    await seedDeck();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // card_0: reviewed an hour ago with high stability — studied + strong.
    await db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: const Value('card_0'),
        isNew: const Value(false),
        stability: const Value(10),
        lastReviewedAt: Value(now - 3600),
        reviewCount: const Value(1),
      ),
    );
    // card_1: reviewed 400 days ago with low stability — studied, not
    // strong (retrievability has decayed far below the threshold).
    await db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: const Value('card_1'),
        isNew: const Value(false),
        stability: const Value(1),
        lastReviewedAt: Value(now - 400 * 86400),
        reviewCount: const Value(1),
      ),
    );
    // card_2: never encountered (no state row) — neither.

    final chapter = chapterWithDecks(
      const [
        ChapterDeckRef(id: 'test-deck', title: 'Fallback Title'),
      ],
    );
    final result = await service.forChapter(chapter);
    expect(result, hasLength(1));
    final progress = result.single;
    expect(progress.deckName, 'Test Deck');
    expect(progress.totalCards, 3);
    expect(progress.studiedCards, 2);
    expect(progress.strongCards, 1);
    expect(progress.isAvailable, isTrue);
  });

  test('planned ref reports unavailable without querying the DB', () async {
    final chapter = chapterWithDecks(
      const [
        ChapterDeckRef(
            id: 'us-concepts-lawmaking',
            title: 'Lawmaking Concepts',
            planned: true,),
      ],
    );
    final result = await service.forChapter(chapter);
    final progress = result.single;
    expect(progress.isAvailable, isFalse);
    expect(progress.deckName, 'Lawmaking Concepts');
    expect(progress.totalCards, 0);
  });

  test('unseeded ref falls back to the ref title', () async {
    final chapter = chapterWithDecks(
      const [
        ChapterDeckRef(id: 'never-seeded', title: 'Yaml Title'),
      ],
    );
    final result = await service.forChapter(chapter);
    final progress = result.single;
    expect(progress.deckName, 'Yaml Title');
    expect(progress.isAvailable, isFalse);
  });
}
