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

import 'dart:math' as math;

import '../../../core/database/drift/app_database.dart';
import '../../pulse/data/pulse_live_service.dart';
import '../../settings/data/settings_service.dart';
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

/// One new item surfaced by [WashingtonWatchService.check], ready to become
/// a notification (or fold into the collapsed summary).
class WatchItem {
  const WatchItem({required this.category, required this.title, this.extra});

  final WatchCategory category;

  /// Official title, verbatim.
  final String title;

  /// Extra body content (currently: a law's CRS first sentence, verbatim).
  final String? extra;

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

  /// id 100 is the collapsed "N updates" summary; 101-103 are individual
  /// items. Never more than 3 fire individually: a 4th collapses the whole
  /// batch into the summary instead.
  static const _summaryId = 100;
  static const _itemIdBase = 101;

  /// Fetches, diffs against baselines, and fires notifications. Safe to
  /// call from anywhere (foreground start, BGAppRefresh): every network
  /// call this depends on fails soft to empty results (see
  /// [PulseLiveService.fetch]), so offline just means "nothing changed."
  Future<void> check() async {
    try {
      final now = _now();
      if (!await _passesRateLimit(now)) return;
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

      // Baselines always advance to the newest thing this fetch saw,
      // regardless of whether the category is enabled right now — so
      // flipping a switch back on later never dumps a backlog of "new"
      // items that actually happened while it was off.
      if (orders.isNotEmpty) {
        final maxEo = orders.map((o) => o.number).reduce(math.max);
        await _db.metaDao.set(_kLastEo, maxEo.toString());
      }
      if (laws.isNotEmpty) {
        await _db.metaDao.set(_kLastLaw, laws.last.actionDate);
      }
      if (bills.isNotEmpty) {
        await _db.metaDao.set(_kLastBillAction, bills.last.actionDate);
      }

      if (isFirstRun) return; // baselines written; nothing to notify yet

      final washingtonOn = await _settings.washingtonNotifEnabled();
      final eosOn = washingtonOn && await _settings.washEosEnabled();
      final billsOn = washingtonOn && await _settings.washBillsEnabled();
      final lawsOn = washingtonOn && await _settings.washLawsEnabled();

      final notifiable = <WatchItem>[
        if (eosOn)
          for (final o in newEos)
            WatchItem(category: WatchCategory.executiveOrder, title: o.title),
        if (billsOn)
          for (final b in newBills)
            WatchItem(category: WatchCategory.bill, title: b.title),
        if (lawsOn)
          for (final l in newLaws)
            WatchItem(category: WatchCategory.law, title: l.title),
      ];

      if (notifiable.isEmpty) return;
      if (!await _sender.isAuthorized()) return;

      if (notifiable.length > 3) {
        await _sender.show(
          id: _summaryId,
          title:
              'Washington was busy: ${notifiable.length} updates in The Pulse.',
          body: '',
          payload: '/pulse',
        );
        return;
      }

      // Small batch: fill in each law's CRS first sentence. Only worth the
      // network round trip when we're actually about to show it.
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
            extra: await _firstSentenceOf(law),
          ),
        );
      }

      for (var i = 0; i < enriched.length; i++) {
        final item = enriched[i];
        await _sender.show(
          id: _itemIdBase + i,
          title: item.notificationTitle,
          body: item.notificationBody,
          payload: '/pulse',
        );
      }
    } catch (_) {
      // Best-effort refresh: never let a formatting/network hiccup surface
      // as a crash on a foreground app start or BGAppRefresh task.
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
