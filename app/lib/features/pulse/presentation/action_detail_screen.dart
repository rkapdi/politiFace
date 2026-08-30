// lib/features/pulse/presentation/action_detail_screen.dart
//
// Detail view for a White House presidential action from the fast lane.
// Reached two ways: an in-app tap on a Pulse feed row (args via extra),
// or a notification tap deep link carrying query parameters
// (/pulse/action?t=...&u=...&k=...&d=...). Cited to whitehouse.gov; the
// provenance line is honest that Federal Register publication follows.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';

class ActionDetailArgs {
  const ActionDetailArgs({
    required this.title,
    required this.url,
    required this.kind,
    required this.date,
  });

  factory ActionDetailArgs.fromQuery(Map<String, String> q) =>
      ActionDetailArgs(
        title: q['t'] ?? '',
        url: q['u'] ?? '',
        kind: q['k'] ?? 'presidential_action',
        date: q['d'] ?? '',
      );

  final String title;
  final String url;
  final String kind; // executive_order | proclamation | memorandum | ...
  final String date; // ISO date or timestamp

  String get kindLabel => switch (kind) {
        'executive_order' => 'EXECUTIVE ORDER',
        'proclamation' => 'PROCLAMATION',
        'memorandum' => 'PRESIDENTIAL MEMORANDUM',
        _ => 'PRESIDENTIAL ACTION',
      };
}

class ActionDetailScreen extends StatelessWidget {
  const ActionDetailScreen({required this.args, super.key});

  final ActionDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day =
        args.date.length >= 10 ? args.date.substring(0, 10) : args.date;

    return Scaffold(
      appBar: AppBar(title: const Text('Presidential action')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: args.kind == 'executive_order'
                  ? cs.brandRed
                  : cs.brandNavy,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              args.kindLabel,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onPrimary, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          Text(args.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (day.isNotEmpty)
            Text(
              'Announced $day',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Source: The White House. The Federal Register publishes the '
              'official numbered text a few days after signing; this item '
              'updates automatically once that happens.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: args.url.isEmpty
                ? null
                : () => launchUrl(
                      Uri.parse(args.url),
                      mode: LaunchMode.externalApplication,
                    ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Read the full text at whitehouse.gov'),
          ),
        ],
      ),
    );
  }
}
