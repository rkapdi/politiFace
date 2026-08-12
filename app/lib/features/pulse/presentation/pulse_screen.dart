// lib/features/pulse/presentation/pulse_screen.dart
//
// The Pulse: one scrollable feed of what the federal government actually
// did. Executive orders, laws enacted, and the latest bill actions,
// merged chronologically, newest first, with the notifications this
// device delivered pinned on top so an alert is always findable here.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../atlas/data/atlas_reference_loader.dart';
import '../data/pulse_live_service.dart';
import 'bill_detail_screen.dart';

enum _PulseKind { order, law, bill }

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

  /// Bill and law rows with anything to show open the detail screen.
  bool get opensDetail =>
      kind == _PulseKind.bill ||
      (kind == _PulseKind.law && (summary != null || congress != null));
}

final _liveProvider = FutureProvider.autoDispose<LivePulse>(
  (ref) => PulseLiveService().fetch(),
);

class _Alert {
  const _Alert({
    required this.title,
    required this.body,
    required this.at,
    this.itemKey,
  });
  final String title;
  final String body;
  final DateTime at;

  /// Dedupe key of the feed item this notification was about
  /// ('eo:14418', 'bill:HR 8121:2026-08-06', 'law:...'). Null for digest
  /// summaries and for entries logged before the key was recorded.
  final String? itemKey;
}

/// Washington notifications this device delivered in the last 7 days,
/// newest first. Pinned so "the notification said X" is always findable
/// here regardless of live-feed churn.
final _alertLogProvider = FutureProvider.autoDispose<List<_Alert>>(
  (ref) async {
    final raw =
        await ref.watch(databaseProvider).metaDao.get('watch.alert_log');
    if (raw == null) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map && e['at'] is int)
            if (DateTime.fromMillisecondsSinceEpoch(e['at'] as int)
                .isAfter(cutoff))
              _Alert(
                title: (e['t'] as String?) ?? '',
                body: (e['b'] as String?) ?? '',
                at: DateTime.fromMillisecondsSinceEpoch(e['at'] as int),
                itemKey: e['k'] as String?,
              ),
      ];
    } catch (_) {
      return const [];
    }
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
  final live = await ref.watch(_liveProvider.future);

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
            originDetail: lawNumber == null
                ? b.action
                : 'Became Public Law $lawNumber',
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

  final items = <_PulseItem>[
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
  const PulseScreen({super.key});

  @override
  ConsumerState<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends ConsumerState<PulseScreen> {
  _PulseKind? _filter;

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
                    ref.invalidate(_liveProvider);
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

  /// A keyed alert deep-links to its feed item; everything else (digest
  /// summaries, pre-upgrade entries, items that have churned out of the
  /// feed) opens a readable detail sheet.
  void _openAlert(_Alert alert, List<_PulseItem> items) {
    HapticFeedback.lightImpact();
    final item = _matchAlert(alert, items);
    if (item != null) {
      _openPulseItem(context, item);
      return;
    }
    _showAlertDetail(alert);
  }

  _PulseItem? _matchAlert(_Alert alert, List<_PulseItem> items) {
    final key = alert.itemKey;
    if (key == null) return null;
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
      for (final i in items) {
        if (i.bill == parts[1]) return i;
      }
    }
    return null;
  }

  void _showAlertDetail(_Alert alert) {
    final theme = Theme.of(context);
    final at = alert.at;
    String two(int n) => n.toString().padLeft(2, '0');
    final delivered = '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DELIVERED $delivered', style: theme.textTheme.labelSmall),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() => _filter = null);
                  },
                  child: const Text(
                    "SEE WHAT'S NEW IN THE PULSE",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
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

/// Shared open behavior for a feed item: bill/law rows push the detail
/// screen, executive orders open the Federal Register record.
void _openPulseItem(BuildContext context, _PulseItem item) {
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
  final List<_Alert> alerts;
  final ThemeData theme;
  final void Function(_Alert) onAlertTap;

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

  @override
  Widget build(BuildContext context) {
    final (header, explainer) = switch (filter) {
      _PulseKind.order => ('WHAT IS AN EXECUTIVE ORDER?', _orderExplainer),
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

  Widget _alertRow(_Alert alert) => InkWell(
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
                        text: '${alert.title}: ',
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
