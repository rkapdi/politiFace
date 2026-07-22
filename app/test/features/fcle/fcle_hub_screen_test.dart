import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/features/fcle/application/fcle_providers.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/presentation/fcle_hub_screen.dart';

// Empty bank: enough to render the hub without needing bundled assets.
const _emptyBank = QuestionBank(<FcleDomain, List<FcleQuestion>>{});

Widget _app(Map<FcleDomain, DomainReadiness> readiness) {
  final router = GoRouter(
    initialLocation: '/fcle',
    routes: [
      GoRoute(path: '/fcle', builder: (_, __) => const FcleHubScreen()),
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/fcle/blueprint',
        builder: (_, __) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/fcle/mock',
        builder: (_, __) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/fcle/practice',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      // Return non-Future values so the FutureProviders resolve on first
      // build: no async, no loading spinner, no bundled assets in the test.
      questionBankProvider.overrideWith((ref) => _emptyBank),
      readinessProvider.overrideWith((ref) => readiness),
      weakestDomainProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
      'readiness percentage floors instead of rounds at the pass threshold',
      (tester) async {
    // 59.9% must never display as "60%" (which would carry the
    // pass-threshold color even though it's below the 60% pass bar).
    final readiness = {
      for (final d in FcleDomain.values)
        d: DomainReadiness(domain: d, accuracy: 0.599, answerCount: 10),
    };
    await tester.pumpWidget(_app(readiness));
    await tester.pump();

    expect(find.text('60%'), findsNothing);
    expect(find.text('59%'), findsWidgets);
  });
}
