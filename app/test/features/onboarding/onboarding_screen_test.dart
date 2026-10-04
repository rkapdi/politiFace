// The diagnostic cold open (Move 1): value first, 5 quick questions that
// cannot be skipped, no account ask, and answers feed the readiness log.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/fcle/application/fcle_providers.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/onboarding/presentation/onboarding_screen.dart';

/// A tiny deterministic bank: 3 questions per domain, first option is
/// always correct, so the walker below has stable targets.
QuestionBank fakeBank() => QuestionBank({
      for (final d in FcleDomain.values)
        d: [
          for (var i = 0; i < 3; i++)
            FcleQuestion(
              id: '${d.code}-q$i',
              domain: d,
              stem: 'Question $i about ${d.label}?',
              options: const [
                FcleOption(key: 'a', text: 'Right answer'),
                FcleOption(key: 'b', text: 'Wrong answer'),
              ],
              answerKey: 'a',
              explanation: 'Because the Constitution says so.',
              citation: 'U.S. Const. art. I',
              difficulty: 1,
            ),
        ],
    });

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
        overrides: [
          databaseProvider.overrideWithValue(db),
          questionBankProvider.overrideWith((ref) => fakeBank()),
        ],
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
                path: '/leaderboard',
                builder: (_, __) => const Scaffold(body: Text('CLASS')),
              ),
            ],
          ),
        ),
      );

  testWidgets(
      'cold open leads with the question, no signup wall anywhere',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Could you pass the FCLE right now?'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
    expect(find.text('START THE DIAGNOSTIC'), findsOneWidget);
    expect(find.textContaining('5 quick questions'), findsOneWidget);
  });

  testWidgets('the diagnostic cannot be skipped, before or during',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('SKIP'), findsNothing);
    expect(find.textContaining('Explore on my own'), findsNothing);
    expect(find.textContaining('EXPLORE ON MY OWN'), findsNothing);

    await tester.tap(find.text('START THE DIAGNOSTIC'));
    for (var f = 0; f < 6; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('THE DIAGNOSTIC'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);
    // A real database round trip flushes the work the screen queued, so
    // teardown can close the database (same as the test below).
    await tester.runAsync(
      () => db.metaDao.get(OnboardingScreen.doneFlagKey),
    );
  });

  testWidgets(
      'starting the diagnostic shows a question; answering logs it '
      'and reveals the citation', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('START THE DIAGNOSTIC'));
    for (var f = 0; f < 6; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('THE DIAGNOSTIC'), findsOneWidget);
    expect(find.byKey(const Key('diag-opt-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('diag-opt-0')));
    // Real loop so the drift insert inside the answer handler lands.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    for (var f = 0; f < 4; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.textContaining('SOURCE'), findsOneWidget);

    // The diagnostic feeds the same local log that powers readiness.
    final counts = await tester.runAsync(() async {
      var total = 0;
      for (final code in [
        'american_democracy',
        'us_constitution',
        'founding_documents',
        'landmark_impact',
      ]) {
        total += await db.fcleAnswersDao.answerCount(code);
      }
      return total;
    });
    expect(counts, 1);
  });
}
