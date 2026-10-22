// Walks the guided tour on a simulator, printing `QA_SHOT tour_<n>` at
// each step so a host watcher can screenshot where the yellow spotlight
// lands. On a fresh install it finishes onboarding first (run without the
// backend dart-defines so there is no account step); otherwise it replays
// the tour from Settings.
//
//   flutter test integration_test/guided_tour_walk_test.dart -d <sim>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:politiface/main.dart' as app;

Future<void> settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('replayed tour: the spotlight lands on each target',
      (tester) async {
    await app.main();
    await settle(tester, 40);
    if (find.text('START THE DIAGNOSTIC').evaluate().isNotEmpty) {
      // Fresh install (run without backend dart-defines, so no account
      // step): finish onboarding; the tour then fires on the first Home
      // landing, mid-transition, which is the case that broke.
      await tester.tap(find.text('START THE DIAGNOSTIC'));
      await settle(tester);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('diag-opt-0')));
        await settle(tester, 6);
        await tester.tap(find.text(i == 4 ? 'SEE YOUR RESULT' : 'NEXT'));
        await settle(tester, 6);
      }
      await tester.tap(find.text('START STUDYING'));
      // Deliberately few frames: catch step one while Home settles.
      await settle(tester, 4);
    } else {
      // Onboarding already done: replay from Settings.
      if (find.text('SKIP').evaluate().isNotEmpty) {
        await tester.tap(find.text('SKIP').first);
        await settle(tester);
      }
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/settings');
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Show me around'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Show me around'));
      await settle(tester, 40);
    }

    for (var i = 1; i <= 6; i++) {
      await settle(tester, 10);
      // ignore: avoid_print
      print('QA_SHOT tour_$i');
      await Future<void>.delayed(const Duration(seconds: 3));
      final next = find.textContaining('NEXT');
      final done = find.textContaining('DONE');
      if (next.evaluate().isNotEmpty) {
        await tester.tap(next.first);
      } else if (done.evaluate().isNotEmpty) {
        await tester.tap(done.first);
      } else {
        break;
      }
      await settle(tester);
    }
  });
}
