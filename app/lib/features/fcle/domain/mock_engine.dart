// lib/features/fcle/domain/mock_engine.dart
//
// Assembles and grades a local Mock FCLE: 80 questions, 20 per domain in
// domain order, no repeats, 60% (48/80) to pass. Mirrors the real exam
// shape and the server's assemble_mock/finalize_mock semantics so a local
// mock and a server mock read the same. Pure logic, no I/O.

import 'dart:math';

import '../data/question_bank_loader.dart';
import 'fcle_question.dart';

class MockAssembly {
  const MockAssembly(this.questions);

  /// Grouped by domain in FCLE order: 20 American Democracy, then 20
  /// US Constitution, and so on.
  final List<FcleQuestion> questions;
}

class DomainScore {
  const DomainScore({required this.correct, required this.total});

  final int correct;
  final int total;
}

class MockResult {
  const MockResult({
    required this.score,
    required this.total,
    required this.passed,
    required this.perDomain,
    this.pendingSync = false,
  });

  final int score;
  final int total;
  final bool passed;
  final Map<FcleDomain, DomainScore> perDomain;

  /// True when a server-backed mock could not be finalized online; the
  /// score shown is the local tally and the server catches up via the
  /// outbox on the next connection.
  final bool pendingSync;

  /// Weakest domain by accuracy; break ties in exam order.
  FcleDomain get weakestDomain {
    var weakest = FcleDomain.values.first;
    var weakestAccuracy = double.infinity;
    for (final d in FcleDomain.values) {
      final s = perDomain[d];
      if (s == null || s.total == 0) continue;
      final acc = s.correct / s.total;
      if (acc < weakestAccuracy) {
        weakestAccuracy = acc;
        weakest = d;
      }
    }
    return weakest;
  }
}

class MockEngine {
  const MockEngine();

  static const passFraction = 0.6;

  /// Throws [StateError] if any domain is short; guard with
  /// [QuestionBank.canAssembleMock] first.
  MockAssembly assemble(QuestionBank bank, {Random? random}) {
    final r = random ?? Random();
    final questions = <FcleQuestion>[];
    for (final d in FcleDomain.values) {
      final pool = List.of(bank.byDomain[d] ?? const <FcleQuestion>[]);
      if (pool.length < QuestionBank.perDomainForMock) {
        throw StateError(
          'Domain ${d.code} has ${pool.length} questions; '
          'a mock needs ${QuestionBank.perDomainForMock}.',
        );
      }
      pool.shuffle(r);
      questions.addAll(pool.take(QuestionBank.perDomainForMock));
    }
    return MockAssembly(questions);
  }

  /// [answers] maps question id to the chosen option key; unanswered
  /// questions count as wrong (the real exam has no skips at scoring time).
  MockResult grade(MockAssembly assembly, Map<String, String> answers) {
    var score = 0;
    final perDomain = <FcleDomain, List<int>>{
      for (final d in FcleDomain.values) d: [0, 0],
    };
    for (final q in assembly.questions) {
      final counts = perDomain[q.domain]!;
      counts[1]++;
      if (q.isCorrect(answers[q.id] ?? '')) {
        counts[0]++;
        score++;
      }
    }
    final total = assembly.questions.length;
    return MockResult(
      score: score,
      total: total,
      passed: score >= (total * passFraction).ceil(),
      perDomain: {
        for (final e in perDomain.entries)
          e.key: DomainScore(correct: e.value[0], total: e.value[1]),
      },
    );
  }
}
