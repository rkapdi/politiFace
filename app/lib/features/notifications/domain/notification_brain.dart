// lib/features/notifications/domain/notification_brain.dart
//
// The on-device notification brain: a pure policy engine that decides
// whether, when, and which of several candidate notifications actually
// reaches the user. Everything it needs is computed on the device from
// the user's own learning state; nothing about the decision leaves the
// phone. That is the whole point: notifications that feel personal
// because they are, without a server ever holding a behavioral profile.
//
// The engine is deliberately pure (no I/O, no plugins, no clock of its
// own): callers gather candidates and a context snapshot, call [decide],
// and act on the returned decisions. This makes the judgment testable to
// the minute.
//
// Design tenets, in priority order:
//   1. Never nag. A hard daily cap, quiet hours, a global minimum gap,
//      and suppression when the user has already been in the app today.
//      Caring means mostly staying quiet.
//   2. Relevance over recency. A Washington item whose sponsor is a face
//      the user has actually learned outranks a generic memory nudge.
//   3. No noise off-topic. FCLE nudges only reach FCLE-engaged users;
//      the civics-curious user who never touched the exam never hears
//      about it.
//   4. Right moment. Non-urgent notifications defer to the hour the user
//      is usually in the app, learned locally.

import 'package:flutter/foundation.dart';

/// What kind of moment a candidate represents. Order encodes base
/// priority: earlier is more important.
enum NotifKind {
  /// An FCLE-engaged user is close to a coverage or readiness milestone,
  /// or an exam is near. The most consequential category for the wedge.
  fcleMilestone,

  /// Cards are about to slip below recall. FSRS knows the literal hour.
  memoryRescue,

  /// Congress did something, made personal: a sponsor or signer the user
  /// has learned, or their home-state delegation.
  washingtonPersonal,

  /// Congress did something, general interest.
  washingtonGeneral,

  /// The next chapter has unlocked.
  chapterReady,
}

/// Base weight per kind. Relevance adds on top, so a highly personal
/// washington item can pass a low-relevance memory nudge, but exam-close
/// milestones still lead.
int _baseWeight(NotifKind kind) => switch (kind) {
      NotifKind.fcleMilestone => 500,
      NotifKind.memoryRescue => 300,
      NotifKind.washingtonPersonal => 280,
      NotifKind.chapterReady => 200,
      NotifKind.washingtonGeneral => 120,
    };

/// A single thing the app could tell the user, already rendered to copy.
@immutable
class NotifCandidate {
  const NotifCandidate({
    required this.kind,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.dedupeKey,
    this.relevance = 0.0,
    this.route = '/',
    this.urgent = false,
  });

  final NotifKind kind;

  /// Platform notification id (stable per slot so a newer one replaces an
  /// older of the same slot rather than stacking).
  final int notificationId;

  final String title;
  final String body;

  /// Identity of this exact message, so the same thing is never repeated
  /// within its cooldown (e.g. "eo:14413", "rescue:2026-07-24",
  /// "fcle:coverage:31").
  final String dedupeKey;

  /// Personal relevance in [0, 1]. For washington items, how strongly it
  /// connects to what the user knows or where they live; for memory, how
  /// much valuable material is slipping.
  final double relevance;

  /// Deep link on tap.
  final String route;

  /// Exam-critical timing: bypasses the already-active-today suppression
  /// (never the daily cap or quiet hours). Reserved for real deadlines.
  final bool urgent;

  int get score =>
      _baseWeight(kind) + (relevance.clamp(0.0, 1.0) * 100).round();
}

/// What the engine decided for one candidate.
enum NotifAction { fireNow, deferToPreferredHour, drop }

@immutable
class NotifDecision {
  const NotifDecision({
    required this.candidate,
    required this.action,
    required this.reason,
    this.scheduledFor,
  });

  final NotifCandidate candidate;
  final NotifAction action;

  /// Why, for logs and tests. Not user-facing.
  final String reason;

  /// Set when [action] is deferToPreferredHour.
  final DateTime? scheduledFor;
}

/// A snapshot of everything the engine reasons over. All of it is derived
/// locally by the caller.
@immutable
class BrainContext {
  const BrainContext({
    required this.now,
    required this.firedTodayCount,
    required this.lastFiredAt,
    required this.recentDedupeKeys,
    required this.openedAppToday,
    required this.fcleEngaged,
    this.dailyCap = 2,
    this.minGap = const Duration(hours: 3),
    this.quietStartHour = 21,
    this.quietEndHour = 8,
    this.preferredHour = 18,
    this.dedupeCooldown = const Duration(days: 3),
  });

  final DateTime now;

  /// How many notifications have already fired today (local day).
  final int firedTodayCount;

  /// When the last notification fired, or null if none recently.
  final DateTime? lastFiredAt;

  /// Dedupe keys fired within the cooldown window, for repeat suppression.
  final Set<String> recentDedupeKeys;

  /// Whether the user has opened the app today. If so, low-priority
  /// notifications are held: they will see it when they play anyway.
  final bool openedAppToday;

  /// Whether the user has engaged with FCLE at all (class member or recent
  /// FCLE activity). Gates the entire fcleMilestone category to zero noise
  /// for everyone else.
  final bool fcleEngaged;

  final int dailyCap;
  final Duration minGap;

  /// Quiet hours as local hours [start, end) wrapping midnight, e.g.
  /// 21..8 means 9pm through 8am are quiet.
  final int quietStartHour;
  final int quietEndHour;

  /// The hour (0-23) the user is usually active, learned locally. Deferred
  /// notifications land here.
  final int preferredHour;

  final Duration dedupeCooldown;

  bool get inQuietHours {
    final h = now.hour;
    if (quietStartHour <= quietEndHour) {
      return h >= quietStartHour && h < quietEndHour;
    }
    return h >= quietStartHour || h < quietEndHour;
  }

  /// The next occurrence of [preferredHour] that is not itself in quiet
  /// hours, at least a little in the future.
  DateTime get nextPreferredSlot {
    var slot = DateTime(now.year, now.month, now.day, preferredHour);
    if (!slot.isAfter(now.add(const Duration(minutes: 1)))) {
      slot = slot.add(const Duration(days: 1));
    }
    return slot;
  }
}

/// The engine. Stateless; every input arrives in [context].
class NotificationBrain {
  const NotificationBrain();

  /// Decides what to do with each candidate. Returns a decision per
  /// candidate, highest-value first. At most [BrainContext.dailyCap] end
  /// up as fireNow/deferToPreferredHour across the day; the rest drop.
  List<NotifDecision> decide(
    List<NotifCandidate> candidates,
    BrainContext context,
  ) {
    final decisions = <NotifDecision>[];

    // Category gate + repeat suppression first, so they never consume a
    // budget slot.
    final eligible = <NotifCandidate>[];
    for (final c in candidates) {
      if (c.kind == NotifKind.fcleMilestone && !context.fcleEngaged) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.drop,
            reason: 'fcle category gated: user not fcle-engaged',
          ),
        );
        continue;
      }
      if (context.recentDedupeKeys.contains(c.dedupeKey)) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.drop,
            reason: 'already sent within cooldown',
          ),
        );
        continue;
      }
      eligible.add(c);
    }

    // Highest score first; stable for equal scores by original order.
    eligible.sort((a, b) => b.score.compareTo(a.score));

    // Remaining budget for today.
    var remaining = context.dailyCap - context.firedTodayCount;
    final gapClear = context.lastFiredAt == null ||
        context.now.difference(context.lastFiredAt!) >= context.minGap;

    final seenDedupe = <String>{};
    for (final c in eligible) {
      // Never two of the exact same message in one pass.
      if (!seenDedupe.add(c.dedupeKey)) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.drop,
            reason: 'duplicate within this batch',
          ),
        );
        continue;
      }

      if (remaining <= 0) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.drop,
            reason: 'daily cap reached',
          ),
        );
        continue;
      }

      // Already opened the app today: hold anything that is not urgent and
      // not a fresh external event (washington/chapter are news; memory and
      // non-urgent fcle they will encounter in-app anyway).
      final isNews = c.kind == NotifKind.washingtonPersonal ||
          c.kind == NotifKind.washingtonGeneral ||
          c.kind == NotifKind.chapterReady;
      if (context.openedAppToday && !c.urgent && !isNews) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.drop,
            reason: 'user already active today; will see it in-app',
          ),
        );
        continue;
      }

      // Quiet hours or a too-recent last send: defer non-urgent to the
      // learned preferred hour instead of dropping.
      if (!c.urgent && (context.inQuietHours || !gapClear)) {
        decisions.add(
          NotifDecision(
            candidate: c,
            action: NotifAction.deferToPreferredHour,
            reason: context.inQuietHours ? 'quiet hours' : 'min gap not met',
            scheduledFor: context.nextPreferredSlot,
          ),
        );
        remaining--;
        continue;
      }

      decisions.add(
        NotifDecision(
          candidate: c,
          action: NotifAction.fireNow,
          reason: 'cleared all gates',
        ),
      );
      remaining--;
    }

    return decisions;
  }
}
