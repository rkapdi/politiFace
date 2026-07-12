// lib/features/atlas/presentation/vocabulary_screen.dart
//
// Civic vocabulary: cited definitions, alphabetical, expandable. Every
// definition links to its primary public source.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/atlas_reference_loader.dart';

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reference = ref.watch(atlasReferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Civic vocabulary')),
      body: reference.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load the vocabulary.')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Original definitions, each linked to a primary public '
              'source.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final term in data.terms) _TermTile(term: term),
          ],
        ),
      ),
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({required this.term});

  final CivicTerm term;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            term.term,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.definition,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(term.citation),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Source: ${Uri.parse(term.citation).host}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
