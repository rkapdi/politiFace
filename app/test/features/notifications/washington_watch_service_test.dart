import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/notifications/data/notification_sender.dart';
import 'package:politiface/features/notifications/data/washington_watch_service.dart';
import 'package:politiface/features/pulse/data/pulse_live_service.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

/// Fakes network results without touching HttpClient — the whole point of
/// the [PulseFetcher] seam.
class FakePulseFetcher implements PulseFetcher {
  FakePulseFetcher({this.orders = const [], this.bills = const []});
  List<LiveOrder> orders;
  List<LiveBillAction> bills;
  int fetchCount = 0;

  @override
  Future<LivePulse> fetchPulse() async {
    fetchCount++;
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

/// Fakes the plugin so tests never touch a platform channel. detectNewItems
/// never notifies, but the service still requires a sender to construct.
class FakeNotificationSender implements NotificationSender {
  bool authorized = true;

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

LiveOrder order(
  int number, {
  String title = 'An executive order',
  String president = 'A President',
}) =>
    LiveOrder(
      number: number,
      title: title,
      president: president,
      signingDate: '2026-07-01',
      url: 'https://federalregister.gov/d/$number',
    );

LiveBillAction lawAction({
  String bill = 'HR 100',
  String title = 'A bill that became law',
  String actionDate = '2026-07-01',
  int? congress = 119,
}) =>
    LiveBillAction(
      bill: bill,
      title: title,
      actionDate: actionDate,
      action: 'Became Public Law 119-1',
      url: 'https://congress.gov/bill',
      congress: congress,
    );

LiveBillAction billAction({
  String bill = 'S 200',
  String title = 'A bill still moving',
  String actionDate = '2026-07-01',
}) =>
    LiveBillAction(
      bill: bill,
      title: title,
      actionDate: actionDate,
      action: 'Passed Senate',
      url: 'https://congress.gov/bill',
      congress: 119,
    );

void main() {
  late AppDatabase db;
  late SettingsService settings;
  late FakeNotificationSender sender;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
    sender = FakeNotificationSender();
  });

  tearDown(() => db.close());

  WashingtonWatchService service({
    PulseFetcher? fetcher,
    DateTime Function()? now,
  }) =>
      WashingtonWatchService(
        db: db,
        fetcher: fetcher ?? FakePulseFetcher(),
        sender: sender,
        settings: settings,
        now: now ?? () => DateTime(2026, 7, 12, 10),
      );

  Future<void> seedBaselines() async {
    await db.metaDao.set('watch.last_eo_number', '5');
    await db.metaDao.set('watch.last_law', '2026-01-01');
    await db.metaDao.set('watch.last_bill_action_date', '2026-01-01');
  }

  test('first run writes baselines silently, detects nothing', () async {
    final fetcher = FakePulseFetcher(orders: [order(5)]);
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, isEmpty);
    expect(await db.metaDao.get('watch.last_eo_number'), '5');
  });

  test('a new EO is detected with its signing president and dedupe key',
      () async {
    await seedBaselines();

    final fetcher = FakePulseFetcher(
      orders: [order(6, title: 'EO 6 title', president: 'Jane Doe')],
    );
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, hasLength(1));
    expect(items.single.category, WatchCategory.executiveOrder);
    expect(items.single.title, 'EO 6 title');
    expect(items.single.personName, 'Jane Doe');
    expect(items.single.dedupeKey, 'eo:6');
    expect(await db.metaDao.get('watch.last_eo_number'), '6');
  });

  test('a new EO is not detected when the category is off', () async {
    await seedBaselines();
    await settings.setWashEosEnabled(false);

    final fetcher = FakePulseFetcher(orders: [order(6)]);
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, isEmpty);
    // Baseline still advances even though the category is muted, so a
    // later re-enable doesn't dump a backlog.
    expect(await db.metaDao.get('watch.last_eo_number'), '6');
  });

  test('nothing is detected when the Washington master switch is off',
      () async {
    await seedBaselines();
    await settings.setWashingtonNotifEnabled(false);

    final fetcher = FakePulseFetcher(orders: [order(6)]);
    expect(await service(fetcher: fetcher).detectNewItems(), isEmpty);
  });

  test('more than 3 new items are returned raw (collapse happens downstream)',
      () async {
    await seedBaselines();

    final fetcher = FakePulseFetcher(
      orders: [order(6), order(7), order(8), order(9)],
    );
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, hasLength(4));
  });

  test('a new law carries the CRS first sentence when available', () async {
    await seedBaselines();

    final fetcher = _SummaryFetcher(
      bills: [lawAction(actionDate: '2026-07-05', title: 'The New Law Act')],
      summaryText: 'This law does a thing. It also does another thing.',
    );
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, hasLength(1));
    expect(items.single.notificationTitle, 'New law');
    expect(
      items.single.notificationBody,
      'The New Law Act This law does a thing.',
    );
    expect(items.single.dedupeKey, 'law:HR 100');
  });

  test('a new bill action is detected as a bill with no CRS lookup', () async {
    await seedBaselines();

    final fetcher =
        FakePulseFetcher(bills: [billAction(actionDate: '2026-07-05')]);
    final items = await service(fetcher: fetcher).detectNewItems();

    expect(items, hasLength(1));
    expect(items.single.category, WatchCategory.bill);
    expect(items.single.title, 'A bill still moving');
    expect(items.single.personName, isNull);
    expect(items.single.dedupeKey, 'bill:S 200:2026-07-05');
  });

  test('rate limited to at most once per 2 hours', () async {
    var clock = DateTime(2026, 7, 12, 10);
    final fetcher = FakePulseFetcher(orders: [order(5)]);
    final svc = service(fetcher: fetcher, now: () => clock);

    await svc.detectNewItems();
    expect(fetcher.fetchCount, 1);

    // 1 hour later: still inside the 2-hour window, no new fetch.
    clock = clock.add(const Duration(hours: 1));
    await svc.detectNewItems();
    expect(fetcher.fetchCount, 1);

    // 3 hours after the first check: past the window, fetch again.
    clock = DateTime(2026, 7, 12, 13, 1);
    await svc.detectNewItems();
    expect(fetcher.fetchCount, 2);
  });

  test('offline (fetch throws) is a silent no-op', () async {
    final items = await service(fetcher: _ThrowingFetcher()).detectNewItems();
    expect(items, isEmpty);
    // No baseline should have been written since the fetch never succeeded.
    expect(await db.metaDao.get('watch.last_eo_number'), isNull);
  });
}

class _ThrowingFetcher implements PulseFetcher {
  @override
  Future<LivePulse> fetchPulse() => Future.error(Exception('offline'));

  @override
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async =>
      null;
}

class _SummaryFetcher extends FakePulseFetcher {
  _SummaryFetcher({required this.summaryText, super.bills});
  final String summaryText;

  @override
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async =>
      LiveBillSummary(
        text: summaryText,
        version: 'Introduced in House',
        date: '2026-07-05',
        truncated: false,
      );
}
