import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/shared/widgets/feedback_motion.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

Widget _reaction(AnswerReactionKind kind, {bool reduceMotion = false}) =>
    _host(
      AnswerReaction(
        kind: kind,
        child: const SizedBox(width: 100, height: 40, child: Text('A')),
      ),
      reduceMotion: reduceMotion,
    );

Matrix4? _transform(WidgetTester tester) {
  final t = find.descendant(
    of: find.byType(AnswerReaction),
    matching: find.byType(Transform),
  );
  if (t.evaluate().isEmpty) return null;
  return tester.widget<Transform>(t.first).transform;
}

void main() {
  testWidgets('a right answer pops, then settles back', (tester) async {
    await tester.pumpWidget(_reaction(AnswerReactionKind.none));
    await tester.pumpWidget(_reaction(AnswerReactionKind.correct));
    await tester.pump(const Duration(milliseconds: 130));
    final m = _transform(tester);
    expect(m, isNotNull);
    expect(m!.getMaxScaleOnAxis(), greaterThan(1.02));
    await tester.pumpAndSettle();
    expect(_transform(tester), isNull);
  });

  testWidgets('a wrong answer shakes sideways, then settles', (tester) async {
    await tester.pumpWidget(_reaction(AnswerReactionKind.none));
    await tester.pumpWidget(_reaction(AnswerReactionKind.wrong));
    await tester.pump(const Duration(milliseconds: 30));
    final m = _transform(tester);
    expect(m, isNotNull);
    expect(m!.getTranslation().x.abs(), greaterThan(1));
    await tester.pumpAndSettle();
    expect(_transform(tester), isNull);
  });

  testWidgets('Reduce Motion: no pop, no shake', (tester) async {
    await tester.pumpWidget(_reaction(AnswerReactionKind.none, reduceMotion: true));
    await tester.pumpWidget(_reaction(AnswerReactionKind.wrong, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_transform(tester), isNull);
  });

  testWidgets('scores count up to the final value', (tester) async {
    await tester.pumpWidget(
      _host(CountUpText(value: 80, format: (n) => '$n%')),
    );
    expect(find.text('0%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('80%'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('80%'), findsOneWidget);
    expect(find.bySemanticsLabel('80%'), findsOneWidget);
  });

  testWidgets('Reduce Motion: the score shows its final value at once',
      (tester) async {
    await tester.pumpWidget(
      _host(CountUpText(value: 80, format: (n) => '$n%'), reduceMotion: true),
    );
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('the confetti burst builds inside a stack without throwing',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 300,
          height: 500,
          child: Stack(children: [CelebrationBurst(fire: true, big: true)]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
