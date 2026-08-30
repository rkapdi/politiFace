import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/pulse/data/pulse_live_service.dart';
import 'package:politiface/features/pulse/presentation/action_detail_screen.dart';

void main() {
  group('parseWhActions', () {
    test('parses the fast-lane payload shape', () {
      final actions = parseWhActions({
        'actions': [
          {
            'guid': 'https://www.whitehouse.gov/?p=49230',
            'title': 'Establishing the United States Space Academy',
            'url': 'https://www.whitehouse.gov/presidential-actions/x/',
            'published_at': '2026-08-28T17:20:24.000Z',
            'kind': 'proclamation',
          },
          {
            'guid': 'https://www.whitehouse.gov/?p=49180',
            'title':
                'Honoring the American History of the Great Lakes and Renaming Lake Ontario as Lake America',
            'url': 'https://www.whitehouse.gov/presidential-actions/y/',
            'published_at': '2026-08-27T21:00:35.000Z',
            'kind': 'executive_order',
          },
          {'guid': 'g', 'title': ''}, // dropped: no title
        ],
      });
      expect(actions.length, 2);
      expect(actions[0].kindLabel, 'PROCLAMATION');
      expect(actions[1].kindLabel, 'EXECUTIVE ORDER');
      expect(actions[1].title, contains('Lake America'));
    });

    test('handles a missing or empty payload', () {
      expect(parseWhActions({}), isEmpty);
      expect(parseWhActions({'actions': []}), isEmpty);
    });
  });

  group('whActionCoveredByOrder', () {
    const action = LiveWhAction(
      guid: 'g',
      title: 'Securing the Nation Against Advanced Cryptographic Attacks',
      url: 'u',
      publishedAt: '2026-06-22T00:00:00Z',
      kind: 'executive_order',
    );

    test('covered when a Federal Register order carries the same title', () {
      const order = LiveOrder(
        number: 14412,
        title:
            'Securing the Nation Against Advanced Cryptographic Attacks',
        president: 'Donald J. Trump',
        signingDate: '2026-06-22',
        url: 'https://www.federalregister.gov/x',
      );
      expect(whActionCoveredByOrder(action, const [order]), isTrue);
    });

    test('not covered by an unrelated order', () {
      const order = LiveOrder(
        number: 1,
        title: 'A Completely Different Subject',
        president: 'x',
        signingDate: '2026-01-01',
        url: 'u',
      );
      expect(whActionCoveredByOrder(action, const [order]), isFalse);
    });
  });

  group('ActionDetailArgs.fromQuery', () {
    test('round-trips the server-built deep link', () {
      final route = Uri(
        path: '/pulse/action',
        queryParameters: {
          't': 'Renaming Lake Ontario as Lake America',
          'u': 'https://www.whitehouse.gov/presidential-actions/y/',
          'k': 'executive_order',
          'd': '2026-08-27T21:00:35.000Z',
        },
      ).toString();
      final args =
          ActionDetailArgs.fromQuery(Uri.parse(route).queryParameters);
      expect(args.title, 'Renaming Lake Ontario as Lake America');
      expect(args.kind, 'executive_order');
      expect(args.kindLabel, 'EXECUTIVE ORDER');
      expect(args.date, startsWith('2026-08-27'));
    });
  });

  testWidgets('ActionDetailScreen renders the action with provenance',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ActionDetailScreen(
          args: ActionDetailArgs(
            title: 'Establishing the United States Space Academy',
            url: 'https://www.whitehouse.gov/presidential-actions/x/',
            kind: 'proclamation',
            date: '2026-08-28T17:20:24.000Z',
          ),
        ),
      ),
    );
    expect(find.text('PROCLAMATION'), findsOneWidget);
    expect(
      find.text('Establishing the United States Space Academy'),
      findsOneWidget,
    );
    expect(find.textContaining('Announced 2026-08-28'), findsOneWidget);
    expect(
      find.textContaining('Federal Register publishes'),
      findsOneWidget,
    );
    expect(find.text('Read the full text at whitehouse.gov'), findsOneWidget);
    // FilledButton.icon builds a private subtype; match by predicate.
    expect(
      find.byWidgetPredicate((w) => w is FilledButton),
      findsOneWidget,
    );
  });
}
