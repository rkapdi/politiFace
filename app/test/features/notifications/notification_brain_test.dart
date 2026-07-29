import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/notifications/domain/notification_brain.dart';

void main() {
  const brain = NotificationBrain();

  BrainContext ctx({
    int hour = 18,
    int firedToday = 0,
    DateTime? lastFired,
    Set<String> recent = const {},
    bool openedToday = false,
    bool fcleEngaged = true,
    int cap = 2,
  }) =>
      BrainContext(
        now: DateTime(2026, 7, 24, hour),
        firedTodayCount: firedToday,
        lastFiredAt: lastFired,
        recentDedupeKeys: recent,
        openedAppToday: openedToday,
        fcleEngaged: fcleEngaged,
        dailyCap: cap,
      );

  NotifCandidate cand(
    NotifKind kind, {
    double relevance = 0.0,
    String dedupe = 'k',
    bool urgent = false,
    int id = 1,
  }) =>
      NotifCandidate(
        kind: kind,
        notificationId: id,
        title: 't',
        body: 'b',
        dedupeKey: dedupe,
        relevance: relevance,
        urgent: urgent,
      );

  test('personal washington outranks a generic memory nudge', () {
    final d = brain.decide(
      [
        cand(NotifKind.memoryRescue, dedupe: 'm'),
        cand(NotifKind.washingtonPersonal, relevance: 1, dedupe: 'w', id: 2),
      ],
      ctx(cap: 1),
    );
    final fired = d.where((x) => x.action == NotifAction.fireNow).toList();
    expect(fired, hasLength(1));
    expect(fired.single.candidate.kind, NotifKind.washingtonPersonal);
  });

  test('exam milestone still leads a personal washington item', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonPersonal, relevance: 1, dedupe: 'w'),
        cand(NotifKind.fcleMilestone, dedupe: 'f'),
      ],
      ctx(cap: 1),
    );
    final fired = d.firstWhere((x) => x.action == NotifAction.fireNow);
    expect(fired.candidate.kind, NotifKind.fcleMilestone);
  });

  test('fcle category is gated off for non-engaged users', () {
    final d = brain.decide(
      [
        cand(NotifKind.fcleMilestone, dedupe: 'f'),
      ],
      ctx(fcleEngaged: false),
    );
    expect(d.single.action, NotifAction.drop);
    expect(d.single.reason, contains('not fcle-engaged'));
  });

  test('daily cap is hard', () {
    final d = brain.decide(
      [
        cand(NotifKind.fcleMilestone, dedupe: 'a'),
        cand(NotifKind.washingtonGeneral, dedupe: 'b', id: 2),
        cand(NotifKind.washingtonGeneral, dedupe: 'c', id: 3),
      ],
      ctx(),
    );
    expect(d.where((x) => x.action == NotifAction.fireNow), hasLength(2));
    expect(d.where((x) => x.action == NotifAction.drop), hasLength(1));
  });

  test('already-fired count eats into the cap', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonGeneral, dedupe: 'b'),
      ],
      ctx(firedToday: 2),
    );
    expect(d.single.action, NotifAction.drop);
    expect(d.single.reason, contains('daily cap'));
  });

  test('repeat within cooldown is suppressed', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonGeneral, dedupe: 'eo:14413'),
      ],
      ctx(recent: {'eo:14413'}),
    );
    expect(d.single.action, NotifAction.drop);
    expect(d.single.reason, contains('cooldown'));
  });

  test('quiet hours defer non-urgent to the preferred slot', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonGeneral, dedupe: 'w'),
      ],
      ctx(hour: 23),
    );
    expect(d.single.action, NotifAction.deferToPreferredHour);
    expect(d.single.scheduledFor!.hour, 18);
    // 11pm defers to 6pm the NEXT day.
    expect(d.single.scheduledFor!.day, 25);
  });

  test('urgent bypasses quiet hours', () {
    final d = brain.decide(
      [
        cand(NotifKind.fcleMilestone, dedupe: 'f', urgent: true),
      ],
      ctx(hour: 23),
    );
    expect(d.single.action, NotifAction.fireNow);
  });

  test('min gap defers non-urgent', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonGeneral, dedupe: 'w'),
      ],
      ctx(lastFired: DateTime(2026, 7, 24, 17)),
    );
    expect(d.single.action, NotifAction.deferToPreferredHour);
    expect(d.single.reason, contains('min gap'));
  });

  test('opened-today holds memory but lets news through', () {
    final memory = brain.decide(
      [
        cand(NotifKind.memoryRescue, dedupe: 'm'),
      ],
      ctx(openedToday: true),
    );
    expect(memory.single.action, NotifAction.drop);
    expect(memory.single.reason, contains('already active'));

    final news = brain.decide(
      [
        cand(NotifKind.washingtonPersonal, relevance: 1, dedupe: 'w'),
      ],
      ctx(openedToday: true),
    );
    expect(news.single.action, NotifAction.fireNow);
  });

  test('urgent fires even when the user was active today', () {
    final d = brain.decide(
      [
        cand(NotifKind.fcleMilestone, dedupe: 'f', urgent: true),
      ],
      ctx(openedToday: true),
    );
    expect(d.single.action, NotifAction.fireNow);
  });

  test('duplicate dedupe keys in one batch collapse to one', () {
    final d = brain.decide(
      [
        cand(NotifKind.washingtonGeneral, dedupe: 'same'),
        cand(NotifKind.washingtonGeneral, dedupe: 'same', id: 2),
      ],
      ctx(),
    );
    expect(d.where((x) => x.action == NotifAction.fireNow), hasLength(1));
    expect(
      d.where((x) => x.reason.contains('duplicate within this batch')),
      hasLength(1),
    );
  });
}
