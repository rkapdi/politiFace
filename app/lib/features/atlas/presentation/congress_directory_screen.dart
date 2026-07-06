// lib/features/atlas/presentation/congress_directory_screen.dart
//
// Every member of Congress, offline. Search + chamber/party filters + a
// persisted home-state picker ("your delegation" is one tap). Rows open
// the full person page.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/card_avatar.dart';
import '../application/people_providers.dart';

class CongressDirectoryScreen extends ConsumerStatefulWidget {
  const CongressDirectoryScreen({super.key});

  @override
  ConsumerState<CongressDirectoryScreen> createState() =>
      _CongressDirectoryScreenState();
}

class _CongressDirectoryScreenState
    extends ConsumerState<CongressDirectoryScreen> {
  @override
  void initState() {
    super.initState();
    // Default the directory to the chosen home state on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final home = await ref.read(homeStateProvider.future);
      if (home != null && mounted) {
        ref.read(directoryFilterProvider.notifier).update(
              (f) => f.copyWith(state: () => home),
            );
      }
    });
  }

  Future<void> _pickState() async {
    final states = await ref.read(availableStatesProvider.future);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          ListTile(
            title: const Text('All states'),
            onTap: () => Navigator.of(context).pop('__all__'),
          ),
          for (final s in states)
            ListTile(
              title: Text(s),
              onTap: () => Navigator.of(context).pop(s),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final state = chosen == '__all__' ? null : chosen;
    ref
        .read(directoryFilterProvider.notifier)
        .update((f) => f.copyWith(state: () => state));
    if (state != null) {
      // Remember it: this is the "your delegation" personalization.
      await ref.read(databaseProvider).metaDao.set(kHomeStateMetaKey, state);
      ref.read(homeStateTickProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(directoryFilterProvider);
    final results = ref.watch(directoryResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Members of Congress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: TextField(
              onChanged: (v) => ref
                  .read(directoryFilterProvider.notifier)
                  .update((f) => f.copyWith(query: v)),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or state',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(filter.state ?? 'All states'),
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    selected: filter.state != null,
                    onSelected: (_) => _pickState(),
                  ),
                  const SizedBox(width: 8),
                  for (final (label, value) in [
                    ('Senate', 'senate'),
                    ('House', 'house'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(label),
                      selected: filter.chamber == value,
                      onSelected: (sel) {
                        HapticFeedback.selectionClick();
                        ref.read(directoryFilterProvider.notifier).update(
                              (f) => f.copyWith(
                                chamber: () => sel ? value : null,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (final party in ['Democrat', 'Republican', 'Independent']) ...[
                    ChoiceChip(
                      label: Text(party),
                      selected: filter.party == party,
                      onSelected: (sel) {
                        HapticFeedback.selectionClick();
                        ref.read(directoryFilterProvider.notifier).update(
                              (f) => f.copyWith(
                                party: () => sel ? party : null,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Could not load the directory.')),
              data: (people) => people.isEmpty
                  ? Center(
                      child: Text(
                        'No members match.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: people.length,
                      itemBuilder: (context, i) =>
                          _MemberRow(person: people[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seat = person.chamber == 'senate'
        ? 'Senator · ${person.state}'
        : 'House · ${person.state}'
            '${person.district == null || person.district == 0 ? '' : '-${person.district}'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/person/${person.id}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              CardAvatar(
                name: person.name,
                radius: 22,
                photoUrl: person.portraitAsset,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$seat · ${person.party ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
