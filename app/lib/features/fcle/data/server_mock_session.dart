// lib/features/fcle/data/server_mock_session.dart
//
// A server-backed Mock FCLE. The server assembles the attempt (a
// mock_attempts row: the efficacy instrument), grades each answer, and
// finalizes the score. The UX never depends on the network though:
//
//   - Question content is reconstructed from the local bank when possible
//     (same YAML the server ingested), falling back to the stems/options
//     the assemble call returned.
//   - An answer that fails to reach the server goes to the outbox WITH the
//     attempt id (idempotent, delivered on reconnect) and is graded from
//     the local answer key for the on-screen tally.
//   - A finalize that fails is queued as a mock_finalize outbox row; the
//     result shown is the local tally, flagged pendingSync.

import '../../../core/database/daos/fcle_answers_dao.dart';
import '../../../core/sync/sync_engine.dart';
import '../domain/fcle_question.dart';
import '../domain/mock_engine.dart';
import '../domain/mock_session.dart';
import '../domain/server_ids.dart';
import 'question_bank_loader.dart';
import 'server_mock_api.dart';

class ServerMockSession implements MockSession {
  ServerMockSession._({
    required this.attemptId,
    required List<FcleQuestion> questions,
    required Map<String, String> serverIdByYamlId,
    required ServerMockApi api,
    required FcleAnswersDao dao,
    required SyncEngine sync,
    required void Function() onAnswerRecorded,
  })  : _questions = questions,
        _serverIdByYamlId = serverIdByYamlId,
        _api = api,
        _dao = dao,
        _sync = sync,
        _onAnswerRecorded = onAnswerRecorded;

  /// Assembles a server attempt. Throws on any network/RPC failure; the
  /// caller falls back to a LocalMockSession.
  static Future<ServerMockSession> start({
    required String kind,
    required QuestionBank bank,
    required ServerMockApi api,
    required FcleAnswersDao dao,
    required SyncEngine sync,
    required void Function() onAnswerRecorded,
  }) async {
    final assembly = await api.assembleMock(kind);

    // Server UUID -> bundled question (same YAML on both sides).
    final localByServerId = {
      for (final q in bank.all) serverUuidForQuestion(q.id): q,
    };

    final questions = <FcleQuestion>[];
    final serverIdByYamlId = <String, String>{};
    for (final item in assembly.items) {
      final local = localByServerId[item.serverId];
      if (local != null) {
        questions.add(local);
        serverIdByYamlId[local.id] = item.serverId;
      } else {
        // Server bank is ahead of this app build. Render from the server
        // payload; grading for this question relies on the server verdict
        // (empty local key counts as wrong if the network also drops).
        final domain = FcleDomain.fromCode(item.domainCode);
        if (domain == null) continue;
        final q = FcleQuestion(
          id: 'server:${item.serverId}',
          domain: domain,
          stem: item.stem,
          options: [
            for (final o in item.options)
              FcleOption(key: o['key'] as String, text: o['text'] as String),
          ],
          answerKey: '',
          explanation: '',
          citation: item.citation,
          difficulty: 3,
        );
        questions.add(q);
        serverIdByYamlId[q.id] = item.serverId;
      }
    }

    return ServerMockSession._(
      attemptId: assembly.attemptId,
      questions: questions,
      serverIdByYamlId: serverIdByYamlId,
      api: api,
      dao: dao,
      sync: sync,
      onAnswerRecorded: onAnswerRecorded,
    );
  }

  final String attemptId;
  final List<FcleQuestion> _questions;
  final Map<String, String> _serverIdByYamlId;
  final ServerMockApi _api;
  final FcleAnswersDao _dao;
  final SyncEngine _sync;
  final void Function() _onAnswerRecorded;

  final _tally = <FcleDomain, List<int>>{}; // domain -> [correct, total]

  @override
  List<FcleQuestion> get questions => _questions;

  @override
  Future<void> submit(FcleQuestion question, String chosenKey) async {
    final serverId = _serverIdByYamlId[question.id]!;
    bool correct;
    try {
      correct = await _api.submitAnswer(
        eventId: uuidV4(),
        serverQuestionId: serverId,
        chosenKey: chosenKey,
        attemptId: attemptId,
      );
    } catch (_) {
      // Offline mid-mock: queue for delivery (server re-grades there) and
      // grade from the bundled key for the on-screen tally.
      await _sync.enqueueAnswer(
        questionId: serverId,
        chosenKey: chosenKey,
        attemptId: attemptId,
      );
      correct = question.isCorrect(chosenKey);
    }

    final counts = _tally.putIfAbsent(question.domain, () => [0, 0]);
    counts[1]++;
    if (correct) counts[0]++;

    // Local history feeds readiness regardless of transport.
    if (!question.id.startsWith('server:')) {
      await _dao.log(
        questionId: question.id,
        domain: question.domain.code,
        correct: correct,
        inMock: true,
        answeredAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    _onAnswerRecorded();
  }

  @override
  bool get isServerBacked => true;

  @override
  Future<MockResult> finish() async {
    // Any answer still queued from a mid-exam blip must reach the server
    // BEFORE finalize, or the attempt is scored short and the late answer
    // dead-letters against the completed attempt. Drain first; if anything
    // for this attempt is still stuck, finalize through the outbox too
    // (FIFO lands the answers ahead of it) and show the local tally.
    await _sync.flush();
    if (await _sync.hasPendingForAttempt(attemptId)) {
      return _finishOffline();
    }
    try {
      final outcome = await _api.finalize(attemptId);
      return MockResult(
        score: outcome.score,
        total: _questions.length,
        passed: outcome.passed,
        perDomain: {
          for (final d in FcleDomain.values)
            d: DomainScore(
              correct: outcome.perDomain[d.code]?['correct'] ?? 0,
              total: outcome.perDomain[d.code]?['total'] ?? 0,
            ),
        },
      );
    } catch (_) {
      return _finishOffline();
    }
  }

  /// Finalize later, show the local tally now.
  Future<MockResult> _finishOffline() async {
    await _sync.enqueueMockFinalize(attemptId: attemptId);
    var score = 0;
    for (final counts in _tally.values) {
      score += counts[0];
    }
    final total = _questions.length;
    return MockResult(
      score: score,
      total: total,
      passed: score >= (total * MockEngine.passFraction).ceil(),
      perDomain: {
        for (final d in FcleDomain.values)
          d: DomainScore(
            correct: _tally[d]?[0] ?? 0,
            total: _tally[d]?[1] ?? 0,
          ),
      },
      pendingSync: true,
    );
  }
}
