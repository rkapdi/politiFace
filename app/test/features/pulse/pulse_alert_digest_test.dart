// Regression: a digest notification ("N updates from Washington") could not
// be read. Tapping it opened the plain feed, and the row in The Pulse listed
// only whatever the live feed still held, with several actions on one bill
// collapsed into one row.
//
// Now the notification's route names its alert-log entry, and the sheet is
// built from the items stored in that entry. These tests run with an EMPTY
// live feed on purpose: nothing shown may depend on it.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/atlas/data/atlas_reference_loader.dart';
import 'package:politiface/features/notifications/domain/alert_log.dart';
import 'package:politiface/features/pulse/data/pulse_live_service.dart';
import 'package:politiface/features/pulse/presentation/bill_detail_screen.dart';
import 'package:politiface/features/pulse/presentation/pulse_screen.dart';

const _digestId = 'wash:summary:2026-07-12';

AlertLogEntry digest() => AlertLogEntry(
      id: _digestId,
      title: '5 updates from Washington',
      body: '1 executive order, 1 new law and 3 bill actions. '
          'Tap to read each one.',
      at: DateTime.now().subtract(const Duration(hours: 1)),
      items: const [
        AlertItem(
          key: 'eo:14500',
          kind: AlertItem.kindOrder,
          title: 'An Order About Widgets',
          date: '2026-07-10',
          url: 'https://www.federalregister.gov/d/14500',
          number: 14500,
        ),
        AlertItem(
          key: 'law:S 44:2026-07-10',
          kind: AlertItem.kindLaw,
          title: 'The Bridges Act',
          date: '2026-07-10',
          url: 'https://www.congress.gov/bill/s44',
          bill: 'S 44',
          action: 'Became Public Law 119-12',
        ),
        // Two actions on ONE bill: two rows.
        AlertItem(
          key: 'bill:HR 8121:2026-07-08',
          kind: AlertItem.kindBill,
          title: 'The Harbors Act',
          date: '2026-07-08',
          url: 'https://www.congress.gov/bill/hr8121',
          bill: 'HR 8121',
          action: 'Passed House',
        ),
        AlertItem(
          key: 'bill:HR 8121:2026-07-10',
          kind: AlertItem.kindBill,
          title: 'The Harbors Act',
          date: '2026-07-10',
          url: 'https://www.congress.gov/bill/hr8121',
          bill: 'HR 8121',
          action: 'Passed Senate',
        ),
        AlertItem(
          key: 'bill:S 9:2026-07-09',
          kind: AlertItem.kindBill,
          title: 'The Rivers Act',
          date: '2026-07-09',
          url: 'https://www.congress.gov/bill/s9',
          bill: 'S 9',
          action: 'Presented to President.',
        ),
      ],
    );

AlertLogEntry single() => AlertLogEntry(
      id: 'bill:HR 77:2026-07-11',
      title: 'Bill advancing',
      body: 'The Canals Act',
      at: DateTime.now().subtract(const Duration(minutes: 5)),
      items: const [
        AlertItem(
          key: 'bill:HR 77:2026-07-11',
          kind: AlertItem.kindBill,
          title: 'The Canals Act',
          date: '2026-07-11',
          url: 'https://www.congress.gov/bill/hr77',
          bill: 'HR 77',
          action: 'Passed House',
        ),
      ],
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<GoRouter> pumpPulse(
    WidgetTester tester, {
    required String location,
    List<AlertLogEntry> log = const [],
    String? rawLog,
  }) async {
    await tester.runAsync(
      () => db.metaDao.set(kAlertLogKey, rawLog ?? encodeAlertLog(log)),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/pulse',
          builder: (_, state) =>
              PulseScreen(alertId: state.uri.queryParameters['alert']),
        ),
        // Stand-in for the bill detail screen: shows what it was given.
        GoRoute(
          path: '/pulse/bill',
          builder: (_, state) {
            final a = state.extra! as BillDetailArgs;
            return Scaffold(
              body: Text(
                'DETAIL ${a.bill} | ${a.title} | ${a.action} | '
                '${a.actionDate} | ${a.originDetail}',
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          atlasReferenceProvider.overrideWith(
            (ref) => const AtlasReference(
              orders: [],
              terms: [],
              laws: [],
              bills: [],
              ordersUpdated: null,
              lawsCongress: null,
            ),
          ),
          // The live feed is EMPTY: the sheet must not need it.
          pulseLiveProvider.overrideWith(
            (ref) => const LivePulse(orders: [], bills: []),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
    return router;
  }

  testWidgets('a digest notification opens the digest with every item',
      (tester) async {
    try {
      await pumpPulse(
        tester,
        log: [digest()],
        location: pulseAlertRoute(_digestId),
      );

      expect(find.text('WHAT IT COVERED'), findsOneWidget);
      // The digest title also sits in the pinned list behind the sheet.
      expect(find.text('5 updates from Washington'), findsWidgets);
      expect(find.text('An Order About Widgets'), findsOneWidget);
      expect(find.text('Executive Order 14500'), findsOneWidget);
      expect(find.text('The Bridges Act'), findsOneWidget);
      expect(find.text('The Rivers Act'), findsOneWidget);
      // Both actions on HR 8121 are listed, each saying what happened.
      expect(find.text('The Harbors Act'), findsNWidgets(2));
      expect(find.text('HR 8121: Passed House'), findsOneWidget);
      expect(find.text('HR 8121: Passed Senate'), findsOneWidget);
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('a row opens the exact action the digest covered',
      (tester) async {
    try {
      await pumpPulse(
        tester,
        log: [digest()],
        location: pulseAlertRoute(_digestId),
      );

      await tester.tap(find.text('HR 8121: Passed House'));
      await settle(tester);

      expect(
        find.text(
          'DETAIL HR 8121 | The Harbors Act | Passed House | 2026-07-08 | null',
        ),
        findsOneWidget,
      );
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('a law row opens as a law', (tester) async {
    try {
      await pumpPulse(
        tester,
        log: [digest()],
        location: pulseAlertRoute(_digestId),
      );

      await tester.tap(find.text('The Bridges Act'));
      await settle(tester);

      expect(
        find.text(
          'DETAIL S 44 | The Bridges Act |  | 2026-07-10 | '
          'Became Public Law 119-12',
        ),
        findsOneWidget,
      );
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('a single bill alert opens that bill directly', (tester) async {
    try {
      await pumpPulse(
        tester,
        log: [single(), digest()],
        location: pulseAlertRoute('bill:HR 77:2026-07-11'),
      );

      expect(
        find.text(
          'DETAIL HR 77 | The Canals Act | Passed House | 2026-07-11 | null',
        ),
        findsOneWidget,
      );
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('a second notification opens while The Pulse is already up',
      (tester) async {
    try {
      final router = await pumpPulse(
        tester,
        log: [single(), digest()],
        location: '/pulse',
      );
      expect(find.text('WHAT IT COVERED'), findsNothing);

      router.go(pulseAlertRoute(_digestId));
      await settle(tester);

      expect(find.text('WHAT IT COVERED'), findsOneWidget);
      expect(find.text('HR 8121: Passed Senate'), findsOneWidget);
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('tapping the pinned digest row lists every item too',
      (tester) async {
    try {
      await pumpPulse(tester, log: [digest()], location: '/pulse');
      expect(find.text('FROM YOUR NOTIFICATIONS'), findsOneWidget);

      await tester.tap(find.textContaining('5 updates from Washington'));
      await settle(tester);

      expect(find.text('WHAT IT COVERED'), findsOneWidget);
      expect(find.text('HR 8121: Passed House'), findsOneWidget);
      expect(find.text('HR 8121: Passed Senate'), findsOneWidget);
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('an unknown alert id lands on the plain feed', (tester) async {
    try {
      await pumpPulse(
        tester,
        log: [digest()],
        location: pulseAlertRoute('wash:summary:1999-01-01'),
      );
      expect(find.text('The Pulse'), findsOneWidget);
      expect(find.text('WHAT IT COVERED'), findsNothing);
    } finally {
      await flush(tester, db);
    }
  });

  testWidgets('an entry from an older build (keys only) still opens',
      (tester) async {
    try {
      final at = DateTime.now().subtract(const Duration(hours: 2));
      await pumpPulse(
        tester,
        location: '/pulse',
        rawLog: '[{"t":"Washington was busy: 4 updates in The Pulse.","b":"",'
            '"at":${at.millisecondsSinceEpoch},'
            '"ks":["eo:1","eo:2","bill:HR 1:2026-07-01","bill:HR 2:2026-07-01"]}]',
      );

      await tester.tap(find.textContaining('Washington was busy'));
      await settle(tester);

      // No stored items and nothing in the feed: the sheet still shows what
      // the notification said rather than failing.
      expect(find.textContaining('DELIVERED'), findsOneWidget);
    } finally {
      await flush(tester, db);
    }
  });
}

/// Lets database reads (real async) and the frames that follow them finish.
/// Fixed pumps, not pumpAndSettle: a loading spinner would never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Final database flush. Queries the widgets started run inside the test's
/// fake clock; one real read drains the connection so closing it at teardown
/// cannot wait forever.
Future<void> flush(WidgetTester tester, AppDatabase db) =>
    tester.runAsync(() => db.metaDao.get(kAlertLogKey));
