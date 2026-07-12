// lib/features/atlas/presentation/executive_orders_screen.dart
//
// Executive orders reference (Purcell ask #2): every EO of the current
// administration from the Federal Register, searchable, each linking to
// the official federalregister.gov document. Read-only civic reference;
// titles are the government's own, presented without commentary.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/atlas_reference_loader.dart';

class ExecutiveOrdersScreen extends ConsumerStatefulWidget {
  const ExecutiveOrdersScreen({super.key});

  @override
  ConsumerState<ExecutiveOrdersScreen> createState() =>
      _ExecutiveOrdersScreenState();
}

class _ExecutiveOrdersScreenState extends ConsumerState<ExecutiveOrdersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = ref.watch(atlasReferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Executive orders')),
      body: reference.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load executive orders.')),
        data: (data) {
          final q = _query.trim().toLowerCase();
          final orders = q.isEmpty
              ? data.orders
              : [
                  for (final o in data.orders)
                    if (o.title.toLowerCase().contains(q) ||
                        'eo ${o.number}'.contains(q) ||
                        '${o.number}'.contains(q))
                      o,
                ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by title or number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${orders.length} of ${data.orders.length} orders'
                        '${data.ordersUpdated == null ? '' : ' · from the Federal Register, updated ${data.ordersUpdated}'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: orders.length,
                  itemBuilder: (context, i) => _OrderTile(order: orders[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final ExecutiveOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showDetail(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EO ${order.number} · ${order.signingDate}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXECUTIVE ORDER ${order.number}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Signed ${order.signingDate} by ${order.president}.'
                '${order.federalRegisterCitation == null ? '' : ' Federal Register: ${order.federalRegisterCitation}.'}',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (order.abstractText != null) ...[
                const SizedBox(height: 10),
                Text(
                  order.abstractText!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(order.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'READ AT FEDERALREGISTER.GOV',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
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
