// lib/features/pulse/presentation/vocab_rich_text.dart
//
// Text with Atlas vocabulary terms rendered as tappable spans. Tapping a
// term opens a bottom sheet with the existing cited definition; no new
// content is authored here. Matching is whole-word, case-insensitive,
// longest term first, first occurrence per term only.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../atlas/data/atlas_reference_loader.dart';

class VocabRichText extends StatefulWidget {
  const VocabRichText({
    required this.text,
    required this.terms,
    super.key,
    this.style,
  });

  final String text;
  final List<CivicTerm> terms;
  final TextStyle? style;

  @override
  State<VocabRichText> createState() => _VocabRichTextState();
}

class _TermMatch {
  const _TermMatch(this.start, this.end, this.term);

  final int start;
  final int end;
  final CivicTerm term;
}

class _VocabRichTextState extends State<VocabRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  List<_TermMatch> _matches() {
    final sorted = [...widget.terms]
      ..sort((a, b) => b.term.length.compareTo(a.term.length));
    final claimed = <_TermMatch>[];
    for (final term in sorted) {
      if (term.term.trim().isEmpty) continue;
      final pattern = RegExp(
        '\\b${RegExp.escape(term.term)}\\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(widget.text);
      if (match == null) continue;
      final overlaps =
          claimed.any((c) => match.start < c.end && match.end > c.start);
      if (overlaps) continue;
      claimed.add(_TermMatch(match.start, match.end, term));
    }
    claimed.sort((a, b) => a.start.compareTo(b.start));
    return claimed;
  }

  void _showTerm(CivicTerm term) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term.term,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  term.definition,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse(term.citation),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final style =
        widget.style ?? theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final matches = _matches();

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showTerm(m.term);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: widget.text.substring(m.start, m.end),
          style: (style ?? const TextStyle()).copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: recognizer,
          semanticsLabel: '${m.term.term}, tap for definition',
        ),
      );
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: style, children: spans));
  }
}
