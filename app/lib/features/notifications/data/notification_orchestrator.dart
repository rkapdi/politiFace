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
//                               + FCLE and dispatches them together.
//   * submitChapterCandidate  — the event-driven chapter-ready nudge, routed
//                               through the same brain on round completion.
//   * recordAppOpen()         — call on foreground so "opened today" and the
//                               preferred-hour histogram stay current.

import 'dart:convert';

import '../../../core/database/drift/app_database.dart';
import '../../fcle/application/objective_readiness.dart';
import '../../fcle/data/objectives_loader.dart';
import '../../fcle/data/question_bank_loader.dart';
import '../../fcle/domain/fcle_question.dart';
import '../../fcle/domain/objective.dart';
import '../../settings/data/settings_service.dart';
import '../domain/notification_brain.dart';
import 'notification_generators.dart';
import 'notification_sender.dart';
import 'washington_watch_service.dart';

// Local AppMeta keys the orchestrator owns.
const _kLog = 'notif.log';
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
    try {
      final now = _now();
      final candidates = <NotifCandidate>[];
      candidates.addAll(await _washingtonCandidates(now));
      final memory = await _memoryRescueCandidate(now);
      if (memory != null) candidates.add(memory);
      candidates.addAll(await _fcleCandidates(now));
      if (candidates.isEmpty) return;
      final delivered = await _dispatch(candidates, now);
      // Advance Washington baselines only for items that actually delivered,
      // so a capped or unauthorized item is retried next cycle rather than
      // lost forever.
      final washingtonDelivered = delivered
          .where(
            (k) =>
                k.startsWith('eo:') ||
                k.startsWith('law:') ||
                k.startsWith('bill:'),
          )
          .toList();
      if (washingtonDelivered.isNotEmpty) {
        await _washington.commitDelivered(washingtonDelivered);
      }
    } catch (_) {
      // Best-effort: never surface as a crash on a BGAppRefresh task.
    }
  }

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
    final items = await _washington.detectNewItems();
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

  Future<List<String>> _dispatch(
    List<NotifCandidate> candidates,
    DateTime now,
  ) async {
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

    final delivered = <String>[];
    for (final d in acting) {
      final c = d.candidate;
      // A deferred item is billed to its DELIVERY day, not the dispatch
      // day, so a defer that crosses midnight counts against the right
      // day's cap.
      final deliveredAt =
          d.action == NotifAction.fireNow ? now : d.scheduledFor!;
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
      // Record immediately after each successful send: a later failure in
      // the batch can never erase an item the user has already seen.
      await _appendLog([c.dedupeKey], deliveredAt, now);
      delivered.add(c.dedupeKey);
    }
    return delivered;
  }

  Future<BrainContext> _buildContext(DateTime now) async {
    final log = await _prunedLog(now);
    final cooldownMs =
        now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;

    var firedTodayCount = 0;
    DateTime? lastFiredAt;
    final recent = <String>{};
    for (final e in log) {
      final at = DateTime.fromMillisecondsSinceEpoch(e.atMillis);
      if (_dayKey(at) == _dayKey(now)) firedTodayCount++;
      if (lastFiredAt == null || at.isAfter(lastFiredAt)) lastFiredAt = at;
      if (e.atMillis >= cooldownMs) recent.add(e.key);
    }

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

  // ── Notification log (AppMeta 'notif.log') ─────────────────────────────

  Future<List<_LogEntry>> _prunedLog(DateTime now) async {
    final cutoff = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    final raw = await _db.metaDao.get(_kLog);
    final entries = _parseLog(raw).where((e) => e.atMillis >= cutoff).toList();
    return entries;
  }

  Future<void> _appendLog(
    List<String> keys,
    DateTime entryTime,
    DateTime pruneNow,
  ) async {
    if (keys.isEmpty) return;
    final entries = await _prunedLog(pruneNow);
    final at = entryTime.millisecondsSinceEpoch;
    entries.addAll(keys.map((k) => _LogEntry(key: k, atMillis: at)));
    await _db.metaDao.set(
      _kLog,
      jsonEncode([
        for (final e in entries) {'k': e.key, 't': e.atMillis},
      ]),
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
