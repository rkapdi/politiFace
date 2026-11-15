// lib/features/notifications/data/notification_orchestrator.dart
//
// The orchestration layer that feeds the on-device notification brain. It
// gathers candidates from every generator (Washington, memory rescue, FCLE
// milestones, chapter ready), assembles a BrainContext entirely from local
// state, asks the brain what to do, and executes the decisions through the
// injectable NotificationSender.
//
// Nothing about the decision leaves the phone. The context is built from
// AppMeta counters the orchestrator itself maintains (a small notification
// log, the learned preferred hour, the last-open day) plus the user's own
// learning state (due cards, FCLE answers, reviewed faces).
//
// Entry points:
//   * run()                   — the periodic sweep (BGAppRefresh, silent push,
//                               foreground start). Gathers Washington + memory
//                               + FCLE and dispatches them together. Only one
//                               sweep runs at a time: see "Exactly once" below.
//   * submitChapterCandidate  — the event-driven chapter-ready nudge, routed
//                               through the same brain on round completion.
//   * recordAppOpen()         — call on foreground so "opened today" and the
//                               preferred-hour histogram stay current.
//
// Exactly once. A sweep can be started from three places (app launch, a
// silent push, the background refresh task, which has its own isolate and
// its own database connection), and they used to overlap: each read the
// same empty log and each sent. Two database-level guards now hold, both
// single atomic statements (MetaDao.claimStamp), so they hold across
// isolates too:
//   1. A sweep first claims a lease ('notif.sweep_lock'). A second sweep
//      that finds the lease held does nothing. The lease expires on its
//      own, so a sweep killed mid-run cannot block the next one for long.
//   2. Each notification is recorded as sent BEFORE it is sent, by claiming
//      'notif.sent:<dedupeKey>'. For a sweep that claim is conditional on
//      still holding the lease, in the same statement. Whoever loses the
//      claim does not send.

import 'dart:convert';
import 'dart:math';

import '../../../core/database/drift/app_database.dart';
import '../../fcle/application/objective_readiness.dart';
import '../../fcle/data/objectives_loader.dart';
import '../../fcle/data/question_bank_loader.dart';
import '../../fcle/domain/fcle_question.dart';
import '../../fcle/domain/objective.dart';
import '../../settings/data/settings_service.dart';
import '../domain/alert_log.dart';
import '../domain/notification_brain.dart';
import 'notification_generators.dart';
import 'notification_sender.dart';
import 'washington_watch_service.dart';

// Local AppMeta keys the orchestrator owns.

/// Pre-1.3.3 sent log: one JSON list, rewritten read-modify-write. Read
/// only, so a notification sent just before the update still counts toward
/// the cap and the cooldown; removed once every entry in it has aged out.
const _kLegacyLog = 'notif.log';

/// One row per notification sent: 'notif.sent:<dedupeKey>' -> delivery time
/// in epoch milliseconds. Claimed atomically before the send.
const _kSentPrefix = 'notif.sent:';

/// One row per item a digest covered: 'notif.covered:<itemKey>' -> delivery
/// time. Keeps an item a digest already reported from alerting again on its
/// own, without counting toward the daily cap (the digest was one
/// notification, not many).
const _kCoveredPrefix = 'notif.covered:';

/// The sweep lease: '<expiresAtMillis>|<owner token>'.
const _kSweepLock = 'notif.sweep_lock';

/// How long a sweep may hold the lease before another may take over. A
/// sweep is a handful of network calls, each capped at 12 seconds; this is
/// comfortably longer, and short enough that a sweep killed mid-run only
/// delays the next by minutes.
const _kSweepLease = Duration(minutes: 2);

/// How long a sent or covered key suppresses a repeat. Matches
/// [BrainContext.dedupeCooldown].
const _kCooldown = Duration(days: 3);
const _kLastOpenDay = 'notif.last_open_day';
const _kOpenHours = 'notif.open_hours';
const _kSolidDomains = 'notif.fcle.solid_domains';
const _kHomeState = 'atlas.home_state';

/// How far ahead a card counts as "about to slip" for memory rescue.
const _kRescueHorizon = Duration(hours: 18);

/// Cards due more than this far in the past are deeply lapsed, not "about to
/// slip"; the five-minute-rescue framing does not fit them, so they are
/// excluded from the rescue count.
const _kRescueStaleFloor = Duration(days: 7);

class NotificationOrchestrator {
  NotificationOrchestrator({
    required AppDatabase db,
    WashingtonWatchService? washington,
    NotificationSender? sender,
    SettingsService? settings,
    NotificationBrain brain = const NotificationBrain(),
    DateTime Function()? now,
    Future<List<Objective>> Function()? loadObjectives,
    Future<QuestionBank> Function()? loadQuestionBank,
  })  : _db = db,
        _sender = sender ?? const PluginNotificationSender(),
        _settings = settings ?? SettingsService(db),
        _brain = brain,
        _now = now ?? DateTime.now,
        _loadObjectives = loadObjectives ?? (() => ObjectivesLoader().load()),
        _loadQuestionBank =
            loadQuestionBank ?? (() => QuestionBankLoader().load()) {
    _washington = washington ??
        WashingtonWatchService(
          db: db,
          sender: _sender,
          settings: _settings,
          now: _now,
        );
  }

  final AppDatabase _db;
  final NotificationSender _sender;
  final SettingsService _settings;
  final NotificationBrain _brain;
  final DateTime Function() _now;
  final Future<List<Objective>> Function() _loadObjectives;
  final Future<QuestionBank> Function() _loadQuestionBank;
  late final WashingtonWatchService _washington;

  /// The periodic sweep. Gathers every pollable candidate, runs them through
  /// the brain together (so relevance ranking is honest across categories),
  /// and executes the decisions. Fail-soft throughout: a hiccup in any one
  /// generator never blocks the others or crashes a background isolate.
  Future<void> run() async {
    String? lease;
    try {
      final now = _now();
      lease = await _claimSweep(now);
      // Another sweep is running (this isolate or the background one). It
      // sees the same feeds and the same log, so there is nothing for this
      // one to add.
      if (lease == null) return;
      await _pruneSent(now);

      final candidates = <NotifCandidate>[];
      candidates.addAll(await _washingtonCandidates(now));
      final memory = await _memoryRescueCandidate(now);
      if (memory != null) candidates.add(memory);
      candidates.addAll(await _fcleCandidates(now));
      if (candidates.isEmpty) return;
      final delivered = await _dispatch(candidates, now, lease: lease);
      // Advance Washington baselines only for items that actually delivered,
      // so a capped or unauthorized item is retried next cycle rather than
      // lost forever. A digest delivers every item it covers: its own key
      // ('wash:summary:<day>') names no item, so the covered keys are what
      // must be committed, or the same backlog comes back tomorrow as a
      // bigger digest.
      final washingtonDelivered = <String>{
        for (final c in delivered)
          if (_isWashington(c))
            ...(c.items.isEmpty ? [c.dedupeKey] : c.itemKeys),
      }.where(_isItemKey).toList();
      if (washingtonDelivered.isNotEmpty) {
        await _washington.commitDelivered(washingtonDelivered);
      }
    } catch (_) {
      // Best-effort: never surface as a crash on a BGAppRefresh task.
    } finally {
      if (lease != null) {
        try {
          await _db.metaDao.removeIfValue(_kSweepLock, lease);
        } catch (_) {
          // The lease expires on its own.
        }
      }
    }
  }

  /// Claims the sweep lease. Returns the lease value to hold and release,
  /// or null when another sweep holds a live one.
  Future<String?> _claimSweep(DateTime now) async {
    final nowMs = now.millisecondsSinceEpoch;
    final value = '${nowMs + _kSweepLease.inMilliseconds}|${_ownerToken()}';
    final won = await _db.metaDao.claimStamp(
      _kSweepLock,
      value: value,
      // A lease whose expiry is in the past is free to take.
      staleBelow: nowMs,
    );
    return won ? value : null;
  }

  static final _random = Random();
  static String _ownerToken() => '${_random.nextInt(1 << 32).toRadixString(16)}'
      '${_random.nextInt(1 << 32).toRadixString(16)}';

  static bool _isWashington(NotifCandidate c) =>
      c.kind == NotifKind.washingtonPersonal ||
      c.kind == NotifKind.washingtonGeneral;

  static bool _isItemKey(String k) =>
      k.startsWith('eo:') || k.startsWith('law:') || k.startsWith('bill:');

  /// Routes an already-decided chapter-ready teaser through the brain instead
  /// of scheduling it directly, so it respects the daily cap, quiet hours, and
  /// repeat suppression like everything else.
  Future<void> submitChapterCandidate({
    required String title,
    required String body,
    required String nextChapterTitle,
  }) async {
    try {
      final candidate = buildChapterReadyCandidate(
        title: title,
        body: body,
        nextChapterTitle: nextChapterTitle,
      );
      await _dispatch([candidate], _now());
    } catch (_) {
      // Never block round completion over a notification side effect.
    }
  }

  /// Marks the app opened today and updates the learned preferred-hour
  /// histogram. Call from a foreground start.
  Future<void> recordAppOpen() async {
    final now = _now();
    await _db.metaDao.set(_kLastOpenDay, _dayKey(now));
    final hours = _readIntMap(await _db.metaDao.get(_kOpenHours));
    final h = now.hour.toString();
    hours[h] = (hours[h] ?? 0) + 1;
    await _db.metaDao.set(_kOpenHours, jsonEncode(hours));
  }

  // ── Candidate gathering ────────────────────────────────────────────────

  Future<List<NotifCandidate>> _washingtonCandidates(DateTime now) async {
    // Pref pre-filter lives inside detectNewItems (master + sub-toggles), so a
    // muted category never even produces items to consider.
    final detected = await _washington.detectNewItems();
    if (detected.isEmpty) return const [];
    // Belt and braces behind the baselines: never report an item again
    // that a notification (its own, or a digest) already covered within
    // the cooldown.
    final reported = await _recentKeys(now);
    final items = [
      for (final i in detected)
        if (!reported.contains(i.dedupeKey)) i,
    ];
    if (items.isEmpty) return const [];

    // Build the studied/home-state lookup once. Face cards only: a bill or EO
    // ties to a person, never a concept card.
    final faceCards = await _db.cardsDao.allActiveFaceCards();
    final reviewedIds = await _db.reviewsDao
        .reviewedCardIdsAmong([for (final c in faceCards) c.id]);
    final byName = <String, LocalCard>{
      for (final c in faceCards) c.politicianName.toLowerCase().trim(): c,
    };
    final homeState = await _db.metaDao.get(_kHomeState);

    final inputs = <WashingtonInput>[];
    for (final item in items) {
      inputs.add(
        WashingtonInput(
          item: item,
          link: await _resolvePerson(item, byName, reviewedIds, homeState),
        ),
      );
    }
    return buildWashingtonCandidates(inputs, now: now);
  }

  /// Resolves the real person behind a Washington item to a personalization
  /// link, or null when there is no honest personal connection. The name in
  /// the returned link is always the person's own card name, so downstream
  /// copy can never contain a fabricated name.
  Future<WashingtonPersonLink?> _resolvePerson(
    WatchItem item,
    Map<String, LocalCard> byName,
    Set<String> reviewedIds,
    String? homeState,
  ) async {
    final name = item.personName?.toLowerCase().trim();
    if (name == null || name.isEmpty) return null;
    final card = byName[name];
    if (card == null) return null; // name is not a face the user has locally

    final studied = reviewedIds.contains(card.id);
    // externalId maps to the person's bioguide id; the people row carries the
    // state that powers home-state delegation matching.
    final person = await _db.peopleDao.byId(card.externalId);
    final state = person?.state;
    final homeMatch = homeState != null && state != null && state == homeState;
    if (!studied && !homeMatch) return null;
    return WashingtonPersonLink(
      name: card.politicianName,
      studied: studied,
      homeState: homeMatch,
      state: state ?? homeState,
    );
  }

  Future<NotifCandidate?> _memoryRescueCandidate(DateTime now) async {
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final horizon = nowSec + _kRescueHorizon.inSeconds;
    final staleFloor = nowSec - _kRescueStaleFloor.inSeconds;
    final due = await _db.reviewsDao.dueAt(horizon);
    final slipping = due.where((s) => s.nextReviewAt >= staleFloor).toList();
    if (slipping.length < 3) return null;

    // A real card name for the copy; never invented. Face cards use the
    // politician name, concept cards their title.
    final card = await _db.cardsDao.cardById(slipping.first.cardId);
    final sampleName = card == null
        ? null
        : (card.cardType == 'face' ? card.politicianName : card.title);
    return buildMemoryRescueCandidate(
      slippingCount: slipping.length,
      sampleCardName: sampleName,
      now: now,
    );
  }

  Future<List<NotifCandidate>> _fcleCandidates(DateTime now) async {
    // Cheap local gate: only FCLE-engaged users hear this category at all.
    if (!await _db.fcleAnswersDao.hasAny()) return const [];
    try {
      final objectives = await _loadObjectives();
      if (objectives.isEmpty) return const [];
      final bank = await _loadQuestionBank();
      final objectiveOf = <String, String>{
        for (final q in bank.all)
          if (q.objective != null) q.id: q.objective!,
      };
      final log = await _db.fcleAnswersDao.answerLog();
      final byCode = computeObjectiveReadiness(
        objectives: objectives,
        objectiveOfQuestion: objectiveOf,
        answerLog: log,
      );
      final covered = byCode.values.where((o) => o.count > 0).length;
      final solidDomains = <FcleDomain>{
        for (final o in byCode.values)
          if (o.state == ReadinessState.solid) o.domain,
      };
      final prior = _readStringSet(await _db.metaDao.get(_kSolidDomains));
      final result = buildFcleMilestoneCandidates(
        covered: covered,
        total: byCode.length,
        solidDomains: solidDomains,
        priorSolidDomainCodes: prior,
        now: now,
      );
      await _db.metaDao
          .set(_kSolidDomains, jsonEncode(result.solidDomainCodes.toList()));
      return result.candidates;
    } catch (_) {
      // Assets may be unavailable in a lean background isolate; FCLE nudges
      // are a nicety, so skip them rather than fail the whole sweep.
      return const [];
    }
  }

  // ── Brain wiring ───────────────────────────────────────────────────────

  /// Decides and sends. Returns the candidates that were delivered (shown
  /// or scheduled). [lease] is the sweep lease when called from [run]; the
  /// event-driven chapter nudge passes none.
  Future<List<NotifCandidate>> _dispatch(
    List<NotifCandidate> candidates,
    DateTime now, {
    String? lease,
  }) async {
    final context = await _buildContext(now);
    final decisions = _brain.decide(candidates, context);
    final acting = decisions.where(
      (d) =>
          d.action == NotifAction.fireNow ||
          d.action == NotifAction.deferToPreferredHour,
    );
    if (acting.isEmpty) return const [];

    // One authorization check for the whole batch. If the user revoked
    // notifications, send nothing and record nothing so a re-grant re-tries.
    if (!await _sender.isAuthorized()) return const [];

    final cooldownCutoff = now.subtract(_kCooldown).millisecondsSinceEpoch;
    final delivered = <NotifCandidate>[];
    for (final d in acting) {
      final c = d.candidate;
      // A deferred item is billed to its DELIVERY day, not the dispatch
      // day, so a defer that crosses midnight counts against the right
      // day's cap.
      final deliveredAt =
          d.action == NotifAction.fireNow ? now : d.scheduledFor!;
      // Record it as sent FIRST, atomically. Exactly one caller can win
      // this claim for a given key, and a sweep can only win it while it
      // still holds the lease, so two overlapping runs can never both
      // send the same notification. Losing the claim means someone else
      // has sent it (or is about to): skip.
      final sentKey = '$_kSentPrefix${c.dedupeKey}';
      final stamp = deliveredAt.millisecondsSinceEpoch.toString();
      final claimed = await _db.metaDao.claimStamp(
        sentKey,
        value: stamp,
        staleBelow: cooldownCutoff,
        requireKey: lease == null ? null : _kSweepLock,
        requireValue: lease,
      );
      if (!claimed) continue;
      try {
        if (d.action == NotifAction.fireNow) {
          await _sender.show(
            id: c.notificationId,
            title: c.title,
            body: c.body,
            payload: c.route,
          );
        } else {
          await _sender.scheduleAt(
            id: c.notificationId,
            title: c.title,
            body: c.body,
            when: d.scheduledFor!,
            payload: c.route,
          );
        }
      } catch (_) {
        // The send failed, so the user saw nothing: give the claim back
        // and let a later sweep try again. Items already sent in this
        // batch stay recorded.
        await _db.metaDao.removeIfValue(sentKey, stamp);
        rethrow;
      }
      delivered.add(c);
      if (_isWashington(c)) {
        // Everything a digest covered is now reported: remember each item
        // so it cannot come back as its own alert or inside a later
        // digest.
        for (final key in c.itemKeys) {
          if (key != c.dedupeKey) {
            await _db.metaDao.set('$_kCoveredPrefix$key', stamp);
          }
        }
        // Washington alerts additionally land in the alert log that The
        // Pulse pins at the top: a notification's content must be findable
        // in the app afterwards, however much the live feed window has
        // churned in the meantime.
        await _appendAlertLog(c, deliveredAt);
      }
    }
    return delivered;
  }

  Future<BrainContext> _buildContext(DateTime now) async {
    final sent = await _sentEntries(now);
    final cooldownMs = now.subtract(_kCooldown).millisecondsSinceEpoch;

    var firedTodayCount = 0;
    DateTime? lastFiredAt;
    final recent = <String>{};
    for (final e in sent) {
      final at = DateTime.fromMillisecondsSinceEpoch(e.atMillis);
      if (_dayKey(at) == _dayKey(now)) firedTodayCount++;
      if (lastFiredAt == null || at.isAfter(lastFiredAt)) lastFiredAt = at;
      if (e.atMillis >= cooldownMs) recent.add(e.key);
    }
    // Items a digest covered suppress their own repeat, but are not
    // notifications themselves: they never count toward the cap or the gap.
    recent.addAll(await _coveredKeys(now));

    final openedToday = (await _db.metaDao.get(_kLastOpenDay)) == _dayKey(now);
    final fcleEngaged = await _db.fcleAnswersDao.hasAny();
    final preferredHour = _preferredHour(
      _readIntMap(await _db.metaDao.get(_kOpenHours)),
    );

    return BrainContext(
      now: now,
      firedTodayCount: firedTodayCount,
      lastFiredAt: lastFiredAt,
      recentDedupeKeys: recent,
      openedAppToday: openedToday,
      fcleEngaged: fcleEngaged,
      preferredHour: preferredHour,
    );
  }

  // ── Sent record (AppMeta 'notif.sent:*', 'notif.covered:*') ─────────────

  /// Every notification sent within the cooldown: the per-key rows, plus
  /// whatever the pre-1.3.3 JSON log still holds.
  Future<List<_LogEntry>> _sentEntries(DateTime now) async {
    final cutoff = now.subtract(_kCooldown).millisecondsSinceEpoch;
    final byKey = <String, int>{};
    for (final e in _parseLog(await _db.metaDao.get(_kLegacyLog))) {
      if (e.atMillis >= cutoff) byKey[e.key] = e.atMillis;
    }
    final rows = await _db.metaDao.withPrefix(_kSentPrefix);
    for (final row in rows.entries) {
      final at = int.tryParse(row.value);
      if (at == null || at < cutoff) continue;
      byKey[row.key.substring(_kSentPrefix.length)] = at;
    }
    return [
      for (final e in byKey.entries) _LogEntry(key: e.key, atMillis: e.value),
    ];
  }

  Future<Set<String>> _coveredKeys(DateTime now) async {
    final cutoff = now.subtract(_kCooldown).millisecondsSinceEpoch;
    final rows = await _db.metaDao.withPrefix(_kCoveredPrefix);
    return {
      for (final row in rows.entries)
        if ((int.tryParse(row.value) ?? 0) >= cutoff)
          row.key.substring(_kCoveredPrefix.length),
    };
  }

  /// Every key reported within the cooldown, sent or covered.
  Future<Set<String>> _recentKeys(DateTime now) async => {
        for (final e in await _sentEntries(now)) e.key,
        ...await _coveredKeys(now),
      };

  /// Drops sent and covered rows past the cooldown, and the legacy log once
  /// nothing in it is still live. Runs under the sweep lease.
  Future<void> _pruneSent(DateTime now) async {
    final cutoff = now.subtract(_kCooldown).millisecondsSinceEpoch;
    for (final prefix in [_kSentPrefix, _kCoveredPrefix]) {
      final rows = await _db.metaDao.withPrefix(prefix);
      for (final row in rows.entries) {
        if ((int.tryParse(row.value) ?? 0) < cutoff) {
          await _db.metaDao.removeIfValue(row.key, row.value);
        }
      }
    }
    final legacy = await _db.metaDao.get(_kLegacyLog);
    if (legacy != null && _parseLog(legacy).every((e) => e.atMillis < cutoff)) {
      await _db.metaDao.remove(_kLegacyLog);
    }
  }

  /// Rolling log (newest first, capped) of Washington notifications this
  /// device actually delivered, each with the full detail of every item it
  /// covered (see alert_log.dart). The Pulse renders it from that record
  /// alone, and the notification's tap route names the entry by [id], so a
  /// digest opens to exactly what it summarized.
  Future<void> _appendAlertLog(
    NotifCandidate c,
    DateTime at,
  ) async {
    final log = [
      // Newest first. A key delivered again after its cooldown replaces
      // its old entry rather than sitting beside it.
      AlertLogEntry(
        id: c.dedupeKey,
        title: c.title,
        body: c.body,
        at: at,
        items: c.items.take(kAlertLogMaxItems).toList(),
      ),
      for (final e in parseAlertLog(await _db.metaDao.get(kAlertLogKey)))
        if (e.id != c.dedupeKey) e,
    ];
    await _db.metaDao.set(
      kAlertLogKey,
      encodeAlertLog(log.take(kAlertLogMaxEntries).toList()),
    );
  }

  static List<_LogEntry> _parseLog(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (e is Map && e['k'] is String && e['t'] is int)
            _LogEntry(key: e['k'] as String, atMillis: e['t'] as int),
      ];
    } catch (_) {
      return [];
    }
  }

  // ── Preferred-hour histogram (AppMeta 'notif.open_hours') ──────────────

  /// The mode of the open-hour histogram, or 18 (6pm) when nothing is learned
  /// yet. Ties resolve to the earlier hour for determinism.
  static int _preferredHour(Map<String, int> hours) {
    if (hours.isEmpty) return 18;
    var best = 18;
    var bestCount = -1;
    for (var h = 0; h < 24; h++) {
      final n = hours[h.toString()] ?? 0;
      if (n > bestCount) {
        bestCount = n;
        best = h;
      }
    }
    return bestCount <= 0 ? 18 : best;
  }

  static Map<String, int> _readIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is int) e.key.toString(): e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Set<String> _readStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return {
        for (final e in list)
          if (e is String) e,
      };
    } catch (_) {
      return {};
    }
  }

  static String _dayKey(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }
}

class _LogEntry {
  const _LogEntry({required this.key, required this.atMillis});
  final String key;
  final int atMillis;
}
