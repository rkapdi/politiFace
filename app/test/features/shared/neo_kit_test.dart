import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/editorial_theme.dart';
import 'package:politiface/features/shared/widgets/neo/neo_kit.dart';

Widget host(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('BrutalButton fires onPressed and exposes button semantics',
      (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      host(BrutalButton(label: 'Start', onPressed: () => fired++)),
    );
    expect(find.text('START'), findsOneWidget);
    await tester.tap(find.byType(BrutalButton));
    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets('DataBarcode renders one bar per unit, hollow misses on light',
      (tester) async {
    await tester.pumpWidget(
      host(
        const DataBarcode(hits: [true, false, true]),
        brightness: Brightness.light,
      ),
    );
    // 3 bars: 2 solid black hits + 1 hollow miss with a border.
    final containers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(DataBarcode),
            matching: find.byType(Container),
          ),
        )
        .toList();
    expect(containers, hasLength(3));
    final miss = containers[1].decoration! as BoxDecoration;
    expect(miss.border, isNotNull); // hollow, not colour-only
  });

  testWidgets('PowerlineBar colours only the active segment', (tester) async {
    await tester.pumpWidget(
      host(const PowerlineBar(active: ReadinessStage.onTrack)),
    );
    expect(find.text('on track'), findsOneWidget);
    expect(find.text('not yet'), findsOneWidget);
    final activeText =
        tester.widget<Text>(find.text('on track')).style!.color;
    final inactiveText =
        tester.widget<Text>(find.text('not yet')).style!.color;
    expect(activeText, EditorialPalette.inkInverted);
    expect(inactiveText, EditorialPalette.textDim);
  });

  testWidgets('PowerlineBar never clips "locked in" on narrow screens',
      (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 300,
          child: PowerlineBar(
            active: ReadinessStage.lockedIn,
            trailing: Text('OF 80'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('locked in'), findsOneWidget);
    expect(find.text('OF 80'), findsOneWidget);
  });

  testWidgets('PowerlineBar survives large accessibility text sizes',
      (tester) async {
    await tester.pumpWidget(
      host(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: SizedBox(
            width: 340,
            child: PowerlineBar(active: ReadinessStage.notYet),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('locked in'), findsOneWidget);
  });

  testWidgets('ResultsTicket shows ribbon only when a state earned it',
      (tester) async {
    await tester.pumpWidget(
      host(
        ResultsTicket(
          serial: 'Session 47',
          score: 8,
          outOf: 10,
          subline: 'Your best run this week.',
          hits: const [true, true, false, true, true],
          streakDays: 12,
          nextIn: '14h',
          ribbon: 'NEW BEST',
          onShare: () {},
        ),
      ),
    );
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.text('SHARE'), findsOneWidget);

    await tester.pumpWidget(
      host(
        ResultsTicket.daily(
          serial: 'Session 48',
          score: 6,
          outOf: 10,
          subline: 'Steady.',
          hits: const [true, false],
          streakDays: 13,
          nextIn: '14h',
          onShare: () {},
        ),
      ),
    );
    expect(find.text('NEW BEST'), findsNothing);
  });

  testWidgets('NeoToggleRow toggles from a tap anywhere on the row',
      (tester) async {
    bool? received;
    await tester.pumpWidget(
      host(
        NeoToggleRow(
          title: 'Daily review reminder',
          subtitle: 'One nudge at your usual hour.',
          value: false,
          onChanged: (v) => received = v,
        ),
      ),
    );
    await tester.tap(find.text('Daily review reminder'));
    expect(received, isTrue);
  });
}
