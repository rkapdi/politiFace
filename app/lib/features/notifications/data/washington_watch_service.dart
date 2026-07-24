// lib/features/notifications/data/washington_watch_service.dart
//
// "What Washington did": a periodic diff against the exact feeds the Pulse
// tab already shows (Federal Register executive orders + the `pulse` Edge
// Function's congress.gov bills/laws — see PulseLiveService). No new fetch
// path is introduced. Runs from a normal app foreground start (belt and
// braces) and from the iOS BGAppRefresh task registered in AppDelegate.
//
// House style: notifications describe what happened, never what it means.
// Bodies are official titles and CRS summary text, verbatim.
//
// Phase 3: this service no longer fires notifications itself. It DETECTS
// what changed (fetch + diff + baseline advance + CRS enrichment) and hands
// the raw items to the NotificationOrchestrator, which runs them through the
// on-device notification brain alongside memory-rescue and FCLE candidates.
// [detectNewItems] is the detection seam; [check] is a thin delegator kept
// for existing callers.

import 'dart:math' as math;

import '../../../core/database/drift/app_database.dart';
import '../../pulse/data/pulse_live_service.dart';
import '../../settings/data/settings_service.dart';
import 'notification_orchestrator.dart';
import 'notification_sender.dart';

/// Native iOS BGAppRefresh identifier. Must match
/// `BGTaskSchedulerPermittedIdentifiers` in Info.plist and the
/// `WorkmanagerPlugin.registerPeriodicTask` call in AppDelegate.swift.
const washingtonRefreshTaskId = 'app.politiface.washingtonRefresh';

/// Seam over [PulseLiveService] so tests can fake network results without
/// touching HttpClient. [LivePulseFetcher] just forwards to the exact
/// fetch paths the Pulse tab already uses.
abstract class PulseFetcher {
  Future<LivePulse> fetchPulse();

  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  });
}

class LivePulseFetcher implements PulseFetcher {
  LivePulseFetcher([PulseLiveService? service])
      : _service = service ?? PulseLiveService();
  final PulseLiveService _service;

  @override
  Future<LivePulse> fetchPulse() => _service.fetch();

  @override
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async {
    try {
      return await _service.fetchBillSummary(
        congress: congress,
        type: type,
        number: number,
      );
    } catch (_) {
      return null; // offline or upstream hiccup: title-only body still works
    }
  }
}

enum WatchCategory { executiveOrder, law, bill }

/// One new item surfaced by [WashingtonWatchService.detectNewItems], ready to
/// become a notification candidate (or fold into the collapsed summary).
class WatchItem {
  const WatchItem({
    required this.category,
    required this.title,
    required this.dedupeKey,
    this.extra,
    this.personName,
  });

  final WatchCategory category;

  /// Official title, verbatim.
  final String title;

  /// Stable identity of this exact update, for the brain's repeat
  /// suppression: 'eo:<num>', 'law:<bill>', 'bill:<bill>:<actiondate>'.
  final String dedupeKey;

  /// Extra body content (currently: a law's CRS first sentence, verbatim).
  final String? extra;

  /// The real newsmaker tied to this item, when the feed carries one: the
  /// signing president for an executive order. Null when the source gives no
  /// person (congress.gov bill/law actions carry no sponsor field today).
  /// Only ever a name that came straight from the feed; never synthesized.
  final String? personName;

  String get notificationTitle {
    switch (category) {
      case WatchCategory.executiveOrder:
        return 'New executive order';
      case WatchCategory.law:
        return 'New law';
      case WatchCategory.bill:
        return 'Bill advancing';
    }
  }

  String get notificationBody =>
      (extra == null || extra!.isEmpty) ? title : '$title $extra';
}

/// Diffs the live Pulse feeds against AppMeta baselines and fires local
/// notifications for what changed since last time.
class WashingtonWatchService {
  WashingtonWatchService({
    required AppDatabase db,
    PulseFetcher? fetcher,
    NotificationSender? sender,
    SettingsService? settings,
    DateTime Function()? now,
  })  : _db = db,
        _fetcher = fetcher ?? LivePulseFetcher(),
        _sender = sender ?? const PluginNotificationSender(),
        _settings = settings ?? SettingsService(db),
        _now = now ?? DateTime.now;

  final AppDatabase _db;
  final PulseFetcher _fetcher;
  final NotificationSender _sender;
  final SettingsService _settings;
  final DateTime Function() _now;

  static const _kLastEo = 'watch.last_eo_number';
  static const _kLastLaw = 'watch.last_law';
  static const _kLastBillAction = 'watch.last_bill_action_date';
  static const _kLastCheck = 'watch.last_check';
  static const _rateLimit = Duration(hours: 2);

  /// Delegates to the [NotificationOrchestrator] so the Washington slice runs
  /// through the same on-device brain (dedupe, daily cap, quiet hours,
  /// personalization) as every other notification. Kept for existing callers;
  /// the fetch + baseline + CRS logic still lives here, in [detectNewItems].
  Future<void> check() => NotificationOrchestrator(
        db: _db,
        washington: this,
        sender: _sender,
        settings: _settings,
        now: _now,
      ).run();

  /// Fetches, diffs against baselines, and returns the new items since last
  /// time (pref-filtered, CRS-enriched for small batches). Does NOT notify:
  /// the orchestrator turns these into candidates and lets the brain decide.
  ///
  /// Safe to call from anywhere (foreground start, BGAppRefresh): every
  /// network call this depends on fails soft to empty results (see
  /// [PulseLiveService.fetch]), so offline just means "nothing changed."
  /// Internally rate-limited to at most once per 2 hours.
  Future<List<WatchItem>> detectNewItems() async {
    try {
      final now = _now();
      if (!await _passesRateLimit(now)) return const [];
      // Stamp the attempt before the fetch, not after: an offline attempt
      // still counts against the 2-hour budget, so a dead connection can't
      // turn "at most once per 2 hours" into "once per foreground open".
      await _db.metaDao.set(
        _kLastCheck,
        now.millisecondsSinceEpoch.toString(),
      );

      final pulse = await _fetcher.fetchPulse();
      final isFirstRun = await _isFirstRun();

      final orders = [...pulse.orders]
        ..sort((a, b) => a.number.compareTo(b.number));
      final laws = <LiveBillAction>[];
      final bills = <LiveBillAction>[];
      for (final b in pulse.bills) {
        (_isLaw(b) ? laws : bills).add(b);
      }
      laws.sort((a, b) => a.actionDate.compareTo(b.actionDate));
      bills.sort((a, b) => a.actionDate.compareTo(b.actionDate));

      final lastEo = int.tryParse(await _db.metaDao.get(_kLastEo) ?? '');
      final lastLaw = await _db.metaDao.get(_kLastLaw);
      final lastBill = await _db.metaDao.get(_kLastBillAction);

      final newEos = lastEo == null
          ? const <LiveOrder>[]
          : [
              for (final o in orders)
                if (o.number > lastEo) o,
            ];
      final newLaws = lastLaw == null
          ? const <LiveBillAction>[]
          : [
              for (final l in laws)
                if (l.actionDate.compareTo(lastLaw) > 0) l,
            ];
      final newBills = lastBill == null
          ? const <LiveBillAction>[]
          : [
              for (final b in bills)
                if (b.actionDate.compareTo(lastBill) > 0) b,
            ];

      final washingtonOn = await _settings.washingtonNotifEnabled();
      final eosOn = washingtonOn && await _settings.washEosEnabled();
      final billsOn = washingtonOn && await _settings.washBillsEnabled();
      final lawsOn = washingtonOn && await _settings.washLawsEnabled();

      // Baseline policy: advance immediately for the FIRST run (silent
      // baselining) and for DISABLED categories (so flipping a switch back
      // on never dumps a backlog of items that happened while it was off).
      // For ENABLED categories the baseline is NOT advanced here: it is
      // committed by the orchestrator only once an item is actually
      // delivered (see [commitDelivered]), so an item dropped by the daily
      // cap or a revoked permission retries next cycle instead of being
      // silently lost forever.
      if ((isFirstRun || !eosOn) && orders.isNotEmpty) {
        final maxEo = orders.map((o) => o.number).reduce(math.max);
        await _db.metaDao.set(_kLastEo, maxEo.toString());
      }
      if ((isFirstRun || !lawsOn) && laws.isNotEmpty) {
        await _db.metaDao.set(_kLastLaw, laws.last.actionDate);
      }
      if ((isFirstRun || !billsOn) && bills.isNotEmpty) {
        await _db.metaDao.set(_kLastBillAction, bills.last.actionDate);
      }

      if (isFirstRun) return const []; // baselines written; nothing new yet

      final notifiable = <WatchItem>[
        if (eosOn)
          for (final o in newEos)
            WatchItem(
              category: WatchCategory.executiveOrder,
              title: o.title,
              dedupeKey: 'eo:${o.number}',
              // The signing president is a real face; the orchestrator checks
              // whether the user has actually studied their card.
              personName: o.president.isEmpty ? null : o.president,
            ),
        if (billsOn)
          for (final b in newBills)
            WatchItem(
              category: WatchCategory.bill,
              title: b.title,
              dedupeKey: 'bill:${b.bill}:${b.actionDate}',
            ),
        if (lawsOn)
          for (final l in newLaws)
            WatchItem(
              category: WatchCategory.law,
              title: l.title,
              dedupeKey: 'law:${l.bill}',
            ),
      ];

      if (notifiable.isEmpty) return const [];

      // More than 3 collapse into a single summary candidate downstream, so
      // the per-law CRS round trip is only worth it for a small batch that
      // will actually surface individually.
      if (notifiable.length > 3) return notifiable;

      final enriched = <WatchItem>[];
      for (final item in notifiable) {
        if (item.category != WatchCategory.law) {
          enriched.add(item);
          continue;
        }
        final law = newLaws.firstWhere((l) => l.title == item.title);
        enriched.add(
          WatchItem(
            category: item.category,
            title: item.title,
            dedupeKey: item.dedupeKey,
            personName: item.personName,
            extra: await _firstSentenceOf(law),
          ),
        );
      }
      return enriched;
    } catch (_) {
      // Best-effort refresh: never let a formatting/network hiccup surface
      // as a crash on a foreground app start or BGAppRefresh task.
      return const [];
    }
  }

  /// Advance the baselines for items the orchestrator actually delivered
  /// (or scheduled). Keys look like 'eo:14413', 'law:2026-07-20',
  /// 'bill:2026-07-20'. Undelivered items are simply not passed here, so
  /// they remain "new" and get another delivery attempt next cycle.
  Future<void> commitDelivered(List<String> deliveredKeys) async {
    var maxEo = -1;
    String? maxLaw;
    String? maxBill;
    for (final k in deliveredKeys) {
      final i = k.indexOf(':');
      if (i < 0) continue;
      final kind = k.substring(0, i);
      final val = k.substring(i + 1);
      switch (kind) {
        case 'eo':
          final n = int.tryParse(val);
          if (n != null && n > maxEo) maxEo = n;
        case 'law':
          if (maxLaw == null || val.compareTo(maxLaw) > 0) maxLaw = val;
        case 'bill':
          if (maxBill == null || val.compareTo(maxBill) > 0) maxBill = val;
      }
    }
    if (maxEo >= 0) {
      final cur = int.tryParse(await _db.metaDao.get(_kLastEo) ?? '') ?? -1;
      if (maxEo > cur) await _db.metaDao.set(_kLastEo, maxEo.toString());
    }
    if (maxLaw != null) {
      final cur = await _db.metaDao.get(_kLastLaw);
      if (cur == null || maxLaw.compareTo(cur) > 0) {
        await _db.metaDao.set(_kLastLaw, maxLaw);
      }
    }
    if (maxBill != null) {
      final cur = await _db.metaDao.get(_kLastBillAction);
      if (cur == null || maxBill.compareTo(cur) > 0) {
        await _db.metaDao.set(_kLastBillAction, maxBill);
      }
    }
  }

  Future<bool> _passesRateLimit(DateTime now) async {
    final raw = await _db.metaDao.get(_kLastCheck);
    if (raw == null) return true;
    final last = int.tryParse(raw);
    if (last == null) return true;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(last);
    return now.difference(lastCheck) >= _rateLimit;
  }

  Future<bool> _isFirstRun() async =>
      (await _db.metaDao.get(_kLastEo)) == null &&
      (await _db.metaDao.get(_kLastLaw)) == null &&
      (await _db.metaDao.get(_kLastBillAction)) == null;

  bool _isLaw(LiveBillAction b) =>
      b.action.toLowerCase().contains('became public law');

  Future<String?> _firstSentenceOf(LiveBillAction law) async {
    if (law.congress == null) return null;
    final parts = law.bill.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final summary = await _fetcher.fetchBillSummary(
      congress: law.congress!,
      type: parts.first,
      number: parts.sublist(1).join(),
    );
    if (summary == null || summary.text.trim().isEmpty) return null;
    return _firstSentence(summary.text);
  }

  static String _firstSentence(String text) {
    final trimmed = text.trim();
    final match = RegExp(r'[^.]*\.').firstMatch(trimmed);
    return (match?.group(0) ?? trimmed).trim();
  }
}
