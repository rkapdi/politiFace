// lib/features/atlas/presentation/recent_laws_screen.dart
//
// Public laws of the current Congress: what actually became law, newest
// first, each linking to congress.gov and cross-linking to the sponsor's
// Atlas person page. Fully offline from the bundled YAML.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/atlas_reference_loader.dart';

class RecentLawsScreen extends ConsumerStatefulWidget {
  const RecentLawsScreen({super.key});

  @override
  ConsumerState<RecentLawsScreen> createState() => _RecentLawsScreenState();
}

class _RecentLawsScreenState extends ConsumerState<RecentLawsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reference = ref.watch(atlasReferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recent laws')),
      body: reference.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load recent laws.')),
        data: (data) {
          if (data.laws.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Law data ships with the next content update.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }
          final q = _query.trim().toLowerCase();
          final laws = q.isEmpty
              ? data.laws
              : [
                  for (final l in data.laws)
                    if (l.title.toLowerCase().contains(q) ||
                        l.lawNumber.contains(q) ||
                        l.bill.toLowerCase().contains(q))
                      l,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${laws.length} of ${data.laws.length} public laws of '
                    'the ${data.lawsCongress ?? 'current'}th Congress',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: laws.length,
                  itemBuilder: (context, i) => _LawTile(law: laws[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LawTile extends StatelessWidget {
  const _LawTile({required this.law});

  final RecentLaw law;

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
                'PUBLIC LAW ${law.lawNumber} · ${law.enactedDate}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                law.title,
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PUBLIC LAW ${law.lawNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                law.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Enacted ${law.enactedDate}. Began as ${law.bill}.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (law.sponsorBioguide != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    HapticFeedback.lightImpact();
                    sheetContext.push('/person/${law.sponsorBioguide}');
                  },
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: theme.colorScheme.primary,),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sponsor: ${law.sponsorName ?? law.sponsorBioguide}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(law.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'READ AT CONGRESS.GOV',
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
