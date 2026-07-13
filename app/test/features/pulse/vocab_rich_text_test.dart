import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/atlas/data/atlas_reference_loader.dart';
import 'package:politiface/features/pulse/presentation/vocab_rich_text.dart';

const _veto = CivicTerm(
  id: 'veto',
  term: 'Veto',
  definition: "The President's constitutional power to refuse to sign a "
      'bill passed by Congress, sending it back with objections.',
  citation: 'https://uscourts.gov/glossary',
);

const _judicialReview = CivicTerm(
  id: 'judicial-review',
  term: 'Judicial review',
  definition: 'The power of courts to decide whether laws and government '
      'actions comply with the Constitution.',
  citation: 'https://www.archives.gov/milestone-documents/marbury-v-madison',
);

/// Every span in the tree that carries a tap recognizer, as (text, span).
List<TextSpan> _linkedSpans(WidgetTester tester) {
  final result = <TextSpan>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) result.add(span);
      return true;
    });
  }
  return result;
}

Widget _host(String text) => MaterialApp(
      home: Scaffold(
        body: VocabRichText(text: text, terms: const [_veto, _judicialReview]),
      ),
    );

void main() {
  testWidgets(
      'links the first occurrence per term, case-insensitively, '
      'and taps open the cited definition', (tester) async {
    await tester.pumpWidget(
      _host(
        'The President may veto a bill. A veto can be overridden. '
        'Judicial review applies.',
      ),
    );

    final spans = _linkedSpans(tester);
    expect(spans.length, 2);

    // Exactly one tappable span for veto: the first occurrence only.
    final vetoSpans = spans.where((s) => s.text == 'veto').toList();
    expect(vetoSpans.length, 1);

    // Case-insensitive whole-phrase match for Judicial review.
    final reviewSpans =
        spans.where((s) => s.text == 'Judicial review').toList();
    expect(reviewSpans.length, 1);

    // Accessibility: linked spans announce themselves.
    expect(vetoSpans.single.semanticsLabel, 'Veto, tap for definition');

    // Tapping the veto span opens the bottom sheet with the cited
    // definition and its source host.
    (vetoSpans.single.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.textContaining('refuse to sign a bill'), findsOneWidget);
    expect(find.textContaining('Source: uscourts.gov'), findsOneWidget);
  });

  testWidgets('word boundaries: no span inside a longer word', (tester) async {
    await tester.pumpWidget(_host('The bill was vetoed yesterday.'));
    expect(_linkedSpans(tester), isEmpty);
  });
}
