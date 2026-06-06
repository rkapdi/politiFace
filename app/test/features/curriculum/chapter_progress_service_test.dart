import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/curriculum/data/chapter_progress_service.dart';
import 'package:politiface/features/curriculum/data/curriculum_loader.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late AppDatabase db;
  late ChapterProgressService service;
  late Curriculum curriculum;

  setUpAll(() async {
    curriculum = await CurriculumLoader().load();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ChapterProgressService(db);
  });

  tearDown(() => db.close());

  test('first call seeds Chapter 1 at day 1', () async {
    final entry = await service.currentProgress(curriculum);
    expect(entry, isNotNull);
    expect(entry!.chapterId, 'ch1.first-principles');
    expect(entry.dayInChapter, 1);
    expect(entry.roundsCompleted, 0);
    expect(entry.completedAt, isNull);
  });

  test('second call returns the same in-progress entry', () async {
    final first = await service.currentProgress(curriculum);
    final second = await service.currentProgress(curriculum);
    expect(second!.chapterId, first!.chapterId);
    expect(second.startedAt, first.startedAt);
  });

  test('recordRoundCompletion advances dayInChapter', () async {
    await service.currentProgress(curriculum); // seed
    final after = await service.recordRoundCompletion(curriculum);
    expect(after.chapterId, 'ch1.first-principles');
    expect(after.dayInChapter, 2);
    expect(after.roundsCompleted, 1);
    expect(after.completedAt, isNull);
  });

  test('chapter completes after `days` rounds, next chapter starts on next currentProgress',
      () async {
    await service.currentProgress(curriculum); // seed Ch1
    final ch1 = curriculum.chapters.first;
    // Play through all of Chapter 1.
    for (var i = 0; i < ch1.days; i++) {
      await service.recordRoundCompletion(curriculum);
    }
    // Last completion marked completedAt.
    final ch1Final = await db.chapterProgressDao.get(
      userId: ChapterProgressService.defaultUserId,
      seasonId: curriculum.season.id,
      chapterId: ch1.id,
    );
    expect(ch1Final?.completedAt, isNotNull);

    // Next call seeds Ch2.
    final next = await service.currentProgress(curriculum);
    expect(next!.chapterId, 'ch2.the-architecture');
    expect(next.dayInChapter, 1);
    expect(next.completedAt, isNull);
  });

  test('completing the final chapter returns null from currentProgress',
      () async {
    // Walk to the end of the season. Each iteration seeds the chapter via
    // currentProgress, then plays through `chapter.days` rounds.
    for (final chapter in curriculum.chapters) {
      final entry = await service.currentProgress(curriculum);
      expect(entry, isNotNull,
          reason: 'Expected to seed ${chapter.id} but got null');
      expect(entry!.chapterId, chapter.id);
      for (var i = 0; i < chapter.days; i++) {
        await service.recordRoundCompletion(curriculum);
      }
    }
    // After the final chapter completes, currentProgress returns null —
    // the season is done.
    final endState = await service.currentProgress(curriculum);
    expect(endState, isNull,
        reason: 'After completing all chapters, season should be done');
  });

  test('recordRoundCompletion throws when no chapter is in progress', () async {
    expect(
      () => service.recordRoundCompletion(curriculum),
      throwsStateError,
    );
  });

  test('seasonProgress returns chapters in start order', () async {
    await service.currentProgress(curriculum); // seed Ch1
    final ch1Days = curriculum.chapters.first.days;
    for (var i = 0; i < ch1Days; i++) {
      await service.recordRoundCompletion(curriculum);
    }
    await service.currentProgress(curriculum); // seed Ch2

    final all = await service.seasonProgress(curriculum.season.id);
    expect(all.length, 2);
    expect(all[0].chapterId, 'ch1.first-principles');
    expect(all[1].chapterId, 'ch2.the-architecture');
    expect(all[0].completedAt, isNotNull);
    expect(all[1].completedAt, isNull);
  });

  test('hasStartedSeason flips true after first currentProgress', () async {
    expect(await service.hasStartedSeason(curriculum.season.id), isFalse);
    await service.currentProgress(curriculum);
    expect(await service.hasStartedSeason(curriculum.season.id), isTrue);
  });
}
