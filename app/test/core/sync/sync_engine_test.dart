import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/daos/outbox_dao.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/core/sync/sync_engine.dart';

/// In-memory transport: records deliveries, fails on demand.
class FakeTransport implements SyncTransport {
  FakeTransport({this.signedIn = true});

  bool signedIn;
  final deliveredEvents = <OutboxEvent>[];
  List<String> get delivered =>
      [for (final e in deliveredEvents) e.eventId];

  /// eventId -> error to throw. PermanentSyncError = server rejection;
  /// anything else = transient network failure.
  final failWith = <String, Exception>{};

  @override
  bool get isSignedIn => signedIn;

  Future<void> _send(OutboxEvent e) async {
    final err = failWith[e.eventId];
    if (err != null) throw err;
    deliveredEvents.add(e);
  }

  @override
  Future<void> sendAnswer(OutboxEvent e) => _send(e);
  @override
  Future<void> sendReview(OutboxEvent e) => _send(e);
  @override
  Future<void> sendSessionEvent(OutboxEvent e) => _send(e);
  @override
  Future<void> sendMockFinalize(OutboxEvent e) => _send(e);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('uuidV4 has version and variant bits', () {
    final id = uuidV4();
    expect(
      id,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );
    expect(uuidV4(), isNot(id));
  });

  test('enqueue no-ops when signed out: nothing leaves the device', () async {
    final engine = SyncEngine(db, FakeTransport(signedIn: false));
    expect(engine.isActive, isFalse);
    await engine.enqueueSessionStart();
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('enqueue no-ops with no transport (unconfigured build)', () async {
    final engine = SyncEngine(db, null);
    expect(engine.isActive, isFalse);
    await engine.enqueueSessionStart();
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('signed in: enqueue + flush delivers and empties the outbox', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await engine.enqueueSessionStart();
    await engine.enqueueSessionEnd();
    await engine.flush();
    expect(transport.delivered.length, 2);
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('delivers oldest first', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'later',
      type: 'session_start',
      clientTs: 2000,
      createdAt: 2000,
    ),);
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'earlier',
      type: 'session_start',
      clientTs: 1000,
      createdAt: 1000,
    ),);
    await engine.flush();
    expect(transport.delivered, ['earlier', 'later']);
  });

  test('transient failure keeps the event and stops the pass', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    // Direct DAO insert: no auto-flush, so the failure is armed first.
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'e1',
      type: 'answer',
      clientTs: 1,
      createdAt: 1,
    ),);
    transport.failWith['e1'] = Exception('socket closed');

    await engine.flush();
    expect(transport.delivered, isEmpty);
    expect(await db.outboxDao.pendingCount(), 1);

    // Network back: the retry delivers the same event (same id).
    transport.failWith.clear();
    await engine.flush();
    expect(transport.delivered, ['e1']);
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('permanent failure does not dam the queue behind it', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'poison',
      type: 'session_start',
      clientTs: 1,
      createdAt: 1,
    ),);
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'good',
      type: 'session_start',
      clientTs: 2,
      createdAt: 2,
    ),);
    transport.failWith['poison'] = PermanentSyncError('42501: rejected');

    await engine.flush();
    expect(transport.delivered, ['good']);
    expect(await db.outboxDao.pendingCount(), 1); // poison still pending
  });

  test('poison event dead-letters after max tries', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await db.outboxDao.enqueue(OutboxEventsCompanion.insert(
      eventId: 'poison',
      type: 'session_start',
      clientTs: 1,
      createdAt: 1,
    ),);
    transport.failWith['poison'] = PermanentSyncError('42501: rejected');

    for (var i = 0; i < OutboxDao.maxTries; i++) {
      await engine.flush();
    }
    expect(await db.outboxDao.pendingCount(), 0);
    expect(await db.outboxDao.deadLetterCount(), 1);

    // Row is kept for diagnosis, with the error recorded.
    final rows = await db.select(db.outboxEvents).get();
    expect(rows.single.lastError, contains('42501'));
    expect(rows.single.tries, OutboxDao.maxTries);
  });

  test('mock_finalize flushes after its attempt answers (FIFO)', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await engine.enqueueAnswer(
      questionId: 'q-uuid',
      chosenKey: 'b',
      attemptId: 'attempt-1',
    );
    await engine.enqueueMockFinalize(attemptId: 'attempt-1');
    await engine.flush();

    expect(transport.deliveredEvents.length, 2);
    expect(transport.deliveredEvents.first.type, 'answer');
    expect(transport.deliveredEvents.last.type, 'mock_finalize');
    expect(transport.deliveredEvents.last.attemptId, 'attempt-1');
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test('answer and review events carry their payload fields', () async {
    final transport = FakeTransport();
    final engine = SyncEngine(db, transport);
    await engine.enqueueAnswer(
      questionId: 'q-uuid',
      chosenKey: 'c',
      attemptId: 'a-uuid',
    );
    await engine.enqueueReview(questionId: 'q2-uuid', grade: 'good');
    // Drain what the fire-and-forget flush inside enqueue may have left.
    await engine.flush();

    expect(transport.deliveredEvents.length, 2);
    final answer =
        transport.deliveredEvents.singleWhere((e) => e.type == 'answer');
    expect(answer.questionId, 'q-uuid');
    expect(answer.chosenKey, 'c');
    expect(answer.attemptId, 'a-uuid');
    final review =
        transport.deliveredEvents.singleWhere((e) => e.type == 'review');
    expect(review.questionId, 'q2-uuid');
    expect(review.grade, 'good');
  });
}
