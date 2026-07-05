// lib/features/fcle/domain/mock_session.dart
//
// One in-progress Mock FCLE, behind an interface so the exam screen does
// not care where truth lives:
//
//   LocalMockSession   - bundled bank, local grading. Always available.
//   ServerMockSession  - server-assembled attempt (mock_attempts row, the
//                        efficacy instrument); see server_mock_session.dart.
//
// The screen contract: read [questions], call [submit] once per question in
// order shown, call [finish] exactly once at the end.

import '../../../core/database/daos/fcle_answers_dao.dart';
import 'fcle_question.dart';
import 'mock_engine.dart';

abstract class MockSession {
  List<FcleQuestion> get questions;

  Future<void> submit(FcleQuestion question, String chosenKey);

  Future<MockResult> finish();
}

class LocalMockSession implements MockSession {
  LocalMockSession({
    required MockAssembly assembly,
    required FcleAnswersDao dao,
    required Future<void> Function({
      required String serverQuestionId,
      required String chosenKey,
    }) enqueueAnswer,
    required void Function() onAnswerRecorded,
    required String Function(String yamlId) serverIdOf,
  })  : _assembly = assembly,
        _dao = dao,
        _enqueueAnswer = enqueueAnswer,
        _onAnswerRecorded = onAnswerRecorded,
        _serverIdOf = serverIdOf;

  final MockAssembly _assembly;
  final FcleAnswersDao _dao;
  final Future<void> Function({
    required String serverQuestionId,
    required String chosenKey,
  }) _enqueueAnswer;
  final void Function() _onAnswerRecorded;
  final String Function(String yamlId) _serverIdOf;

  final _answers = <String, String>{};
  static const _engine = MockEngine();

  @override
  List<FcleQuestion> get questions => _assembly.questions;

  @override
  Future<void> submit(FcleQuestion question, String chosenKey) async {
    _answers[question.id] = chosenKey;
    await _dao.log(
      questionId: question.id,
      domain: question.domain.code,
      correct: question.isCorrect(chosenKey),
      inMock: true,
      answeredAt: DateTime.now().millisecondsSinceEpoch,
    );
    // Plain practice answer server-side (no attempt): still feeds domain
    // readiness and engagement even though the mock itself is local.
    await _enqueueAnswer(
      serverQuestionId: _serverIdOf(question.id),
      chosenKey: chosenKey,
    );
    _onAnswerRecorded();
  }

  @override
  Future<MockResult> finish() async => _engine.grade(_assembly, _answers);
}
