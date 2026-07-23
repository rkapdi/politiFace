import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
  });

  tearDown(() => db.close());

  test('crash reporting defaults to ON, anonymous diagnostics posture',
      () async {
    expect(await settings.crashReportsEnabled(), true);
  });

  test('crash reporting opt-in round-trips and can be revoked', () async {
    await settings.setCrashReportsEnabled(true);
    expect(await settings.crashReportsEnabled(), true);
    // The same key main.dart reads before deciding to init Sentry.
    expect(await db.metaDao.get(SettingsService.kCrashReports), '1');

    await settings.setCrashReportsEnabled(false);
    expect(await settings.crashReportsEnabled(), false);
  });

  test('resetProgress returns crash reporting to the default (on)',
      () async {
    await settings.setCrashReportsEnabled(false);
    await settings.resetProgress();
    expect(await settings.crashReportsEnabled(), true);
  });

  test('sound effects default to ON when the preference is unset', () async {
    expect(await settings.soundEffectsEnabled(), true);
  });

  test('sound effects toggle round-trips', () async {
    await settings.setSoundEffectsEnabled(false);
    expect(await settings.soundEffectsEnabled(), false);

    await settings.setSoundEffectsEnabled(true);
    expect(await settings.soundEffectsEnabled(), true);
  });

  test('resetProgress reverts sound effects to the default ON', () async {
    await settings.setSoundEffectsEnabled(false);
    await settings.resetProgress();
    expect(await settings.soundEffectsEnabled(), true);
  });

  test('resetProgress empties every user-state table', () async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.cardMemoryStates).insert(
          CardMemoryStatesCompanion.insert(cardId: 'card-1'),
        );
    await db.into(db.reviewLogs).insert(
          ReviewLogsCompanion.insert(
            cardId: 'card-1',
            reviewedAt: now,
            grade: 2,
            stability: 1,
            difficulty: 5,
            retrievability: 1,
            intervalDays: 1,
          ),
        );
    await db.into(db.userNodeProgress).insert(
          UserNodeProgressCompanion.insert(
            nodeId: 'node-1',
            governmentId: 'us-federal',
          ),
        );
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'streak.count', value: '5'),
        );
    await db.into(db.fcleAnswers).insert(
          FcleAnswersCompanion.insert(
            questionId: 'q-1',
            domain: 'D1',
            correct: true,
            answeredAt: now,
          ),
        );
    await db.into(db.completedRuns).insert(
          CompletedRunsCompanion.insert(
            id: 'run-1',
            mode: 'trivia',
            completedAt: now,
          ),
        );
    await db.into(db.chapterProgress).insert(
          ChapterProgressCompanion.insert(
            seasonId: 'season-1',
            chapterId: 'chapter-1',
            startedAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.dailyRounds).insert(
          DailyRoundsCompanion.insert(
            dateIso: '2026-07-12',
            chapterId: 'chapter-1',
            dayInChapter: 1,
            startedAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.outboxEvents).insert(
          OutboxEventsCompanion.insert(
            eventId: 'event-1',
            type: 'answer',
            clientTs: now,
            createdAt: now,
          ),
        );

    await settings.resetProgress();

    expect(await db.select(db.cardMemoryStates).get(), isEmpty);
    expect(await db.select(db.reviewLogs).get(), isEmpty);
    expect(await db.select(db.userNodeProgress).get(), isEmpty);
    expect(await db.select(db.appMeta).get(), isEmpty);
    expect(await db.select(db.fcleAnswers).get(), isEmpty);
    expect(await db.select(db.completedRuns).get(), isEmpty);
    expect(await db.select(db.chapterProgress).get(), isEmpty);
    expect(await db.select(db.dailyRounds).get(), isEmpty);
    expect(await db.select(db.outboxEvents).get(), isEmpty);
  });
}
