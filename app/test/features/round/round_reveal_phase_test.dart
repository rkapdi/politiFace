// Regression test for the reveal-screen clipping bug: on a short viewport
// the chapter-complete banner used to sit inside a fixed, non-scrolling
// Column with `Spacer()`s, so once content exceeded the available height
// the banner (and CTA row below it) clipped instead of scrolling into
// view. Pumps at a small physical size to reproduce a keyboard-shrunk /
// small-device viewport and asserts the banner text is reachable and no
// RenderFlex overflow is thrown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/features/round/domain/round_state.dart';
import 'package:politiface/features/round/presentation/round_reveal_phase.dart';
import 'package:politiface/features/trivia/domain/trivia_scoring.dart';

DailyRoundState _finalDayState() => DailyRoundState(
      dateIso: '2026-07-12',
      chapterId: 'ch1',
      chapterTitle: 'The Executive',
      chapterSubtitle: 'Sub',
      dayInChapter: 3,
      daysInChapter: 3,
      phase: RoundPhase.reveal,
      cards: const [],
      trivia: const [],
      nextChapterTitle: 'The Legislature',
      result: TriviaResult(
        totalScore: 120,
        correctCount: 9,
        totalQuestions: 10,
        averageConfidence: 2.4,
        archetype: TriviaArchetype.civicScholar,
        gridEmojis: [...List.filled(9, '🟩'), '🟨'],
      ),
    );

Widget _app(DailyRoundState state) {
  final router = GoRouter(
    initialLocation: '/round',
    routes: [
      GoRoute(
        path: '/round',
        builder: (_, __) => RoundRevealPhase(state: state, onDone: () {}),
      ),
      GoRoute(
        path: '/round/review',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
      'chapter-complete banner scrolls into view on a short viewport '
      'without overflowing', (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    // Small enough to force the reveal content taller than the viewport
    // (simulates a small device / keyboard-shrunk safe area).
    tester.view.physicalSize = const Size(375, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    await tester.pumpWidget(_app(_finalDayState()));
    await tester.pumpAndSettle();

    // No RenderFlex overflow (would surface as a FlutterError caught by
    // the test binding and fail the test via takeException below).
    expect(tester.takeException(), isNull);

    final bannerFinder = find.text('CHAPTER COMPLETE');
    expect(bannerFinder, findsOneWidget);

    // Scroll it into view the way a real user would, then confirm it is
    // actually laid out on-screen (not clipped) and hittable.
    await tester.scrollUntilVisible(
      bannerFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(bannerFinder).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
