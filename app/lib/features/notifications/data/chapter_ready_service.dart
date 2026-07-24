// lib/features/notifications/data/chapter_ready_service.dart
//
// Fires the "your next chapter is ready" nudge the morning after a round
// completes the current chapter. Split into a pure decision function
// (decideChapterNotification — testable without the plugin) and a thin
// service that wires it to settings + the injectable NotificationSender.

import '../../../core/database/drift/app_database.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../round/domain/round_state.dart';
import '../../settings/data/settings_service.dart';
import 'notification_orchestrator.dart';
import 'notification_sender.dart';

const chapterReadyNotificationId = 50;

/// What to show, and when, for a round that just completed. Returned by
/// [decideChapterNotification]; null means no notification is warranted.
class ChapterNotificationPlan {
  const ChapterNotificationPlan({
    required this.title,
    required this.body,
    required this.when,
  });

  final String title;
  final String body;
  final DateTime when;
}

/// Pure: no db, no plugin, no settings lookups. Exercised directly by
/// tests without touching platform channels.
///
/// Fires only when [round] finished the last day of its chapter and there
/// is a next chapter to tease. The body lists up to 3 of the next
/// chapter's day-1 lesson titles as a comma list; [when] is 9:00 AM the
/// day after [now].
ChapterNotificationPlan? decideChapterNotification({
  required DailyRoundState round,
  required Chapter? nextChapter,
  required DateTime now,
}) {
  if (!round.isFinalDay) return null;
  if (round.nextChapterTitle == null || nextChapter == null) return null;

  final titles =
      nextChapter.lessonsForDay(1).map((l) => l.title).take(3).toList();
  final body = titles.isEmpty
      ? 'Up next: a new set of lessons.'
      : 'Up next: ${titles.join(', ')}, and more.';

  final tomorrow =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final when = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);

  return ChapterNotificationPlan(
    title: 'Chapter unlocked: ${round.nextChapterTitle}',
    body: body,
    when: when,
  );
}

/// Thin wrapper: checks the pref, then either cancels the chapter nudge or
/// hands the teaser to the [NotificationOrchestrator] as a candidate, so the
/// brain decides whether and when it actually reaches the user (respecting the
/// daily cap, quiet hours, and repeat suppression like every other category).
class ChapterReadyService {
  ChapterReadyService({
    required AppDatabase db,
    NotificationSender? sender,
    SettingsService? settings,
    NotificationOrchestrator? orchestrator,
  })  : _db = db,
        _sender = sender ?? const PluginNotificationSender(),
        _settings = settings ?? SettingsService(db),
        _orchestrator = orchestrator;

  final AppDatabase _db;
  final NotificationSender _sender;
  final SettingsService _settings;
  final NotificationOrchestrator? _orchestrator;

  /// Best-effort side effect for the round-completion path: never throws,
  /// so it can be called `unawaited` without risking round completion.
  Future<void> onRoundCompleted({
    required DailyRoundState round,
    required Curriculum curriculum,
    DateTime? now,
  }) async {
    try {
      if (!await _settings.chapterNotifEnabled()) {
        await _sender.cancel(chapterReadyNotificationId);
        return;
      }
      final clock = now ?? DateTime.now();
      final nextChapter = curriculum.chapterAfter(round.chapterId);
      final plan = decideChapterNotification(
        round: round,
        nextChapter: nextChapter,
        now: clock,
      );
      if (plan == null) return;
      final orchestrator = _orchestrator ??
          NotificationOrchestrator(
            db: _db,
            sender: _sender,
            settings: _settings,
            now: () => clock,
          );
      await orchestrator.submitChapterCandidate(
        title: plan.title,
        body: plan.body,
        nextChapterTitle: round.nextChapterTitle!,
      );
    } catch (_) {
      // Never block round completion over a notification side effect.
    }
  }
}
