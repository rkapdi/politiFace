// Regression: three routes built their screen with `state.extra! as T`.
// The argument only exists on an in-app push, so opening the same URL from
// a deep link, a notification, an initial route or a restored route
// crashed with a null check (or a bad cast). Each now falls back to a
// screen that needs nothing.
//
// These run against the app's real route table (buildRouter), not a copy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/app/router.dart';
import 'package:politiface/features/fcle/domain/mock_engine.dart';
import 'package:politiface/features/fcle/presentation/mock_result_screen.dart';
import 'package:politiface/features/live/application/live_session_controller.dart';
import 'package:politiface/features/live/presentation/live_session_screen.dart';
import 'package:politiface/features/pulse/presentation/bill_detail_screen.dart';

GoRoute routeAt(GoRouter router, String path) {
  GoRoute? found;
  void walk(List<RouteBase> routes) {
    for (final r in routes) {
      if (r is GoRoute && r.path == path) found = r;
      walk(r.routes);
    }
  }

  walk(router.configuration.routes);
  return found!;
}

GoRouterState stateFor(GoRouter router, String path, {Object? extra}) =>
    GoRouterState(
      router.configuration,
      uri: Uri.parse(path),
      matchedLocation: path,
      fullPath: path,
      pathParameters: const {},
      pageKey: ValueKey(path),
      extra: extra,
    );

const bill = BillDetailArgs(
  bill: 'HR 1',
  title: 'A bill',
  action: 'Passed House',
  actionDate: '2026-07-10',
  url: 'https://www.congress.gov/',
);
const live = LiveSessionArgs(sessionId: 's-1', title: 'Review');
const result = MockResult(score: 1, total: 2, passed: false, perDomain: {});

void main() {
  late GoRouter router;
  late BuildContext context;

  Future<void> boot(WidgetTester tester) async {
    router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
  }

  for (final (path, fallback, valid) in <(String, String, Object)>[
    ('/pulse/bill', '/pulse', bill),
    ('/live', '/', live),
    ('/fcle/result', '/fcle', result),
  ]) {
    testWidgets('$path with no argument falls back to $fallback',
        (tester) async {
      await boot(tester);
      final route = routeAt(router, path);

      // A deep link or restored route: no extra at all.
      final bare = stateFor(router, path);
      expect(await route.redirect!(context, bare), fallback);
      // Even if the redirect were bypassed, building must not throw.
      expect(route.builder!(context, bare), isA<SizedBox>());

      // An extra left over from some other route: wrong type.
      final wrong = stateFor(router, path, extra: 'not the right thing');
      expect(await route.redirect!(context, wrong), fallback);
      expect(route.builder!(context, wrong), isA<SizedBox>());
    });

    testWidgets('$path with its argument still opens', (tester) async {
      await boot(tester);
      final route = routeAt(router, path);
      final state = stateFor(router, path, extra: valid);

      expect(await route.redirect!(context, state), isNull);
      final screen = route.builder!(context, state);
      expect(
        screen,
        switch (path) {
          '/pulse/bill' => isA<BillDetailScreen>(),
          '/live' => isA<LiveSessionScreen>(),
          _ => isA<MockResultScreen>(),
        },
      );
    });
  }

  testWidgets('no route in the app force-unwraps a missing argument',
      (tester) async {
    await boot(tester);
    // Every route with a builder must survive being built with no extra,
    // or carry a redirect that sends such an arrival elsewhere.
    final failures = <String>[];
    Future<void> walk(List<RouteBase> routes, String prefix) async {
      for (final r in routes) {
        if (r is GoRoute && r.builder != null && !r.path.contains(':')) {
          final path = r.path.startsWith('/') ? r.path : '$prefix/${r.path}';
          final state = stateFor(router, path);
          final redirected =
              r.redirect == null ? null : await r.redirect!(context, state);
          if (redirected == null) {
            try {
              r.builder!(context, state);
            } catch (e) {
              failures.add('$path: $e');
            }
          }
        }
        await walk(r.routes, prefix);
      }
    }

    await walk(router.configuration.routes, '');
    expect(failures, isEmpty);
  });
}
