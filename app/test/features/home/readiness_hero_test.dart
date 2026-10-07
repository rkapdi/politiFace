// Home's readiness card below the projection threshold: progress toward
// the 8 answers the projection needs, not "No signal yet", once a student
// has answered anything (onboarding's diagnostic deals 5).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/domain/readiness_projection.dart';
import 'package:politiface/features/home/application/home_providers.dart';
import 'package:politiface/features/home/presentation/home_screen.dart';

Widget _hero(int recent) => ProviderScope(
      overrides: [
        readinessSummaryProvider.overrideWith((ref) async => null),
        recentFcleAnswerCountProvider.overrideWith((ref) async => recent),
      ],
      child: const MaterialApp(home: Scaffold(body: ReadinessHero())),
    );

void main() {
  testWidgets('after the diagnostic: progress toward the projection',
      (tester) async {
    await tester.pumpWidget(_hero(5));
    await tester.pumpAndSettle();
    expect(find.text('5 of $kMinAnswersForProjection answers'), findsOneWidget);
    expect(find.textContaining('3 more'), findsOneWidget);
    expect(find.text('No signal yet'), findsNothing);
  });

  testWidgets('nothing answered yet: no signal', (tester) async {
    await tester.pumpWidget(_hero(0));
    await tester.pumpAndSettle();
    expect(find.text('No signal yet'), findsOneWidget);
  });
}
