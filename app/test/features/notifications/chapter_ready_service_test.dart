import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';
import 'package:politiface/features/notifications/data/chapter_ready_service.dart';
import 'package:politiface/features/notifications/data/notification_sender.dart';
import 'package:politiface/features/round/domain/round_state.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

class _ScheduledCall {
  _ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });
  final int id;
  final String title;
  final String body;
  final DateTime when;
}

/// Fakes the plugin so tests never touch a platform channel. Optionally
/// throws from [scheduleAt] to exercise the best-effort swallow path.
class FakeNotificationSender implements NotificationSender {
  bool authorized = true;
  bool throwOnSchedule = false;
  final scheduled = <_ScheduledCall>[];
  final cancelled = <int>[];

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (throwOnSchedule) throw Exception('platform channel unavailable');
    scheduled.add(_ScheduledCall(id: id, title: title, body: body, when: when));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

DailyRoundState roundAt({
  required int dayInChapter,
  required int daysInChapter,
  String? nextChapterTitle,
  String chapterId = 'ch1',
}) =>
    DailyRoundState(
      dateIso: '2026-07-12',
      chapterId: chapterId,
      chapterTitle: 'Chapter One',
      chapterSubtitle: 'Subtitle',
      dayInChapter: dayInChapter,
      daysInChapter: daysInChapter,
      phase: RoundPhase.done,
      cards: const [],
      trivia: const [],
      nextChapterTitle: nextChapterTitle,
    );

Chapter chapterWithLessons(List<String> lessonTitles, {String id = 'ch2'}) =>
    Chapter(
      id: id,
      order: 2,
      title: 'Chapter Two',
      subtitle: 'Subtitle Two',
      days: 2,
      itemIds: const [],
      lessons: [
        for (var i = 0; i < lessonTitles.length; i++)
          Lesson(
            id: 'lesson-$i',
            day: 1,
            title: lessonTitles[i],
            body: 'Body text for lesson $i.',
          ),
      ],
    );

void main() {
  group('decideChapterNotification (pure)', () {
    final now = DateTime(2026, 7, 12, 15, 30);

    test('null when the round did not finish the chapter', () {
      final round = roundAt(
        dayInChapter: 1,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(['A', 'B']);
      expect(
        decideChapterNotification(round: round, nextChapter: next, now: now),
        isNull,
      );
    });

    test('null when there is no next chapter title', () {
      final round = roundAt(dayInChapter: 2, daysInChapter: 2);
      expect(
        decideChapterNotification(round: round, nextChapter: null, now: now),
        isNull,
      );
    });

    test('null when nextChapterTitle is set but the Chapter object is missing',
        () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      expect(
        decideChapterNotification(round: round, nextChapter: null, now: now),
        isNull,
      );
    });

    test('builds title + comma-list body from up to 3 day-1 lesson titles', () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(['Federalism', 'The Bill of Rights']);

      final plan =
          decideChapterNotification(round: round, nextChapter: next, now: now);

      expect(plan, isNotNull);
      expect(plan!.title, 'Chapter unlocked: Chapter Two');
      expect(plan.body, 'Up next: Federalism, The Bill of Rights, and more.');
    });

    test('caps the lesson list at 3 titles even when more are authored', () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(['One', 'Two', 'Three', 'Four']);

      final plan =
          decideChapterNotification(round: round, nextChapter: next, now: now);

      expect(plan!.body, 'Up next: One, Two, Three, and more.');
    });

    test(
        'falls back to generic body when the next chapter has no day-1 '
        'lessons authored yet', () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(const []);

      final plan =
          decideChapterNotification(round: round, nextChapter: next, now: now);

      expect(plan!.body, 'Up next: a new set of lessons.');
    });

    test('schedules for 9:00 AM the day after now', () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(['A']);

      final plan =
          decideChapterNotification(round: round, nextChapter: next, now: now);

      expect(plan!.when, DateTime(2026, 7, 13, 9));
    });

    test('has no em-dashes in title or body (house style)', () {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      final next = chapterWithLessons(['A', 'B', 'C']);

      final plan =
          decideChapterNotification(round: round, nextChapter: next, now: now);

      expect(plan!.title.contains('—'), isFalse);
      expect(plan.body.contains('—'), isFalse);
    });
  });

  group('ChapterReadyService (wired to settings + a fake sender)', () {
    late AppDatabase db;
    late SettingsService settings;
    late FakeNotificationSender sender;
    late Curriculum curriculum;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsService(db);
      sender = FakeNotificationSender();
      curriculum = Curriculum(
        version: 1,
        locale: 'en',
        season: const Season(
          id: 'season-1',
          title: 'Civic Foundations',
          subtitle: '',
          totalChapters: 2,
          estimatedDays: 4,
        ),
        chapters: [
          const Chapter(
            id: 'ch1',
            order: 1,
            title: 'Chapter One',
            subtitle: '',
            days: 2,
            itemIds: [],
          ),
          chapterWithLessons(['Federalism', 'The Bill of Rights']),
        ],
        branches: const [],
      );
    });

    tearDown(() => db.close());

    ChapterReadyService svc() =>
        ChapterReadyService(settings: settings, sender: sender);

    test('schedules the notification when the pref is on and authorized',
        () async {
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      await svc().onRoundCompleted(
        round: round,
        curriculum: curriculum,
        now: DateTime(2026, 7, 12, 15),
      );

      expect(sender.scheduled, hasLength(1));
      expect(sender.scheduled.single.id, chapterReadyNotificationId);
      expect(sender.scheduled.single.title, 'Chapter unlocked: Chapter Two');
    });

    test('does nothing when the round did not finish the chapter', () async {
      final round = roundAt(
        dayInChapter: 1,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );
      await svc().onRoundCompleted(round: round, curriculum: curriculum);

      expect(sender.scheduled, isEmpty);
    });

    test('cancels rather than schedules when the pref is off', () async {
      await settings.setChapterNotifEnabled(false);
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );

      await svc().onRoundCompleted(round: round, curriculum: curriculum);

      expect(sender.scheduled, isEmpty);
      expect(sender.cancelled, [chapterReadyNotificationId]);
    });

    test('does not schedule when notifications are not authorized', () async {
      sender.authorized = false;
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );

      await svc().onRoundCompleted(round: round, curriculum: curriculum);

      expect(sender.scheduled, isEmpty);
    });

    test('never throws even if the sender blows up (best-effort)', () async {
      sender.throwOnSchedule = true;
      final round = roundAt(
        dayInChapter: 2,
        daysInChapter: 2,
        nextChapterTitle: 'Chapter Two',
      );

      await expectLater(
        svc().onRoundCompleted(round: round, curriculum: curriculum),
        completes,
      );
    });
  });
}
