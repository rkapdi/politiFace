import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/curriculum/data/curriculum_loader.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';

void main() {
  // Loads the real bundled YAML — exercises the actual asset path and
  // validates the v1 curriculum is internally consistent. Tests that
  // touch the file system bind to the real rootBundle via
  // TestWidgetsFlutterBinding.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('loads the bundled us_civics.yaml without error', () async {
    final curriculum = await CurriculumLoader().load();
    expect(curriculum.version, greaterThanOrEqualTo(1));
    expect(curriculum.locale, 'en-US');
  });

  test('season has the expected shape', () async {
    final curriculum = await CurriculumLoader().load();
    expect(curriculum.season.id, 'us-civics-season-1');
    expect(curriculum.season.totalChapters, 6);
    expect(curriculum.chapters.length, curriculum.season.totalChapters);
  });

  test('all 5 branches present with concept nodes', () async {
    final curriculum = await CurriculumLoader().load();
    final ids = curriculum.branches.map((b) => b.id).toSet();
    expect(
      ids,
      containsAll(<String>[
        'foundations',
        'legislative',
        'executive',
        'judicial',
        'state-local',
      ]),
    );
    for (final branch in curriculum.branches) {
      expect(branch.conceptNodes, isNotEmpty,
          reason: 'branch ${branch.id} has no concept nodes',);
    }
  });

  test('chapter item_ids all resolve to known curriculum items', () async {
    // The loader validates this on parse — if it threw, the test fails.
    // We re-check explicitly so the test surface communicates the
    // invariant.
    final curriculum = await CurriculumLoader().load();
    for (final chapter in curriculum.chapters) {
      for (final id in chapter.itemIds) {
        expect(curriculum.itemById(id), isNotNull,
            reason: 'chapter ${chapter.id} references missing item $id',);
      }
    }
  });

  test('every curriculum item belongs to exactly one chapter', () async {
    final curriculum = await CurriculumLoader().load();
    final itemToChapters = <String, List<String>>{};
    for (final chapter in curriculum.chapters) {
      for (final id in chapter.itemIds) {
        (itemToChapters[id] ??= []).add(chapter.id);
      }
    }
    final duplicates = itemToChapters.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key} -> ${e.value.join(", ")}')
        .toList();
    expect(duplicates, isEmpty,
        reason: 'curriculum items assigned to multiple chapters: $duplicates',);

    final orphans = curriculum.allItems
        .where((i) => !itemToChapters.containsKey(i.id))
        .map((i) => i.id)
        .toList();
    expect(orphans, isEmpty,
        reason: 'curriculum items not assigned to any chapter: $orphans',);
  });

  test('chapterAfter walks the season in order, returns null past the end',
      () async {
    final curriculum = await CurriculumLoader().load();
    for (var i = 0; i < curriculum.chapters.length - 1; i++) {
      final cur = curriculum.chapters[i];
      final next = curriculum.chapterAfter(cur.id);
      expect(next, isNotNull);
      expect(next!.order, cur.order + 1);
    }
    final last = curriculum.chapters.last;
    expect(curriculum.chapterAfter(last.id), isNull);
  });

  test('chapterForItem returns the owning chapter for known items',
      () async {
    final curriculum = await CurriculumLoader().load();
    // decl.purpose lives in Chapter 1 (First Principles).
    final ch = curriculum.chapterForItem('decl.purpose');
    expect(ch?.id, 'ch1.first-principles');
  });

  test('item_count is at least the CORE-tier minimum (30 core items)',
      () async {
    final curriculum = await CurriculumLoader().load();
    final core = curriculum.allItems
        .where((i) => i.tier == CurriculumTier.core)
        .toList();
    expect(core.length, greaterThanOrEqualTo(30));
  });

  test('every item has at least one source attribution', () async {
    final curriculum = await CurriculumLoader().load();
    for (final item in curriculum.allItems) {
      expect(item.sources, isNotEmpty,
          reason: 'item ${item.id} has no source attribution',);
    }
  });

  // ── Lesson layer (Phase 6) ────────────────────────────────────────────

  test('chapter 1 carries lessons for both days with valid related cards',
      () async {
    final curriculum = await CurriculumLoader().load();
    final ch1 = curriculum.chapters.first;
    expect(ch1.lessons, isNotEmpty);
    expect(ch1.lessonsForDay(1), hasLength(3));
    expect(ch1.lessonsForDay(2), hasLength(3));
    for (final lesson in ch1.lessons) {
      expect(lesson.body, isNotEmpty);
      expect(lesson.body, isNot(endsWith('\n')));
      // Every related card id must be a curriculum item of this chapter —
      // that is the linker convention (card id == item id).
      for (final cardId in lesson.relatedCardIds) {
        expect(ch1.itemIds, contains(cardId),
            reason: 'lesson ${lesson.id} references $cardId',);
      }
    }
  });

  test('chapters without lessons parse fine (lessons optional)', () async {
    final curriculum = await CurriculumLoader().load();
    // Not all chapters are authored yet — that must never break parsing.
    expect(curriculum.chapters, hasLength(6));
  });

  test('every chapter carries lessons, each within range and self-referential',
      () async {
    final curriculum = await CurriculumLoader().load();
    for (final ch in curriculum.chapters) {
      expect(ch.lessons, isNotEmpty, reason: '${ch.id} has no lessons');
      for (final lesson in ch.lessons) {
        expect(lesson.body, isNotEmpty);
        expect(lesson.body, isNot(endsWith('\n')));
        expect(lesson.day, inInclusiveRange(1, ch.days),
            reason: '${lesson.id} day ${lesson.day} outside ${ch.id}',);
        // related_cards must name items belonging to this chapter (the
        // briefing drills what it just taught).
        for (final cardId in lesson.relatedCardIds) {
          expect(ch.itemIds, contains(cardId),
              reason: 'lesson ${lesson.id} references $cardId not in ${ch.id}',);
        }
        // Every lesson cites a source.
        expect(lesson.source, isNotNull, reason: '${lesson.id} has no source');
      }
    }
  });
}
