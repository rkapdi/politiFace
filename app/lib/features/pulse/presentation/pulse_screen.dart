// lib/features/pulse/presentation/pulse_screen.dart
//
// The Pulse: one scrollable feed of what the federal government actually
// did. Executive orders, laws enacted, and the latest bill actions,
// merged chronologically, newest first, with the notifications this
// device delivered pinned on top so an alert is always findable here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../atlas/data/atlas_reference_loader.dart';
import '../../notifications/domain/alert_log.dart';
import '../data/pulse_live_service.dart';
import 'action_detail_screen.dart';
import 'bill_detail_screen.dart';

enum _PulseKind { order, action, law, bill }

class _PulseItem {
  const _PulseItem({
    required this.kind,
    required this.date,
    required this.title,
    required this.detail,
    required this.url,
    this.sponsorBioguide,
    this.sponsorName,
    this.bill,
    this.action,
    this.originDetail,
    this.congress,
    this.summary,
    this.summaryVersion,
    this.summaryDate,
    this.summaryTruncated = false,
    this.whKind,
  });

  final _PulseKind kind;
  final String date; // ISO
  final String title;
  final String detail;
  final String url;
  final String? sponsorBioguide;
  final String? sponsorName;
  final String? bill; // e.g. HR 8121 (bill and law rows)
  final String? action; // congress.gov latest-action text, verbatim
  final String? originDetail; // law rows: "Became Public Law 119-100"
  final int? congress;
  final String? summary; // CRS summary carried from the bundle
  final String? summaryVersion;
  final String? summaryDate;
  final bool summaryTruncated;

  /// White House action rows: executive_order | proclamation | memorandum.
  final String? whKind;

  /// Bill, law, and White House action rows open a detail screen.
  bool get opensDetail =>
      kind == _PulseKind.bill ||
      kind == _PulseKind.action ||
      (kind == _PulseKind.law && (summary != null || congress != null));
}

/// The live layer of the feed. Public so a test can stand in for the
/// network.
final pulseLiveProvider = FutureProvider.autoDispose<LivePulse>(
  (ref) => PulseLiveService().fetch(),
);

/// Washington notifications this device delivered in the last 7 days,
/// newest first. Pinned so "the notification said X" is always findable
/// here regardless of live-feed churn. Each entry carries the full detail
/// of every item it covered (see alert_log.dart).
final _alertLogProvider = FutureProvider.autoDispose<List<AlertLogEntry>>(
  (ref) async {
    final raw = await ref.watch(databaseProvider).metaDao.get(kAlertLogKey);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return [
      for (final e in parseAlertLog(raw))
        if (e.at.isAfter(cutoff)) e,
    ];
  },
);

class _PulseFeed {
  const _PulseFeed({
    required this.items,
    required this.liveOrders,
    required this.liveBills,
  });

  final List<_PulseItem> items;
  final bool liveOrders;
  final bool liveBills;
}

/// Bundled content overlaid with whatever is live right now. Executive
/// orders come straight from the Federal Register (keyless); bill actions
/// go live once the backend proxy exists. De-duped: live wins.
final _pulseFeedProvider = FutureProvider.autoDispose<_PulseFeed>((ref) async {
  final reference = await ref.watch(atlasReferenceProvider.future);
  final live = await ref.watch(pulseLiveProvider.future);

  final ordersByNumber = <int, _PulseItem>{
    for (final o in reference.orders)
      o.number: _PulseItem(
        kind: _PulseKind.order,
        date: o.signingDate,
        title: o.title,
        detail: 'Executive Order ${o.number}, signed by ${o.president}',
        url: o.url,
      ),
  };
  for (final o in live.orders) {
    ordersByNumber[o.number] = _PulseItem(
      kind: _PulseKind.order,
      date: o.signingDate,
      title: o.title,
      detail: 'Executive Order ${o.number}, signed by ${o.president}',
      url: o.url,
    );
  }

  final billsById = <String, _PulseItem>{
    for (final b in reference.bills)
      b.bill: _PulseItem(
        kind: _PulseKind.bill,
        date: b.actionDate,
        title: b.title.isEmpty ? b.bill : b.title,
        detail: '${b.bill}: ${b.action}',
        url: b.url,
        bill: b.bill,
        action: b.action,
        congress: b.congress,
        summary: b.summary,
        summaryVersion: b.summaryVersion,
        summaryDate: b.summaryDate,
        summaryTruncated: b.summaryTruncated,
      ),
  };
  // Bundled laws, keyed for dedupe against the live feed: a bill that
  // already appears in recent_laws.yaml must not render twice.
  final bundledLawBills = <String>{for (final l in reference.laws) l.bill};
  final bundledLawNumbers = <String>{
    for (final l in reference.laws) l.lawNumber,
  };

  final liveLaws = <_PulseItem>[];
  for (final b in live.bills) {
    // Same classifier as the Washington watch notifier: an enacted bill is
    // a LAW here too, or a "New law" notification opens a feed where the
    // law is filed under "Bill actions" and hidden by the "New laws"
    // filter.
    if (isEnactedLaw(b)) {
      final lawNumber = publicLawNumberOf(b);
      final dupe = bundledLawBills.contains(b.bill) ||
          (lawNumber != null && bundledLawNumbers.contains(lawNumber));
      if (!dupe) {
        billsById.remove(b.bill); // never also listed as a bill action
        liveLaws.add(
          _PulseItem(
            kind: _PulseKind.law,
            date: b.actionDate,
            title: b.title.isEmpty ? b.bill : b.title,
            detail: lawNumber == null
                ? '${b.bill}: ${b.action}'
                : 'Became Public Law $lawNumber (started as ${b.bill})',
            url: b.url,
            bill: b.bill,
            action: b.action,
            originDetail:
                lawNumber == null ? b.action : 'Became Public Law $lawNumber',
            congress: b.congress,
          ),
        );
      }
      continue;
    }
    // Live wins on freshness, but a bundled CRS summary carries forward
    // so going online never deletes a summary.
    final prior = billsById[b.bill];
    billsById[b.bill] = _PulseItem(
      kind: _PulseKind.bill,
      date: b.actionDate,
      title: b.title.isEmpty ? b.bill : b.title,
      detail: '${b.bill}: ${b.action}',
      url: b.url,
      bill: b.bill,
      action: b.action,
      congress: b.congress ?? prior?.congress,
      summary: prior?.summary,
      summaryVersion: prior?.summaryVersion,
      summaryDate: prior?.summaryDate,
      summaryTruncated: prior?.summaryTruncated ?? false,
    );
  }

  // White House fast lane: same-day presidential actions. Skip any the
  // Federal Register already covers (that entry is richer: EO number).
  final whItems = <_PulseItem>[
    for (final a in live.actions)
      if (!whActionCoveredByOrder(a, [
        ...live.orders,
        ...reference.orders.map((o) => LiveOrder(
              number: o.number,
              title: o.title,
              president: o.president,
              signingDate: o.signingDate,
              url: o.url,
            ))
      ]))
        _PulseItem(
          kind: _PulseKind.action,
          date: a.publishedAt.length >= 10
              ? a.publishedAt.substring(0, 10)
              : a.publishedAt,
          title: a.title,
          detail: 'Announced by the White House. '
              'Federal Register publication pending.',
          url: a.url,
          whKind: a.kind,
        ),
  ];

  final items = <_PulseItem>[
    ...whItems,
    ...ordersByNumber.values,
    ...liveLaws,
    for (final l in reference.laws)
      _PulseItem(
        kind: _PulseKind.law,
        date: l.enactedDate,
        title: l.title,
        detail: 'Became Public Law ${l.lawNumber} (started as ${l.bill})',
        url: l.url,
        sponsorBioguide: l.sponsorBioguide,
        sponsorName: l.sponsorName,
        bill: l.bill,
        originDetail: 'Became Public Law ${l.lawNumber}',
        congress: reference.lawsCongress,
        summary: l.summary,
        summaryVersion: l.summaryVersion,
        summaryDate: l.summaryDate,
        summaryTruncated: l.summaryTruncated,
      ),
    ...billsById.values,
  ]..sort((a, b) => b.date.compareTo(a.date));

  return _PulseFeed(
    items: items,
    liveOrders: live.orders.isNotEmpty,
    liveBills: live.bills.isNotEmpty,
  );
});

class PulseScreen extends ConsumerStatefulWidget {
  const PulseScreen({this.alertId, super.key});

  /// Set when the screen is opened from a notification tap
  /// ('/pulse?alert=<id>'): the id of the alert-log entry to open straight
  /// away, so a digest lands on the list of what it covered instead of on
  /// the plain feed.
  final String? alertId;

  @override
  ConsumerState<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends ConsumerState<PulseScreen> {
  _PulseKind? _filter;

  @override
  void initState() {
    super.initState();
    _openAlertFromRoute(widget.alertId);
  }

  @override
  void didUpdateWidget(PulseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The Pulse tab stays alive in the shell, so a notification tapped
    // while it is already built arrives as a new alertId, not a new State.
    if (widget.alertId != oldWidget.alertId) {
      _openAlertFromRoute(widget.alertId);
    }
  }

  /// Opens the alert a notification tap named. The log is re-read first:
  /// the entry was written moments ago (possibly by the background
  /// refresh isolate), after this screen last loaded it.
  void _openAlertFromRoute(String? alertId) {
    if (alertId == null || alertId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.invalidate(_alertLogProvider);
      final List<AlertLogEntry> alerts;
      try {
        alerts = await ref.read(_alertLogProvider.future);
      } catch (_) {
        return; // unreadable log: the plain feed is still a fine landing
      }
      if (!mounted) return;
      AlertLogEntry? alert;
      for (final a in alerts) {
        if (a.id == alertId) {
          alert = a;
          break;
        }
      }
      if (alert == null) return;
      // Never wait on the network to show what a notification said: the
      // entry is self-contained. The feed only enriches, if it is loaded.
      final feed = ref.read(_pulseFeedProvider).valueOrNull?.items ?? const [];
      _openAlert(alert, feed, fromNotification: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = ref.watch(_pulseFeedProvider);
    final alerts = ref.watch(_alertLogProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('The Pulse')),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load the feed.')),
        data: (data) {
          final visible = _filter == null
              ? data.items
              : [
                  for (final i in data.items)
                    if (i.kind == _filter) i,
                ];
          return Column(
            children: [
              if (alerts.isNotEmpty || _filter != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: _PulseInfoCard(
                    filter: _filter,
                    alerts: alerts,
                    theme: theme,
                    onAlertTap: (a) => _openAlert(a, data.items),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, kind) in [
                        ('All', null),
                        ('Executive orders', _PulseKind.order),
                        ('White House', _PulseKind.action),
                        ('New laws', _PulseKind.law),
                        ('Bill actions', _PulseKind.bill),
                      ]) ...[
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == kind,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _filter = kind);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Row(
                  children: [
                    Icon(
                      data.liveOrders ? Icons.bolt : Icons.inventory_2_outlined,
                      size: 14,
                      color: data.liveOrders
                          ? theme.colorScheme.brandGreen
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.liveOrders
                            ? 'Executive orders live from the Federal '
                                'Register${data.liveBills ? '; bills live' : '; bills from the latest content update'}.'
                            : 'Offline: showing the latest content update. '
                                'Pull to refresh.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pulseLiveProvider);
                    await ref.read(_pulseFeedProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, i) {
                      if (i == visible.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'From the Federal Register and congress.gov. '
                            'Every item links to the official record.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return _PulseTile(item: visible[i]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens one delivered alert.
  ///
  /// An alert about a single item opens that item; a digest opens a sheet
  /// listing every item it covered. Both are built from what the log entry
  /// stored at send time, never from what the live feed happens to hold
  /// now. Entries from older builds stored only keys and fall back to
  /// matching the feed.
  void _openAlert(
    AlertLogEntry alert,
    List<_PulseItem> feed, {
    bool fromNotification = false,
  }) {
    if (!fromNotification) HapticFeedback.lightImpact();
    if (alert.items.length == 1) {
      final item = alert.items.single;
      // Arriving from a notification, do not throw the reader straight out
      // to the browser for an executive order: show what the alert said,
      // with the order one tap away.
      final leavesApp = item.kind == AlertItem.kindOrder;
      if (!(fromNotification && leavesApp)) {
        _openAlertItem(item, feed);
        return;
      }
    }
    if (alert.items.isEmpty) {
      final key = alert.legacyItemKey;
      final item = key == null ? null : _itemForKey(key, feed);
      if (item != null) {
        _openPulseItem(context, item);
        return;
      }
    }
    _showAlertDetail(alert, feed);
  }

  /// Opens one stored item: bills and laws on the detail screen (with the
  /// exact action the alert was about), executive orders on the official
  /// record.
  void _openAlertItem(AlertItem item, List<_PulseItem> feed) {
    if (item.kind == AlertItem.kindOrder) {
      if (item.url.isEmpty) return;
      launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication);
      return;
    }
    final isLaw = item.kind == AlertItem.kindLaw;
    final action = item.action ?? '';
    // A CRS summary the feed already holds for this bill carries over; the
    // action and date always come from the alert itself.
    _PulseItem? inFeed;
    for (final i in feed) {
      if (i.bill != null && i.bill == item.bill) {
        inFeed = i;
        break;
      }
    }
    String? originDetail;
    if (isLaw) {
      // Same reading of the action text as the feed's own law rows.
      final lawNumber = publicLawNumberOf(
        LiveBillAction(
          bill: item.bill ?? '',
          title: item.title,
          actionDate: item.date,
          action: action,
          url: item.url,
        ),
      );
      originDetail = lawNumber == null
          ? (action.isEmpty ? null : action)
          : 'Became Public Law $lawNumber';
    }
    context.push(
      '/pulse/bill',
      extra: BillDetailArgs(
        bill: item.bill ?? '',
        congress: item.congress ?? inFeed?.congress,
        title: item.title,
        action: isLaw ? '' : action,
        actionDate: item.date,
        url: item.url,
        originDetail: originDetail,
        summary: inFeed?.summary,
        summaryVersion: inFeed?.summaryVersion,
        summaryDate: inFeed?.summaryDate,
        summaryTruncated: inFeed?.summaryTruncated ?? false,
      ),
    );
  }

  /// Legacy entries only: finds the feed item a stored key points at. A
  /// bill key carries the action date, which is preferred so two actions
  /// on one bill do not resolve to the same row when both are in the feed.
  _PulseItem? _itemForKey(String key, List<_PulseItem> items) {
    final parts = key.split(':');
    if (parts.length < 2) return null;
    if (parts[0] == 'eo') {
      final prefix = 'Executive Order ${parts[1]},';
      for (final i in items) {
        if (i.kind == _PulseKind.order && i.detail.startsWith(prefix)) {
          return i;
        }
      }
      return null;
    }
    if (parts[0] == 'law' || parts[0] == 'bill') {
      final date = parts.length >= 3 ? parts.last : null;
      _PulseItem? sameBill;
      for (final i in items) {
        if (i.bill != parts[1]) continue;
        if (date != null && i.date == date) return i;
        sameBill ??= i;
      }
      return sameBill;
    }
    return null;
  }

  /// Legacy entries only: the items a digest covered, exact when the entry
  /// stored keys, approximated by delivery-date window for the oldest.
  (List<_PulseItem>, bool) _legacyCoveredItems(
    AlertLogEntry alert,
    List<_PulseItem> items,
  ) {
    if (alert.legacyItemKeys.isNotEmpty) {
      final covered = <_PulseItem>[];
      for (final k in alert.legacyItemKeys) {
        final m = _itemForKey(k, items);
        if (m != null && !covered.contains(m)) covered.add(m);
      }
      if (covered.isNotEmpty) return (covered, false);
    }
    String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final hi = iso(alert.at);
    final lo = iso(alert.at.subtract(const Duration(days: 3)));
    return (
      [
        for (final i in items)
          if (i.date.compareTo(lo) >= 0 && i.date.compareTo(hi) <= 0) i,
      ].take(12).toList(),
      true,
    );
  }

  void _showAlertDetail(AlertLogEntry alert, List<_PulseItem> items) {
    final theme = Theme.of(context);
    final at = alert.at;
    String two(int n) => n.toString().padLeft(2, '0');
    final delivered = '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
    // Stored items are the record of what the alert covered: every one is
    // listed, in the order it was sent. Only an entry from an older build
    // (keys only) is reconstructed from the feed.
    final stored = alert.items;
    final (legacy, approximate) = stored.isNotEmpty
        ? (const <_PulseItem>[], false)
        : _legacyCoveredItems(alert, items);
    final hasRows = stored.isNotEmpty || legacy.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DELIVERED $delivered',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  alert.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (alert.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    alert.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
                if (hasRows) ...[
                  const SizedBox(height: 14),
                  Text(
                    approximate
                        ? 'FROM THE FEED AROUND THAT DAY'
                        : 'WHAT IT COVERED',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final i in stored)
                          _CoveredItemRow(
                            kind: switch (i.kind) {
                              AlertItem.kindOrder => _PulseKind.order,
                              AlertItem.kindLaw => _PulseKind.law,
                              _ => _PulseKind.bill,
                            },
                            title: i.title.isEmpty ? (i.bill ?? '') : i.title,
                            date: i.date,
                            // What happened, verbatim: tells two actions on
                            // the same bill apart.
                            detail: i.kind == AlertItem.kindOrder
                                ? (i.number == null
                                    ? null
                                    : 'Executive Order ${i.number}')
                                : [
                                    if (i.bill != null) i.bill!,
                                    if ((i.action ?? '').isNotEmpty) i.action!,
                                  ].join(': '),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openAlertItem(i, items);
                            },
                          ),
                        for (final i in legacy)
                          _CoveredItemRow(
                            kind: i.kind,
                            title: i.title,
                            date: i.date,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openPulseItem(context, i);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One compact row in the alert-detail sheet: kind badge word, title,
/// date, and (when given) a line saying what happened. Tap opens the item.
class _CoveredItemRow extends StatelessWidget {
  const _CoveredItemRow({
    required this.kind,
    required this.title,
    required this.date,
    required this.onTap,
    this.detail,
  });

  final _PulseKind kind;
  final String title;
  final String date;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (kind) {
      _PulseKind.order => ('EO', theme.colorScheme.brandRed),
      _PulseKind.action => ('WH', theme.colorScheme.brandRed),
      _PulseKind.law => ('LAW', theme.colorScheme.brandGreen),
      _PulseKind.bill => ('BILL', theme.colorScheme.brandNavy),
    };
    final detail = this.detail;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared open behavior for a feed item: bill/law rows push the detail
/// screen, executive orders open the Federal Register record.
void _openPulseItem(BuildContext context, _PulseItem item) {
  if (item.kind == _PulseKind.action) {
    context.push(
      '/pulse/action',
      extra: ActionDetailArgs(
        title: item.title,
        url: item.url,
        kind: item.whKind ?? 'presidential_action',
        date: item.date,
      ),
    );
    return;
  }
  if (item.opensDetail) {
    context.push(
      '/pulse/bill',
      extra: BillDetailArgs(
        bill: item.bill ?? '',
        congress: item.congress,
        title: item.title,
        action: item.kind == _PulseKind.bill ? (item.action ?? '') : '',
        actionDate: item.date,
        url: item.url,
        originDetail: item.originDetail,
        summary: item.summary,
        summaryVersion: item.summaryVersion,
        summaryDate: item.summaryDate,
        summaryTruncated: item.summaryTruncated,
      ),
    );
    return;
  }
  launchUrl(
    Uri.parse(item.url),
    mode: LaunchMode.externalApplication,
  );
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({required this.item});

  final _PulseItem item;

  (String, Color) _badge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (item.kind) {
      case _PulseKind.order:
        return ('EXECUTIVE ORDER', cs.brandRed);
      case _PulseKind.action:
        return (
          switch (item.whKind) {
            'executive_order' => 'EXECUTIVE ORDER',
            'proclamation' => 'PROCLAMATION',
            'memorandum' => 'MEMORANDUM',
            _ => 'WHITE HOUSE',
          },
          item.whKind == 'executive_order' ? cs.brandRed : cs.brandNavy,
        );
      case _PulseKind.law:
        return ('NEW LAW', cs.brandGreen);
      case _PulseKind.bill:
        return ('BILL ACTION', cs.brandNavy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _badge(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          if (item.opensDetail) HapticFeedback.lightImpact();
          _openPulseItem(context, item);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.date,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.opensDetail) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                item.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              if (item.sponsorBioguide != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/person/${item.sponsorBioguide}');
                    },
                    child: Text(
                      'Sponsor: ${item.sponsorName ?? item.sponsorBioguide}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The context box above the feed. On "All" it holds the notifications
/// this device delivered, verbatim and tappable, so "the alert said X"
/// always has a home here even after the live window churns. With a
/// filter active it becomes a short explainer of that instrument.
class _PulseInfoCard extends StatelessWidget {
  const _PulseInfoCard({
    required this.filter,
    required this.alerts,
    required this.theme,
    required this.onAlertTap,
  });

  final _PulseKind? filter;
  final List<AlertLogEntry> alerts;
  final ThemeData theme;
  final void Function(AlertLogEntry) onAlertTap;

  static const _orderExplainer =
      'An executive order is a written directive from the President that '
      'manages how the federal government operates. Orders draw their '
      'force from Article II of the Constitution and from powers Congress '
      'delegates by statute. They do not need a vote in Congress, but '
      'they cannot override the Constitution or existing law, courts can '
      'strike them down, and a later President can amend or revoke them. '
      'Each order is numbered and published in the Federal Register.';

  static const _lawExplainer =
      'A bill becomes a law after both chambers of Congress pass '
      'identical text and the President signs it, or Congress overrides a '
      'veto with a two thirds vote in each chamber. Each new statute '
      'receives a Public Law number and is published by the Office of the '
      'Federal Register.';

  static const _billExplainer =
      "A bill action is any recorded step in a bill's life on "
      'congress.gov: introduction, committee referral, floor votes, '
      'passage in either chamber, and presidential action. Most bills '
      'never become law; the trail of actions shows where a bill '
      'actually stands.';

  static const _actionExplainer =
      'Presidential actions are executive orders, proclamations, and '
      'memoranda as announced by the White House, often days before the '
      'Federal Register publishes the official numbered text. Items here '
      'update automatically once that publication happens.';

  @override
  Widget build(BuildContext context) {
    final (header, explainer) = switch (filter) {
      _PulseKind.order => ('WHAT IS AN EXECUTIVE ORDER?', _orderExplainer),
      _PulseKind.action => ('WHAT ARE PRESIDENTIAL ACTIONS?', _actionExplainer),
      _PulseKind.law => ('HOW A BILL BECOMES A LAW', _lawExplainer),
      _PulseKind.bill => ('WHAT ARE BILL ACTIONS?', _billExplainer),
      null => ('FROM YOUR NOTIFICATIONS', null),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          if (explainer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                explainer,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in alerts) _alertRow(a),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertRow(AlertLogEntry alert) => InkWell(
        onTap: () => onAlertTap(alert),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: alert.body.isEmpty
                            ? alert.title
                            : '${alert.title}: ',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: alert.body,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
}
