import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/curriculum/data/content_linker.dart';
import 'package:politiface/features/curriculum/data/curriculum_loader.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';
import 'package:politiface/features/round/data/chapter_content_sampler.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase db;
  late ChapterContentSampler sampler;
  late Curriculum curriculum;
  late Chapter chapter;

  setUpAll(() async {
    curriculum = await CurriculumLoader().load();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sampler = ChapterContentSampler(db, ContentLinker(db));
    chapter = curriculum.chapters.first; // Ch1 First Principles (7 items, 2 days)
  });

  tearDown(() => db.close());

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> seedDeckWithCards(int count, {String prefix = 'pool'}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: '${prefix}_deck',
          externalId: '${prefix}_deck_ext',
          name: 'Pool deck',
          updatedAt: now,
        ),);
    for (var i = 0; i < count; i++) {
      await db.into(db.localCards).insert(LocalCardsCompanion.insert(
            id: '${prefix}_card_$i',
            deckId: '${prefix}_deck',
            externalId: '${prefix}_card_ext_$i',
            politicianName: 'Pool $i',
            title: 'Title $i',
            sourceUrl: '',
            updatedAt: now,
          ),);
    }
  }

  Future<void> seedCardForItem(String itemId, {String suffix = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'deck_concepts$suffix',
          externalId: 'deck_concepts$suffix',
          name: 'Concept deck',
          updatedAt: now,
        ),);
    await db.into(db.localCards).insert(LocalCardsCompanion.insert(
          id: 'concept_${itemId.replaceAll('.', '_')}',
          deckId: 'deck_concepts$suffix',
          externalId: itemId,
          politicianName: 'n/a',
          title: 'concept: $itemId',
          sourceUrl: '',
          updatedAt: now,
        ),);
  }

  // ── Tests ──────────────────────────────────────────────────────────────

  test('empty DB + no fallback → returns empty SampledContent', () async {
    final result = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
      allowFallback: false,
    );
    expect(result.isEmpty, isTrue);
    expect(result.unresolvedItemIds, equals(chapter.itemIds));
  });

  test('empty DB + fallback enabled but no pool cards → still empty', () async {
    final result = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    expect(result.isEmpty, isTrue);
  });

  test('fallback fills up to requested count when chapter has zero resolution',
      () async {
    await seedDeckWithCards(10);
    final result = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    expect(result.cards.length, 5);
    // All came from fallback, so sourceItemIds should all be null.
    expect(result.sourceItemIds.every((id) => id == null), isTrue);
    // And every chapter item is unresolved.
    expect(result.unresolvedItemIds.length, chapter.itemIds.length);
  });

  test('chapter resolution preferred over fallback when both available',
      () async {
    // Seed cards for 3 chapter items + a pool of 10 unrelated cards.
    final firstThreeItemIds = chapter.itemIds.take(3).toList();
    for (var i = 0; i < firstThreeItemIds.length; i++) {
      await seedCardForItem(firstThreeItemIds[i], suffix: '_$i');
    }
    await seedDeckWithCards(10);

    final result = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    expect(result.cards.length, 5);
    final fromChapter =
        result.sourceItemIds.where((id) => id != null).length;
    expect(fromChapter, 3,
        reason: 'All 3 chapter-resolved items should be in the sample first',);
    final fromFallback =
        result.sourceItemIds.where((id) => id == null).length;
    expect(fromFallback, 2,
        reason: 'Remaining 2 slots filled by fallback',);
  });

  test('deterministic by date — same date returns same cards', () async {
    await seedDeckWithCards(20);
    final a = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    final b = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    expect(a.cards.map((c) => c.id).toList(),
        equals(b.cards.map((c) => c.id).toList()),);
  });

  test('different date → likely different cards', () async {
    await seedDeckWithCards(20);
    final a = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    final b = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-27',
    );
    final aIds = a.cards.map((c) => c.id).toSet();
    final bIds = b.cards.map((c) => c.id).toSet();
    // With a pool of 20 and pick-5, identical sets across dates is
    // statistically vanishingly unlikely. Assert at least one differs.
    expect(aIds == bIds, isFalse);
  });

  test('cards vs trivia sample for same date pull different subsets',
      () async {
    // Big pool so the deterministic shuffles for cards/trivia produce
    // distinguishable picks.
    await seedDeckWithCards(20);
    final cards = await sampler.sampleCards(
      chapter: chapter,
      count: 5,
      dateIso: '2026-05-26',
    );
    final trivia = await sampler.sampleTrivia(
      chapter: chapter,
      count: 10,
      dateIso: '2026-05-26',
    );
    final cardIds = cards.cards.map((c) => c.id).toSet();
    final triviaIds = trivia.cards.map((c) => c.id).toSet();
    // Overlap is fine, but identical sets would mean the salt isn't
    // working.
    expect(cardIds == triviaIds, isFalse);
  });
}
