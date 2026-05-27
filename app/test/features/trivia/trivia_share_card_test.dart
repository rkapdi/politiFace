import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:politiface/features/trivia/domain/trivia_scoring.dart';
import 'package:politiface/features/trivia/presentation/trivia_share_card.dart';

/// Per-archetype fixtures matching the kinds of runs that actually produce
/// each archetype, so the golden looks like what a real user would share.
final _fixtures = <TriviaArchetype, TriviaResult>{
  TriviaArchetype.civicScholar: const TriviaResult(
    totalScore: 130,
    correctCount: 9,
    totalQuestions: 10,
    averageConfidence: 2.6,
    archetype: TriviaArchetype.civicScholar,
    gridEmojis: [
      '🟦', '🟦', '🟦', '🟦', '🟩', '🟦', '🟦', '🟦', '🟩', '🟦',
    ],
  ),
  TriviaArchetype.luckyGuesser: const TriviaResult(
    totalScore: 55,
    correctCount: 8,
    totalQuestions: 10,
    averageConfidence: 1.4,
    archetype: TriviaArchetype.luckyGuesser,
    gridEmojis: [
      '🟩', '🟩', '🟩', '🟧', '🟩', '🟩', '🟩', '🟩', '🟧', '🟩',
    ],
  ),
  TriviaArchetype.civicBullshitter: const TriviaResult(
    totalScore: -12,
    correctCount: 3,
    totalQuestions: 10,
    averageConfidence: 2.7,
    archetype: TriviaArchetype.civicBullshitter,
    gridEmojis: [
      '🟦', '🟥', '🟥', '🟦', '🟥', '🟥', '🟥', '🟦', '🟥', '🟥',
    ],
  ),
  TriviaArchetype.humbleApprentice: const TriviaResult(
    totalScore: 18,
    correctCount: 3,
    totalQuestions: 10,
    averageConfidence: 1.2,
    archetype: TriviaArchetype.humbleApprentice,
    gridEmojis: [
      '🟧', '🟧', '🟩', '🟧', '🟧', '🟩', '🟧', '🟧', '🟧', '🟩',
    ],
  ),
};

void main() {
  setUpAll(() {
    // Don't let google_fonts try to HTTP-fetch Plus Jakarta Sans in tests
    // — no network, just use the fallback TextStyle.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('TriviaShareCard', () {
    for (final entry in _fixtures.entries) {
      final archetype = entry.key;
      final fixture = entry.value;
      final slug = archetype.name; // dart enum .name -> e.g. "civicScholar"

      testWidgets(
        'renders without overflow for $slug',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              TriviaShareCard(
                result: fixture,
                dateLabel: 'May 26',
              ),
            ),
          );
          // If any RenderFlex overflowed during layout, the binding records
          // a FlutterError. The takeException() call asserts none fired.
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'shows wordmark + archetype name + score for $slug',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              TriviaShareCard(
                result: fixture,
                dateLabel: 'May 26',
              ),
            ),
          );

          expect(find.text('POLITIFACE'), findsOneWidget);
          expect(find.text('politiface.app'), findsOneWidget);
          expect(
            find.text(fixture.archetype.name.toUpperCase()),
            findsOneWidget,
          );
          final scorePrefix = fixture.totalScore > 0 ? '+' : '';
          expect(
            find.text('$scorePrefix${fixture.totalScore} / 150'),
            findsOneWidget,
          );
          expect(
            find.text(fixture.gridEmojis.join(' ')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'matches golden for $slug',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              RepaintBoundary(
                child: TriviaShareCard(
                  result: fixture,
                  dateLabel: 'May 26',
                ),
              ),
            ),
          );
          await expectLater(
            find.byType(TriviaShareCard),
            matchesGoldenFile('goldens/trivia_share_card_$slug.png'),
          );
        },
        // Skipped: google_fonts fetches Plus Jakarta Sans at runtime,
        // which doesn't work in test environments (no network) and falls
        // back differently per platform (macOS dev vs Linux CI). To
        // enable: bundle the TTF as an asset under `assets/fonts/`,
        // register in pubspec, and call FontLoader before the test.
        // Tracked as a v1.1 follow-up in the share-card plan.
        skip: true,
        tags: ['golden'],
      );
    }
  });

  group('formatShareCardDate', () {
    test('formats valid YYYY-MM-DD into "Mon D"', () {
      expect(formatShareCardDate('2026-05-26'), 'May 26');
      expect(formatShareCardDate('2026-01-01'), 'Jan 1');
      expect(formatShareCardDate('2026-12-31'), 'Dec 31');
    });

    test('passes through malformed input', () {
      expect(formatShareCardDate('not-a-date'), 'not-a-date');
      expect(formatShareCardDate('2026-13-01'), '2026-13-01');
      expect(formatShareCardDate(''), '');
    });
  });
}

/// Wrap the share card in the minimum scaffolding needed for layout (size,
/// theme, MediaQuery, Directionality). The card sizes itself to 360x640;
/// the SizedBox just gives the test viewport room.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: TriviaShareCard.canvasWidth,
          height: TriviaShareCard.canvasHeight,
          child: child,
        ),
      ),
    ),
  );
}
