// The tour's yellow spotlight must stay on its target when the target moves
// after the step starts: Home is still sliding in from onboarding, and
// late-loading content (readiness numbers, the class row) shifts the page.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/home/presentation/guided_tour.dart';

const _spotlight = Key('tour-spotlight');

Rect? spotlightTarget(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.byKey(_spotlight));
  // ignore: avoid_dynamic_calls
  return (paint.painter as dynamic).target as Rect?;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('the spotlight follows its target when the page shifts',
      (tester) async {
    final spacer = ValueNotifier<double>(100);
    late WidgetRef hostRef;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                hostRef = ref;
                return ValueListenableBuilder<double>(
                  valueListenable: spacer,
                  builder: (_, h, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: h),
                      KeyedSubtree(
                        key: GuidedTour.readinessKey,
                        child: const SizedBox(
                          width: 200,
                          height: 80,
                          child: Text('READINESS'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('READINESS'));
    // Not awaited: the future completes when the tour closes.
    GuidedTour.start(context, hostRef);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final before = spotlightTarget(tester);
    expect(before, isNotNull);
    expect(before!.top, closeTo(100 - 6, 1));

    // Late content pushes the card down after the step started.
    spacer.value = 300;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final after = spotlightTarget(tester);
    expect(after!.top, closeTo(300 - 6, 1),
        reason: 'the spotlight stayed where the card used to be',);

    // Close the tour so no timers or routes leak past the test.
    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => db.metaDao.get(GuidedTour.flagKey));
  });

  testWidgets('a target taller than the room around it keeps the card on '
      'screen', (tester) async {
    late WidgetRef hostRef;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                hostRef = ref;
                // Like the Memory empty state: one target fills the page.
                return Column(
                  children: [
                    const SizedBox(height: 40),
                    KeyedSubtree(
                      key: GuidedTour.readinessKey,
                      child: const SizedBox(
                        width: 400,
                        height: 520,
                        child: Text('TALL TARGET'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    GuidedTour.start(tester.element(find.text('TALL TARGET')), hostRef);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final title = tester.getRect(find.text('This band is the whole game'));
    final next = tester.getRect(find.textContaining('NEXT'));
    expect(title.top, greaterThanOrEqualTo(0), reason: 'card cut off at top');
    expect(next.bottom, lessThanOrEqualTo(screen.height),
        reason: 'card cut off at bottom',);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => db.metaDao.get(GuidedTour.flagKey));
  });
}
