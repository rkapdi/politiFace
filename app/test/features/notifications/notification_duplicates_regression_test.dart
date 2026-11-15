// Regression tests for the duplicate and unreadable Washington notifications
// fixed in 1.3.3:
//
//   (a) A digest never marked the items it covered as delivered, so the same
//       backlog came back the next day inside a bigger digest.
//   (b) Sweeps started from app launch, a silent push and the background
//       refresh task could overlap, each reading the same empty log and each
//       sending.
//   (c) The alert log stored only keys, so a digest could not be read back
//       once the live feed moved on, and two actions on one bill collapsed
//       into one row.
//   (d) Routine procedural bill actions (referrals to committee and the
//       like) were counted as updates.

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/notifications/data/notification_orchestrator.dart';
import 'package:politiface/features/notifications/data/notification_sender.dart';
import 'package:politiface/features/notifications/data/washington_watch_service.dart';
import 'package:politiface/features/notifications/domain/alert_log.dart';
import 'package:politiface/features/pulse/data/pulse_live_service.dart';

class _Sent {
  _Sent(this.id, this.title, this.body, this.payload);
  final int id;
  final String title;
  final String body;
  final String? payload;
}

/// Records every send. Shared by all the orchestrators in a test, the way
/// one phone has one notification centre.
class RecordingSender implements NotificationSender {
  final sent = <_Sent>[];

  @override
  Future<bool> isAuthorized() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // A real send crosses a platform channel: yield, so overlapping sweeps
    // really do interleave here.
    await Future<void>.delayed(Duration.zero);
    sent.add(_Sent(id, title, body, payload));
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await Future<void>.delayed(Duration.zero);
    sent.add(_Sent(id, title, body, payload));
  }

  @override
  Future<void> cancel(int id) async {}
}

class FakeFetcher implements PulseFetcher {
  FakeFetcher({this.orders = const [], this.bills = const []});
  List<LiveOrder> orders;
  List<LiveBillAction> bills;
  int fetches = 0;

  @override
  Future<LivePulse> fetchPulse() async {
    fetches++;
    // A real fetch is a network round trip: yield, so overlapping sweeps
    // all get past their "nothing sent yet" reads before any of them sends.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return LivePulse(orders: orders, bills: bills);
  }

  @override
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async =>
      null;
}

LiveOrder order(int n, {String? title}) => LiveOrder(
      number: n,
      title: title ?? 'Order $n',
      // No face card exists for this name, so every order is "general".
      president: 'A President',
      signingDate: '2026-07-10',
      url: 'https://www.federalregister.gov/d/$n',
    );

LiveBillAction bill(
  String number,
  String action, {
  String date = '2026-07-10',
  String? title,
}) =>
    LiveBillAction(
      bill: number,
      title: title ?? 'A bill about $number',
      actionDate: date,
      action: action,
      url: 'https://www.congress.gov/bill/$number',
      congress: 119,
    );

Future<void> seedBaselines(AppDatabase db) async {
  await db.metaDao.set('watch.last_eo_number', '5');
  await db.metaDao.set('watch.last_law', '2026-01-01');
  await db.metaDao.set('watch.last_bill_action_date', '2026-01-01');
}

void main() {
  final now = DateTime(2026, 7, 12, 15); // outside quiet hours

  group('one database', () {
    late AppDatabase db;
    late RecordingSender sender;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      sender = RecordingSender();
    });
    tearDown(() => db.close());

    NotificationOrchestrator orchestrator(FakeFetcher fetcher, DateTime at) =>
        NotificationOrchestrator(
          db: db,
          washington: WashingtonWatchService(
            db: db,
            fetcher: fetcher,
            sender: sender,
            now: () => at,
          ),
          sender: sender,
          now: () => at,
        );

    // ── (a) ──────────────────────────────────────────────────────────────
    test('a delivered digest marks every item it covered as delivered',
        () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);

      await orchestrator(fetcher, now).run();
      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.title, '5 updates from Washington');
      // The baseline moved past everything the digest covered...
      expect(await db.metaDao.get('watch.last_eo_number'), '10');

      // ...so the next day, with the same feed, there is nothing to say.
      final nextDay = now.add(const Duration(days: 1));
      await orchestrator(fetcher, nextDay).run();
      expect(sender.sent, hasLength(1), reason: 'the backlog came back');
    });

    test('the next day reports only what is new, not the old backlog again',
        () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);
      await orchestrator(fetcher, now).run();

      fetcher.orders = [...fetcher.orders, order(11, title: 'The new one')];
      await orchestrator(fetcher, now.add(const Duration(days: 1))).run();

      expect(sender.sent, hasLength(2));
      // One new order is a single alert about that order, not "6 updates".
      expect(sender.sent.last.title, 'New executive order');
      expect(sender.sent.last.body, 'The new one');
    });

    test('items a digest covered stay quiet even if a baseline fails to move',
        () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);
      await orchestrator(fetcher, now).run();
      // Simulate the pre-fix state: the digest went out, the baseline did
      // not advance.
      await db.metaDao.set('watch.last_eo_number', '5');

      await orchestrator(fetcher, now.add(const Duration(days: 1))).run();
      expect(sender.sent, hasLength(1));
      // ...and the baseline is healed rather than left behind.
      expect(await db.metaDao.get('watch.last_eo_number'), '10');
    });

    test('after updating, a digest the previous build sent is not sent again',
        () async {
      await seedBaselines(db);
      // What a build before 1.3.3 left behind: yesterday's digest in the
      // alert log with only the keys it covered, its own key in the old
      // sent log, and baselines that never moved.
      final yesterday = now.subtract(const Duration(days: 1));
      await db.metaDao.set(
        kAlertLogKey,
        '[{"t":"Washington was busy: 5 updates in The Pulse.","b":"",'
        '"at":${yesterday.millisecondsSinceEpoch},'
        '"ks":["eo:6","eo:7","eo:8","eo:9","eo:10"]}]',
      );
      await db.metaDao.set(
        'notif.log',
        '[{"k":"wash:summary:2026-07-11",'
            '"t":${yesterday.millisecondsSinceEpoch}}]',
      );
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);

      await orchestrator(fetcher, now).run();

      expect(sender.sent, isEmpty, reason: 'the old backlog was sent again');
      // And the baseline is caught up, so it stays quiet after the
      // cooldown too.
      expect(await db.metaDao.get('watch.last_eo_number'), '10');
      await orchestrator(fetcher, now.add(const Duration(days: 5))).run();
      expect(sender.sent, isEmpty);
    });

    // ── (b) ──────────────────────────────────────────────────────────────
    test('three sweeps at once deliver exactly one notification', () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [order(6, title: 'The only new order')]);

      // App launch, a silent push and the background task, all at once.
      await Future.wait([
        for (var i = 0; i < 3; i++) orchestrator(fetcher, now).run(),
      ]);

      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.body, 'The only new order');
      // The two that lost the lock did no work at all.
      expect(fetcher.fetches, 1);
      expect(parseAlertLog(await db.metaDao.get(kAlertLogKey)), hasLength(1));
    });

    test('three sweeps at once deliver one digest, not three', () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);

      await Future.wait([
        for (var i = 0; i < 3; i++) orchestrator(fetcher, now).run(),
      ]);

      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.title, '5 updates from Washington');
    });

    test('the lock is released, so the next sweep runs normally', () async {
      await seedBaselines(db);
      final fetcher = FakeFetcher(orders: [order(6)]);
      await orchestrator(fetcher, now).run();
      expect(await db.metaDao.get('notif.sweep_lock'), isNull);

      fetcher.orders = [order(6), order(7)];
      await orchestrator(fetcher, now.add(const Duration(hours: 4))).run();
      expect(sender.sent, hasLength(2));
    });

    test('a sweep does nothing while another holds a live lock', () async {
      await seedBaselines(db);
      final held = now.add(const Duration(minutes: 1)).millisecondsSinceEpoch;
      await db.metaDao.set('notif.sweep_lock', '$held|another-sweep');
      final fetcher = FakeFetcher(orders: [order(6)]);

      await orchestrator(fetcher, now).run();

      expect(sender.sent, isEmpty);
      expect(fetcher.fetches, 0);
      // It never releases a lock it does not hold.
      expect(await db.metaDao.get('notif.sweep_lock'), '$held|another-sweep');
    });

    test('a lock left by a sweep that died expires and is taken over',
        () async {
      await seedBaselines(db);
      final expired =
          now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
      await db.metaDao.set('notif.sweep_lock', '$expired|dead-sweep');
      final fetcher = FakeFetcher(orders: [order(6)]);

      await orchestrator(fetcher, now).run();

      expect(sender.sent, hasLength(1));
      expect(await db.metaDao.get('notif.sweep_lock'), isNull);
    });

    test('a key already recorded as sent is never sent again', () async {
      await seedBaselines(db);
      // Another run recorded the send a moment ago; this sweep read its
      // candidates before that and would otherwise send a second copy.
      await db.metaDao.set(
        'notif.sent:eo:6',
        now.millisecondsSinceEpoch.toString(),
      );
      await orchestrator(FakeFetcher(orders: [order(6)]), now).run();
      expect(sender.sent, isEmpty);
    });

    test('a notification sent by the previous build still counts', () async {
      await seedBaselines(db);
      // The pre-1.3.3 JSON log, written minutes before the update.
      await db.metaDao.set(
        'notif.log',
        '[{"k":"eo:6","t":${now.millisecondsSinceEpoch - 60000}}]',
      );
      await orchestrator(FakeFetcher(orders: [order(6)]), now).run();
      expect(sender.sent, isEmpty);
    });

    // ── (c) ──────────────────────────────────────────────────────────────
    test('a digest log entry stores every item with title, date, kind, link',
        () async {
      await seedBaselines(db);
      final fetcher = FakeFetcher(
        orders: [order(6, title: 'An order')],
        bills: [
          // Two actions on ONE bill, on different days: two items, not one.
          bill('HR 8121', 'Passed House', date: '2026-07-08', title: 'A Act'),
          bill('HR 8121', 'Passed Senate', title: 'A Act'),
          bill('S 44', 'Became Public Law 119-12', title: 'B Act'),
        ],
      );

      await orchestrator(fetcher, now).run();

      final entry = parseAlertLog(await db.metaDao.get(kAlertLogKey)).single;
      expect(entry.id, 'wash:summary:2026-07-12');
      expect(entry.title, '4 updates from Washington');
      expect(
        entry.body,
        '1 executive order, 1 new law and 2 bill actions. '
        'Tap to read each one.',
      );
      expect(entry.items, hasLength(4));

      final byKey = {for (final i in entry.items) i.key: i};
      final eo = byKey['eo:6']!;
      expect(eo.kind, AlertItem.kindOrder);
      expect(eo.title, 'An order');
      expect(eo.date, '2026-07-10');
      expect(eo.url, 'https://www.federalregister.gov/d/6');
      expect(eo.number, 6);

      final house = byKey['bill:HR 8121:2026-07-08']!;
      final senate = byKey['bill:HR 8121:2026-07-10']!;
      expect(house.kind, AlertItem.kindBill);
      expect(house.action, 'Passed House');
      expect(house.date, '2026-07-08');
      expect(senate.action, 'Passed Senate');
      expect(senate.date, '2026-07-10');
      expect(senate.bill, 'HR 8121');
      expect(senate.congress, 119);
      expect(senate.url, 'https://www.congress.gov/bill/HR 8121');

      final law = byKey['law:S 44:2026-07-10']!;
      expect(law.kind, AlertItem.kindLaw);
      expect(law.title, 'B Act');
      expect(law.action, 'Became Public Law 119-12');
    });

    test('tapping a digest opens that digest, not the plain feed', () async {
      await seedBaselines(db);
      final fetcher =
          FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);
      await orchestrator(fetcher, now).run();

      final payload = sender.sent.single.payload!;
      expect(payload, isNot('/pulse'));
      final uri = Uri.parse(payload);
      expect(uri.path, '/pulse');
      // The route names the log entry the notification belongs to.
      final entry = parseAlertLog(await db.metaDao.get(kAlertLogKey)).single;
      expect(uri.queryParameters['alert'], entry.id);
    });

    test('a single alert stores its item too, and routes to it', () async {
      await seedBaselines(db);
      await orchestrator(
        FakeFetcher(bills: [bill('HR 9', 'Passed House', title: 'Nine Act')]),
        now,
      ).run();

      final entry = parseAlertLog(await db.metaDao.get(kAlertLogKey)).single;
      expect(entry.id, 'bill:HR 9:2026-07-10');
      expect(entry.items.single.title, 'Nine Act');
      expect(entry.items.single.action, 'Passed House');
      expect(
        Uri.parse(sender.sent.single.payload!).queryParameters['alert'],
        'bill:HR 9:2026-07-10',
      );
    });

    // ── (d) ──────────────────────────────────────────────────────────────
    test('routine procedural bill actions are not counted in the digest',
        () async {
      await seedBaselines(db);
      final fetcher = FakeFetcher(
        bills: [
          bill('HR 1', 'Passed House'),
          bill('HR 2', 'Passed Senate'),
          bill('S 3', 'Presented to President.'),
          bill('S 4', 'Ordered to be Reported by the Yeas and Nays: 14 - 9.'),
          // Routine: none of these may be counted or listed.
          bill('HR 5', 'Referred to the House Committee on the Judiciary.'),
          bill(
            'S 6',
            'Read twice and referred to the Committee on Finance.',
          ),
          bill('HR 7', 'Referred to the Subcommittee on Health.'),
          bill('HR 8', 'Introduced in House'),
          bill('HR 9', 'Sponsor introductory remarks on measure. (CR H884)'),
          bill('HR 10', 'Placed on the Union Calendar, Calendar No. 664.'),
        ],
      );

      await orchestrator(fetcher, now).run();

      expect(sender.sent.single.title, '4 updates from Washington');
      expect(
        sender.sent.single.body,
        '4 bill actions. Tap to read each one.',
      );
      final entry = parseAlertLog(await db.metaDao.get(kAlertLogKey)).single;
      expect(
        [for (final i in entry.items) i.bill],
        ['HR 1', 'HR 2', 'S 3', 'S 4'],
      );
    });

    test('a sweep of only routine actions sends nothing', () async {
      await seedBaselines(db);
      final fetcher = FakeFetcher(
        bills: [
          for (var n = 1; n <= 6; n++)
            bill('HR $n', 'Referred to the House Committee on Rules.'),
        ],
      );
      await orchestrator(fetcher, now).run();
      expect(sender.sent, isEmpty);
    });
  });

  test('isMeaningfulBillAction: routine steps out, real movement in', () {
    for (final routine in [
      'Referred to the House Committee on Energy and Commerce.',
      'Referred to the Committee on Ways and Means, and in addition to Rules',
      'Read twice and referred to the Committee on Finance.',
      'Referred to the Subcommittee on Aviation.',
      'Introduced in Senate',
      'Sponsor introductory remarks on measure. (CR H884)',
      'Placed on the Union Calendar, Calendar No. 664.',
      'Committee on Banking, Housing, and Urban Affairs. Hearings held.',
      'Forwarded by Subcommittee to Full Committee by Voice Vote.',
      'Received in the Senate.',
      'Held at the desk.',
      '',
    ]) {
      expect(isMeaningfulBillAction(routine), isFalse, reason: routine);
    }
    for (final meaningful in [
      'Passed House',
      'Passed Senate without amendment by Unanimous Consent.',
      'On passage Passed by the Yeas and Nays: 220 - 205 (Roll no. 123).',
      'Ordered to be Reported by the Yeas and Nays: 14 - 9.',
      'Presented to President.',
      'Signed by President.',
      'Vetoed by President.',
      'Became Public Law No: 119-12.',
    ]) {
      expect(isMeaningfulBillAction(meaningful), isTrue, reason: meaningful);
    }
  });

  // The background refresh task runs in its own isolate with its own
  // connection to the same database file. Three connections stand in for
  // launch, silent push and background task.
  test('three sweeps on three connections to one file deliver exactly once',
      () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('pf_sweep_');
    final file = File('${dir.path}/sweep.sqlite');
    final dbs = [
      for (var i = 0; i < 3; i++) AppDatabase.forTesting(NativeDatabase(file)),
    ];
    addTearDown(() async {
      for (final d in dbs) {
        await d.close();
      }
      await dir.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });
    for (final d in dbs) {
      await d.metaDao.get('warm'); // open and migrate one at a time
    }
    await seedBaselines(dbs.first);

    final sender = RecordingSender();
    final fetcher =
        FakeFetcher(orders: [for (var n = 6; n <= 10; n++) order(n)]);
    await Future.wait([
      for (final d in dbs)
        NotificationOrchestrator(
          db: d,
          washington: WashingtonWatchService(
            db: d,
            fetcher: fetcher,
            sender: sender,
            now: () => now,
          ),
          sender: sender,
          now: () => now,
        ).run(),
    ]);

    expect(sender.sent, hasLength(1));
    expect(sender.sent.single.title, '5 updates from Washington');
    expect(fetcher.fetches, 1);
    expect(await dbs.last.metaDao.get('watch.last_eo_number'), '10');
  });
}
