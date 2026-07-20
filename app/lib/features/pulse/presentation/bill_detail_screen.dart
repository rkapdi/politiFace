// lib/features/pulse/presentation/bill_detail_screen.dart
//
// One bill (or enacted law), interpreted by nobody: the CRS summary with
// explicit attribution, the latest congress.gov action verbatim, and the
// link to the official record. Atlas vocabulary terms in the text are
// tappable and open the existing cited definitions. Politiface adds no
// commentary, verdicts, or derived judgments anywhere on this screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../atlas/data/atlas_reference_loader.dart';
import '../data/pulse_live_service.dart';
import 'vocab_rich_text.dart';

/// Typed navigation payload for `/pulse/bill`, passed via GoRouter
/// `state.extra` (the same pattern as `/fcle/result` with `MockResult`).
class BillDetailArgs {
  const BillDetailArgs({
    required this.bill,
    required this.title,
    required this.action,
    required this.actionDate,
    required this.url,
    this.congress,
    this.originDetail,
    this.summary,
    this.summaryVersion,
    this.summaryDate,
    this.summaryTruncated = false,
  });

  final String bill; // e.g. HR 8121
  final int? congress; // enables the live summary fetch when bundled
  final String title;
  final String action; // congress.gov latest-action text, verbatim
  final String actionDate;
  final String url; // the official congress.gov record
  final String? originDetail; // law rows: "Became Public Law 119-100"
  final String? summary;
  final String? summaryVersion;
  final String? summaryDate;
  final bool summaryTruncated;
}

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({required this.args, super.key});

  final BillDetailArgs args;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  static const _noSummaryCopy =
      'No CRS summary is available for this bill yet. The Congressional '
      'Research Service writes summaries after a bill is introduced, and '
      'they can take time to appear.';
  static const _truncatedCopy =
      'Shortened to fit offline. The full summary is on congress.gov.';

  Future<LiveBillSummary?>? _liveSummary;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args.summary == null && args.congress != null) {
      final parts = args.bill.split(' ');
      if (parts.length == 2) {
        _liveSummary = PulseLiveService()
            .fetchBillSummary(
              congress: args.congress!,
              type: parts[0],
              number: parts[1],
            )
            .catchError((Object _) => null);
      }
    }
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: theme.colorScheme.brandNavy,
      ),
    );
  }

  Widget _attribution(BuildContext context, String? version, String? date) {
    final theme = Theme.of(context);
    var copy = 'Summary by the Congressional Research Service, the '
        'nonpartisan research arm of the Library of Congress.';
    if (version != null && version.isNotEmpty) {
      copy += ' Version: $version, $date.';
    }
    return Text(
      copy,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _summaryBody(
    BuildContext context,
    List<CivicTerm> terms,
    String text,
    bool truncated,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VocabRichText(text: text, terms: terms),
        if (truncated)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _truncatedCopy,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _noSummary(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _noSummaryCopy,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.45,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _summarySection(BuildContext context, List<CivicTerm> terms) {
    final args = widget.args;
    if (args.summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _attribution(context, args.summaryVersion, args.summaryDate),
          const SizedBox(height: 10),
          _summaryBody(context, terms, args.summary!, args.summaryTruncated),
        ],
      );
    }
    if (_liveSummary != null) {
      return FutureBuilder<LiveBillSummary?>(
        future: _liveSummary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final live = snapshot.data;
          if (live == null) return _noSummary(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _attribution(context, live.version, live.date),
              const SizedBox(height: 10),
              _summaryBody(context, terms, live.text, live.truncated),
            ],
          );
        },
      );
    }
    return _noSummary(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = widget.args;
    final terms =
        ref.watch(atlasReferenceProvider).value?.terms ?? const <CivicTerm>[];

    return Scaffold(
      appBar: AppBar(title: Text(args.bill)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            args.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (args.originDetail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                args.originDetail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'WHAT THIS BILL DOES'),
          const SizedBox(height: 8),
          _summarySection(context, terms),
          if (args.action.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel(context, 'LATEST ACTION'),
            const SizedBox(height: 8),
            Text(
              args.actionDate,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            VocabRichText(text: args.action, terms: terms),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse(args.url),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('View the official record on congress.gov'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'From congress.gov, the official record of Congress. '
            'Politiface adds no commentary.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
