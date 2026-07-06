// lib/features/pulse/presentation/pulse_screen.dart
//
// The Pulse: one scrollable feed of what the federal government actually
// did. Executive orders, laws enacted, and the latest bill actions,
// merged chronologically, newest first. Instead of notification spam the
// feed is there when the user opens it, fully offline from bundled
// content; freshness comes from the weekly content refresh (and, later,
// live checks once a keyless proxy exists).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../atlas/data/atlas_reference_loader.dart';
import '../data/pulse_live_service.dart';

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
  });

  final _PulseKind kind;
  final String date; // ISO
  final String title;
  final String detail;
  final String url;
  final String? sponsorBioguide;
  final String? sponsorName;
}

final _liveProvider = FutureProvider.autoDispose<LivePulse>(
  (ref) => PulseLiveService().fetch(),
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
      ),
  };
  for (final b in live.bills) {
    billsById[b.bill] = _PulseItem(
      kind: _PulseKind.bill,
      date: b.actionDate,
      title: b.title.isEmpty ? b.bill : b.title,
      detail: '${b.bill}: ${b.action}',
      url: b.url,
    );
  }

  final items = <_PulseItem>[
    ...ordersByNumber.values,
    for (final l in reference.laws)
      _PulseItem(
        kind: _PulseKind.law,
        date: l.enactedDate,
        title: l.title,
        detail: 'Became Public Law ${l.lawNumber} (started as ${l.bill})',
        url: l.url,
        sponsorBioguide: l.sponsorBioguide,
        sponsorName: l.sponsorName,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Pulse'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
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
        onTap: () => launchUrl(
          Uri.parse(item.url),
          mode: LaunchMode.externalApplication,
        ),
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
