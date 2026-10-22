// ClassBlock on Home: the MY CLASS card for cohort members, and a slim
// "Joining a class?" row for everyone else, so a student who signs in on a
// phone that already finished onboarding can still reach the class code
// screen. Rendered against provider overrides; no network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/features/home/presentation/class_block.dart';
import 'package:politiface/features/leaderboard/application/leaderboard_providers.dart';
import 'package:politiface/features/leaderboard/data/leaderboard_api.dart';

const cohortFixture = CohortInfo(
  id: 'c1',
  name: 'POS 2041-67',
  role: 'student',
  rosterName: 'Maria Lopez',
);

class _FixedSelection extends SelectedCohortId {
  @override
  Future<String?> build() async => null;
}

Widget _harness(Future<List<CohortInfo>> Function() cohorts) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: ClassBlock()),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (_, __) => const Scaffold(body: Text('class code screen')),
      ),
      GoRoute(
        path: '/class',
        builder: (_, __) => const Scaffold(body: Text('class messages')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      myCohortsProvider.overrideWith((ref) => cohorts()),
      selectedCohortIdProvider.overrideWith(_FixedSelection.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('no class yet: a join row that opens the class code screen',
      (tester) async {
    await tester.pumpWidget(_harness(() async => const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Joining a class?'), findsOneWidget);
    expect(find.textContaining('MY CLASS'), findsNothing);

    await tester.tap(find.textContaining('Joining a class?'));
    await tester.pumpAndSettle();
    expect(find.text('class code screen'), findsOneWidget);
  });

  testWidgets('in a class: the MY CLASS card, no join row', (tester) async {
    await tester.pumpWidget(_harness(() async => [cohortFixture]));
    await tester.pumpAndSettle();

    expect(find.textContaining('MY CLASS'), findsOneWidget);
    expect(find.textContaining('Joining a class?'), findsNothing);
  });
}
