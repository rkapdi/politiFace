// Onboarding: three pages, skippable everywhere, no account ask, sets
// both its own flag and the old home-tour flag so orientations never
// stack.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/home/presentation/first_run_tour.dart';
import 'package:politiface/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget host({String start = '/onboarding'}) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: start,
            routes: [
              GoRoute(
                path: '/onboarding',
                builder: (_, __) => const OnboardingScreen(),
              ),
              GoRoute(
                path: '/',
                builder: (_, __) => const Scaffold(body: Text('HOME')),
              ),
              GoRoute(
                path: '/fcle',
                builder: (_, __) => const Scaffold(body: Text('FCLE HUB')),
              ),
              GoRoute(
                path: '/leaderboard',
                builder: (_, __) => const Scaffold(body: Text('CLASS')),
              ),
            ],
          ),
        ),
      );

  testWidgets('walks three pages and lands on the FCLE hook', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Pass the FCLE with confidence'), findsOneWidget);
    // No account ask anywhere in onboarding: the no-signup-wall rule.
    expect(find.textContaining('Sign in'), findsNothing);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Learn it once, keep it for good'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Could you pass it today?'), findsOneWidget);

    // Drift futures need the real event loop; fake-async would hang on
    // the flag writes inside _finish.
    await tester.runAsync(() async {
      await tester.tap(find.text('SEE IF YOU CAN PASS'));
      // Real delay (not pump): lets the handler's drift awaits and the
      // context.go continuation run to completion on the live event loop.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('FCLE HUB'), findsOneWidget);

    final done = await tester.runAsync(
      () => db.metaDao.get(OnboardingScreen.doneFlagKey),
    );
    final tour = await tester.runAsync(
      () => db.metaDao.get(FirstRunTour.flagKey),
    );
    expect(done, '1');
    expect(tour, '1');
  });

  testWidgets('SKIP exits to home from the first page and persists',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.runAsync(() async {
      await tester.tap(find.text('SKIP'));
      // Real delay (not pump): lets the handler's drift awaits and the
      // context.go continuation run to completion on the live event loop.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    final done = await tester.runAsync(
      () => db.metaDao.get(OnboardingScreen.doneFlagKey),
    );
    expect(done, '1');
  });

  testWidgets('class-code path routes to the leaderboard', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('I HAVE A CLASS CODE'));
      // Real delay (not pump): lets the handler's drift awaits and the
      // context.go continuation run to completion on the live event loop.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('CLASS'), findsOneWidget);
  });
}
