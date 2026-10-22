import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/notifications/data/notification_generators.dart';
import 'package:politiface/features/notifications/data/notification_orchestrator.dart';
import 'package:politiface/features/notifications/data/notification_sender.dart';
import 'package:politiface/features/notifications/data/washington_watch_service.dart';
import 'package:politiface/features/pulse/data/pulse_live_service.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

class _Delivery {
  _Delivery(this.id, this.title, this.body, {this.scheduled = false});
  final int id;
  final String title;
  final String body;
  final bool scheduled;
}

class FakeSender implements NotificationSender {
  bool authorized = true;
  final delivered = <_Delivery>[];

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async =>
      delivered.add(_Delivery(id, title, body));

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async =>
      delivered.add(_Delivery(id, title, body, scheduled: true));

  @override
  Future<void> cancel(int id) async {}
}

class FakeFetcher implements PulseFetcher {
  FakeFetcher({this.orders = const []});
  List<LiveOrder> orders;

  @override
  Future<LivePulse> fetchPulse() async =>
      LivePulse(orders: orders, bills: const []);

  @override
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async =>
      null;
}

LiveOrder eoOrder(int n, {required String president, String title = 'EO'}) =>
    LiveOrder(
      number: n,
      title: title,
      president: president,
      signingDate: '2026-07-01',
      url: 'https://federalregister.gov/d/$n',
    );

void main() {
  late AppDatabase db;
  late SettingsService settings;
  late FakeSender sender;
  final now = DateTime(2026, 7, 12, 15); // outside quiet hours
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
    sender = FakeSender();
  });

  tearDown(() => db.close());

  Future<void> seedBaselines() async {
    await db.metaDao.set('watch.last_eo_number', '5');
    await db.metaDao.set('watch.last_law', '2026-01-01');
    await db.metaDao.set('watch.last_bill_action_date', '2026-01-01');
  }

  Future<void> seedDueCards(int n) async {
    for (var i = 0; i < n; i++) {
      await db.into(db.cardMemoryStates).insert(
            CardMemoryStatesCompanion.insert(
              cardId: 'due-$i',
              isNew: const Value(false),
              nextReviewAt: Value(nowSec + 3600),
            ),
          );
    }
  }

  Future<void> seedFace({
    required String bioguide,
    required String name,
    required bool reviewed,
    String? state,
  }) async {
    await db.into(db.localCards).insert(
          LocalCardsCompanion.insert(
            id: 'card-$bioguide',
            deckId: 'deck-1',
            externalId: bioguide,
            politicianName: name,
            title: 'Senator',
            sourceUrl: 'https://example.gov',
            updatedAt: 0,
          ),
        );
    await db.into(db.people).insert(
          PeopleCompanion.insert(
            id: bioguide,
            name: name,
            currentRole: 'Senator',
            state: Value(state),
          ),
        );
    await db.into(db.cardMemoryStates).insert(
          CardMemoryStatesCompanion.insert(
            cardId: 'card-$bioguide',
            isNew: Value(!reviewed),
            nextReviewAt: Value(nowSec + 999999999),
          ),
        );
  }

  NotificationOrchestrator orchestrator({PulseFetcher? fetcher}) =>
      NotificationOrchestrator(
        db: db,
        washington: WashingtonWatchService(
          db: db,
          fetcher: fetcher ?? FakeFetcher(),
          sender: sender,
          settings: settings,
          now: () => now,
        ),
        sender: sender,
        settings: settings,
        now: () => now,
      );

  test('records fired keys and drops the repeat within cooldown', () async {
    await seedDueCards(3);

    await orchestrator().run();
    expect(sender.delivered, hasLength(1));
    expect(sender.delivered.single.id, NotifSlots.memoryRescue);
    expect(await db.metaDao.get('notif.log'), contains('rescue:2026-07-12'));

    // Second sweep the same day: the dedupe key is in the log, so the brain
    // suppresses it and nothing new is delivered.
    await orchestrator().run();
    expect(sender.delivered, hasLength(1));
  });

  test('respects the Washington master switch as a pre-filter', () async {
    await seedBaselines();
    await settings.setWashingtonNotifEnabled(false);

    await orchestrator(
      fetcher: FakeFetcher(orders: [eoOrder(6, president: 'A President')]),
    ).run();

    expect(sender.delivered, isEmpty);
  });

  test('personalizes a Washington item for a studied face', () async {
    await seedBaselines();
    await seedFace(bioguide: 'C001', name: 'Susan Collins', reviewed: true);

    await orchestrator(
      fetcher: FakeFetcher(orders: [eoOrder(6, president: 'Susan Collins')]),
    ).run();

    expect(sender.delivered, hasLength(1));
    expect(sender.delivered.single.body, contains('Susan Collins'));
    expect(sender.delivered.single.body, contains('from your deck'));
  });

  test('personalizes a Washington item for a home-state delegation match',
      () async {
    await seedBaselines();
    await db.metaDao.set('atlas.home_state', 'ME');
    // Not reviewed, but in the user's home state.
    await seedFace(
      bioguide: 'C001',
      name: 'Susan Collins',
      state: 'ME',
      reviewed: false,
    );

    await orchestrator(
      fetcher: FakeFetcher(orders: [eoOrder(6, president: 'Susan Collins')]),
    ).run();

    expect(sender.delivered, hasLength(1));
    expect(sender.delivered.single.body, contains('ME delegation'));
  });

  test('stays general and names no one when there is no real connection',
      () async {
    await seedBaselines();
    await db.metaDao.set('atlas.home_state', 'FL');
    // A card exists but it is neither reviewed nor in the home state.
    await seedFace(
      bioguide: 'C001',
      name: 'Susan Collins',
      state: 'ME',
      reviewed: false,
    );

    await orchestrator(
      fetcher: FakeFetcher(
        orders: [eoOrder(6, president: 'Susan Collins', title: 'Some Order')],
      ),
    ).run();

    expect(sender.delivered, hasLength(1));
    expect(sender.delivered.single.body, 'Some Order');
    expect(sender.delivered.single.body, isNot(contains('Susan Collins')));
  });
}
