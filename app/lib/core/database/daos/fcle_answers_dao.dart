// lib/core/database/daos/fcle_answers_dao.dart
//
// FCLE answer history. Powers the per-domain readiness indicator (rolling
// accuracy over the most recent answers) and weak-area practice (which
// domain is weakest, which questions were missed).

import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'fcle_answers_dao.g.dart';

@DriftAccessor(tables: [FcleAnswers])
class FcleAnswersDao extends DatabaseAccessor<AppDatabase>
    with _$FcleAnswersDaoMixin {
  FcleAnswersDao(super.db);

  /// Readiness looks at this many most-recent answers per domain, matching
  /// the server's user_domain_readiness window.
  static const rollingWindow = 50;

  Future<void> log({
    required String questionId,
    required String domain,
    required bool correct,
    required bool inMock,
    required int answeredAt,
  }) =>
      into(fcleAnswers).insert(
        FcleAnswersCompanion.insert(
          questionId: questionId,
          domain: domain,
          correct: correct,
          inMock: Value(inMock),
          answeredAt: answeredAt,
        ),
      );

  /// Rolling accuracy for one domain over the last [rollingWindow] answers,
  /// or null when the domain has no history yet.
  Future<double?> rollingAccuracy(String domain) async {
    final recent = await (select(fcleAnswers)
          ..where((t) => t.domain.equals(domain))
          ..orderBy([(t) => OrderingTerm.desc(t.answeredAt)])
          ..limit(rollingWindow))
        .get();
    if (recent.isEmpty) return null;
    final correct = recent.where((r) => r.correct).length;
    return correct / recent.length;
  }

  /// Whether the user has ever answered a single FCLE question. The cheapest
  /// possible local "is this user FCLE-engaged?" signal for the notification
  /// orchestrator (gates the whole FCLE notification category, no network).
  Future<bool> hasAny() async {
    final c = countAll();
    final row = await (selectOnly(fcleAnswers)
          ..addColumns([c])
          ..limit(1))
        .getSingle();
    return (row.read(c) ?? 0) > 0;
  }

  /// How many answers a domain has ever received (readiness confidence).
  Future<int> answerCount(String domain) async {
    final c = countAll();
    final row = await (selectOnly(fcleAnswers)
          ..addColumns([c])
          ..where(fcleAnswers.domain.equals(domain)))
        .getSingle();
    return row.read(c) ?? 0;
  }

  /// The full local answer log, newest first. Objective-level readiness joins
  /// this against the in-memory question bank (questionId -> objective) rather
  /// than storing an objective column, so re-tagging content needs no schema
  /// migration. Local volume is small, so returning every row is fine.
  Future<List<({String questionId, bool correct, int answeredAt})>>
      answerLog() async {
    final rows = await (select(fcleAnswers)
          ..orderBy([(t) => OrderingTerm.desc(t.answeredAt)]))
        .get();
    return [
      for (final r in rows)
        (
          questionId: r.questionId,
          correct: r.correct,
          answeredAt: r.answeredAt,
        ),
    ];
  }

  /// Question ids answered incorrectly more recently than correctly:
  /// the weak-area practice pool, most recently missed first.
  Future<List<String>> missedQuestionIds(
    String domain, {
    int limit = 50,
  }) async {
    final rows = await (select(fcleAnswers)
          ..where((t) => t.domain.equals(domain))
          ..orderBy([(t) => OrderingTerm.desc(t.answeredAt)]))
        .get();
    final latest = <String, bool>{};
    for (final r in rows) {
      latest.putIfAbsent(r.questionId, () => r.correct);
    }
    return [
      for (final e in latest.entries)
        if (!e.value) e.key,
    ].take(limit).toList();
  }

  /// Ids the user has answered at least once, for prefer-unseen sampling.
  Future<Set<String>> answeredQuestionIds(String domain) async {
    final rows = await (selectOnly(fcleAnswers, distinct: true)
          ..addColumns([fcleAnswers.questionId])
          ..where(fcleAnswers.domain.equals(domain)))
        .get();
    return {
      for (final r in rows) r.read(fcleAnswers.questionId)!,
    };
  }
}
