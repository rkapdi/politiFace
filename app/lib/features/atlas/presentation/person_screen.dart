// lib/features/atlas/presentation/person_screen.dart
//
// The IMDb-style person page: everything renders instantly from the local
// people table. Header, facts, full career timeline, committees with
// leadership badges, and primary-source links. No runtime fetches.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/card_avatar.dart';
import '../application/people_providers.dart';

class PersonScreen extends ConsumerWidget {
  const PersonScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: person.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load profile.')),
        data: (p) => p == null
            ? const Center(child: Text('Profile not found.'))
            : _PersonView(person: p),
      ),
    );
  }
}

class _PersonView extends StatelessWidget {
  const _PersonView({required this.person});

  final Person person;

  List<Map<String, dynamic>> _decodeList(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = _decodeList(person.terms);
    final committees = _decodeList(person.committees);
    final citations = (json.decode(person.citations) as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final firstTermStart =
        terms.isEmpty ? null : terms.first['start']?.toString();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardAvatar(
              name: person.name,
              radius: 40,
              photoUrl: person.portraitAsset,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.currentRole,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  if (person.party != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      person.party!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _FactRow(label: 'Born', value: person.birthday),
        _FactRow(label: 'In Congress since', value: firstTermStart),
        _FactRow(label: 'Current term ends', value: person.termEnd),
        const SizedBox(height: 20),
        if (committees.isNotEmpty) ...[
          _SectionLabel(text: 'COMMITTEES', theme: theme),
          const SizedBox(height: 8),
          for (final c in committees)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant,),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c['title'] == null
                          ? (c['name']?.toString() ?? '')
                          : '${c['name']} (${c['title']})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                        fontWeight:
                            c['title'] == null ? null : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
        ],
        _SectionLabel(text: 'CAREER', theme: theme),
        const SizedBox(height: 8),
        for (final t in terms.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    '${_year(t['start'])} to ${_year(t['end'])}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _termLine(t),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _SectionLabel(text: 'SOURCES', theme: theme),
        const SizedBox(height: 8),
        for (final url in [
          ...citations,
          if (person.officialUrl != null) person.officialUrl!,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      Uri.parse(url).host,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Data: unitedstates/congress-legislators (public domain) and '
          'official congressional photos.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _year(Object? iso) {
    final s = iso?.toString() ?? '';
    return s.length >= 4 ? s.substring(0, 4) : '?';
  }

  static String _termLine(Map<String, dynamic> t) {
    final type = t['type'] == 'sen' ? 'U.S. Senator' : 'U.S. Representative';
    final state = t['state'] ?? '';
    final district = t['district'];
    final seat = t['type'] == 'sen' || district == null || district == 0
        ? '$type from $state'
        : '$type, $state district $district';
    final party = t['party'];
    return party == null ? seat : '$seat ($party)';
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
}
