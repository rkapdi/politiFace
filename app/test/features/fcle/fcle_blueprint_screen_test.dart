import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/features/fcle/application/objective_readiness.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/objective.dart';
import 'package:politiface/features/fcle/presentation/fcle_blueprint_screen.dart';

// A small stubbed taxonomy so the screen is testable with no published
// content. Readiness is provided directly (no database), and the exam verdict
// is produced by the real aggregation so the test exercises the same rollup
// the app uses.
const _objectives = [
  Objective(
    code: 'OBJ-CON-1',
    domain: FcleDomain.usConstitution,
    description: 'Analyse the legislative branch under Article I.',
  ),
  Objective(
    code: 'OBJ-DEM-1',
    domain: FcleDomain.americanDemocracy,
    description: 'Identify the core constitutional principles.',
  ),
];

ObjectiveReadiness _readiness(
  Objective o, {
  double? accuracy,
  int count = 0,
}) =>
    ObjectiveReadiness(
      code: o.code,
      domain: o.domain,
      description: o.description,
      accuracy: accuracy,
      count: count,
      state: readinessStateFor(accuracy: accuracy, count: count),
    );

Widget _app(Map<String, ObjectiveReadiness> readiness) {
  final router = GoRouter(
    initialLocation: '/fcle/blueprint',
    routes: [
      GoRoute(
        path: '/fcle/blueprint',
        builder: (_, __) => const FcleBlueprintScreen(),
      ),
      GoRoute(path: '/fcle', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/fcle/practice',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // Return non-Future values so the FutureProviders resolve on first
      // build: no async, no loading spinner, no database in the widget test.
      objectivesProvider.overrideWith((ref) => _objectives),
      objectiveReadinessProvider.overrideWith((ref) => readiness),
      examReadinessProvider
          .overrideWith((ref) => aggregateExamReadiness(readiness)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  // Objective rows live below the fold in a lazy ListView; scroll a finder
  // into view (building rows along the way) before asserting on it.
  Future<void> reveal(WidgetTester tester, Finder finder) => tester
      .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

  testWidgets('honest empty state before any answers', (tester) async {
    final readiness = {
      for (final o in _objectives) o.code: _readiness(o),
    };
    await tester.pumpWidget(_app(readiness));
    await tester.pump();

    // Verdict card (top of the screen) reports coverage, not a score.
    expect(find.text('0 of 2 objectives practiced'), findsOneWidget);
    expect(find.textContaining('Just starting'), findsOneWidget);

    // Objective descriptions render under their competency sections.
    await reveal(
      tester,
      find.text('Analyse the legislative branch under Article I.'),
    );
    expect(find.text('Analyse the legislative branch under Article I.'),
        findsOneWidget,);
    // Honest empty state: nothing graded before any answers.
    expect(find.text('Not practiced yet'), findsWidgets);
    // No accuracy line before any practice.
    expect(find.textContaining('Recent practice accuracy'), findsNothing);
  });

  testWidgets('shows factual accuracy + attempt count once practiced',
      (tester) async {
    final readiness = {
      _objectives[0].code:
          _readiness(_objectives[0], accuracy: 1, count: 4), // solid
      _objectives[1].code: _readiness(_objectives[1]), // unseen
    };
    await tester.pumpWidget(_app(readiness));
    await tester.pump();

    expect(find.text('1 of 2 objectives practiced'), findsOneWidget);
    await reveal(tester, find.text('SOLID'));
    expect(find.text('Recent practice accuracy 100%'), findsOneWidget);
    expect(find.text('4 attempts'), findsOneWidget);
    expect(find.text('SOLID'), findsOneWidget);
  });
}
