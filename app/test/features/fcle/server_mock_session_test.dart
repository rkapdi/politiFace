import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/core/sync/sync_engine.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/data/server_mock_api.dart';
import 'package:politiface/features/fcle/data/server_mock_session.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/server_ids.dart';

class FakeMockApi implements ServerMockApi {
  FakeMockApi({required this.assembly});

  ServerMockAssembly assembly;
  bool submitFails = false;
  bool finalizeFails = false;
  final submitted = <String>[]; // serverQuestionIds
  int finalizeCalls = 0;
  ServerMockOutcome? outcome;

  @override
  Future<ServerMockAssembly> assembleMock(String kind) async => assembly;

  @override
  Future<bool> submitAnswer({
    required String eventId,
    required String serverQuestionId,
    required String chosenKey,
    required String attemptId,
  }) async {
    if (submitFails) throw Exception('network down');
    submitted.add(serverQuestionId);
    return chosenKey == 'b'; // server truth: b is always right
  }

  @override
  Future<ServerMockOutcome> finalize(String attemptId) async {
    finalizeCalls++;
    if (finalizeFails) throw Exception('network down');
    return outcome!;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  FcleQuestion q(String id, FcleDomain d) => FcleQuestion(
        id: id,
        domain: d,
        stem: 'Stem $id?',
        options: const [
          FcleOption(key: 'a', text: 'A'),
          FcleOption(key: 'b', text: 'B'),
        ],
        answerKey: 'b',
        explanation: 'x',
        citation: 'https://example.gov',
        difficulty: 3,
      );

  QuestionBank bank() => QuestionBank({
        FcleDomain.americanDemocracy: [q('ad-1', FcleDomain.americanDemocracy)],
        FcleDomain.usConstitution: [q('uc-1', FcleDomain.usConstitution)],
      });

  ServerMockAssembly assemblyFor(QuestionBank b) => ServerMockAssembly(
        attemptId: 'attempt-1',
        items: [
          for (final question in b.all)
            ServerMockItem(
              serverId: serverUuidForQuestion(question.id),
              domainCode: question.domain.code,
              stem: question.stem,
              options: const [
                {'key': 'a', 'text': 'A'},
                {'key': 'b', 'text': 'B'},
              ],
              citation: question.citation,
            ),
        ],
      );

  test('online: answers go to the RPC, finalize returns the server verdict',
      () async {
    final b = bank();
    final api = FakeMockApi(assembly: assemblyFor(b))
      ..outcome = const ServerMockOutcome(
        score: 1,
        passed: false,
        perDomain: {
          'american_democracy': {'correct': 1, 'total': 1},
          'us_constitution': {'correct': 0, 'total': 1},
        },
      );
    final engine = SyncEngine(db, null); // engine unused online

    final session = await ServerMockSession.start(
      kind: 'baseline',
      bank: b,
      api: api,
      dao: db.fcleAnswersDao,
      sync: engine,
      onAnswerRecorded: () {},
    );

    // Server items map back onto the bundled questions.
    expect(session.questions.map((x) => x.id).toList(), ['ad-1', 'uc-1']);
    expect(session.attemptId, 'attempt-1');

    await session.submit(session.questions[0], 'b'); // right
    await session.submit(session.questions[1], 'a'); // wrong
    expect(api.submitted.length, 2);

    final result = await session.finish();
    expect(result.score, 1);
    expect(result.passed, isFalse);
    expect(result.pendingSync, isFalse);
    expect(result.perDomain[FcleDomain.americanDemocracy]!.correct, 1);
    expect(result.perDomain[FcleDomain.usConstitution]!.correct, 0);

    // Local history recorded with the server verdicts.
    expect(
      await db.fcleAnswersDao.rollingAccuracy('american_democracy'),
      1.0,
    );
    expect(await db.fcleAnswersDao.rollingAccuracy('us_constitution'), 0.0);
    // Nothing queued: everything delivered directly.
    expect(await db.outboxDao.pendingCount(), 0);
  });

  test(
      'offline degradation: answers queue with the attempt id, finalize '
      'queues and the local tally is flagged pendingSync', () async {
    final b = bank();
    final api = FakeMockApi(assembly: assemblyFor(b))
      ..submitFails = true
      ..finalizeFails = true;
    final transport = _RecordingSignedInTransport();
    final engine = SyncEngine(db, transport);

    final session = await ServerMockSession.start(
      kind: 'baseline',
      bank: b,
      api: api,
      dao: db.fcleAnswersDao,
      sync: engine,
      onAnswerRecorded: () {},
    );

    await session.submit(session.questions[0], 'b'); // right (local key)
    await session.submit(session.questions[1], 'a'); // wrong (local key)
    final result = await session.finish();

    expect(result.pendingSync, isTrue);
    expect(result.score, 1);
    expect(result.total, 2);

    // The outbox carries both answers (with the attempt id) and the
    // deferred finalize, in FIFO order.
    await engine.flush();
    expect(
      transport.delivered.map((e) => e.type).toList(),
      ['answer', 'answer', 'mock_finalize'],
    );
    expect(transport.delivered[0].attemptId, 'attempt-1');
    expect(transport.delivered[2].attemptId, 'attempt-1');
  });

  test('server-only questions render from the payload and skip local history',
      () async {
    final b = bank();
    final assembly = ServerMockAssembly(
      attemptId: 'attempt-2',
      items: [
        ...assemblyFor(b).items,
        const ServerMockItem(
          serverId: '99999999-9999-5999-8999-999999999999',
          domainCode: 'founding_documents',
          stem: 'Newer than this app build?',
          options: [
            {'key': 'a', 'text': 'Yes'},
            {'key': 'b', 'text': 'No'},
          ],
          citation: 'https://example.gov',
        ),
      ],
    );
    final api = FakeMockApi(assembly: assembly)
      ..outcome = const ServerMockOutcome(
        score: 3,
        passed: true,
        perDomain: {},
      );
    final session = await ServerMockSession.start(
      kind: 'practice',
      bank: b,
      api: api,
      dao: db.fcleAnswersDao,
      sync: SyncEngine(db, null),
      onAnswerRecorded: () {},
    );

    expect(session.questions.length, 3);
    final serverOnly = session.questions.last;
    expect(serverOnly.id, startsWith('server:'));
    expect(serverOnly.stem, 'Newer than this app build?');

    await session.submit(serverOnly, 'b');
    // Graded by the server, but no local-history row for an unknown id.
    expect(
      await db.fcleAnswersDao.rollingAccuracy('founding_documents'),
      isNull,
    );
  });
}

class _RecordingSignedInTransport implements SyncTransport {
  final delivered = <OutboxEvent>[];

  @override
  bool get isSignedIn => true;

  Future<void> _send(OutboxEvent e) async => delivered.add(e);

  @override
  Future<void> sendAnswer(OutboxEvent e) => _send(e);
  @override
  Future<void> sendReview(OutboxEvent e) => _send(e);
  @override
  Future<void> sendSessionEvent(OutboxEvent e) => _send(e);
  @override
  Future<void> sendMockFinalize(OutboxEvent e) => _send(e);
  @override
  Future<void> upsertCardState(OutboxEvent e) => _send(e);
  @override
  Future<void> upsertAppState(OutboxEvent e) => _send(e);
}
