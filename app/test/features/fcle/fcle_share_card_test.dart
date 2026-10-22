import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/mock_engine.dart';
import 'package:politiface/features/fcle/presentation/fcle_share_card.dart';

MockResult _result({required int score, required bool passed}) => MockResult(
      score: score,
      total: 80,
      passed: passed,
      perDomain: {
        FcleDomain.americanDemocracy:
            const DomainScore(correct: 18, total: 20),
        FcleDomain.usConstitution: const DomainScore(correct: 15, total: 20),
        FcleDomain.foundingDocuments:
            const DomainScore(correct: 12, total: 20),
        FcleDomain.landmarkImpact: const DomainScore(correct: 11, total: 20),
      },
    );

Widget _host(MockResult result) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: FcleShareCard.canvasWidth,
            height: FcleShareCard.canvasHeight,
            child: FcleShareCard(result: result, dateLabel: 'Jul 4'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders a passing card without overflow', (tester) async {
    await tester.pumpWidget(_host(_result(score: 56, passed: true)));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('56', findRichText: true), findsOneWidget);
    expect(find.text('ABOVE THE PASSING BAR'), findsOneWidget);
    expect(find.text('politiface.app'), findsOneWidget);
  });

  testWidgets('renders a failing card without overflow', (tester) async {
    await tester.pumpWidget(_host(_result(score: 31, passed: false)));
    expect(tester.takeException(), isNull);
    expect(find.text('BELOW THE BAR, FOR NOW'), findsOneWidget);
    expect(find.text('Passing is 48 of 80.'), findsOneWidget);
  });

  testWidgets('renders with an empty per-domain map (degenerate result)',
      (tester) async {
    const degenerate = MockResult(
      score: 0,
      total: 80,
      passed: false,
      perDomain: {},
    );
    await tester.pumpWidget(_host(degenerate));
    expect(tester.takeException(), isNull);
  });
}
