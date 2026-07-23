// lib/features/fcle/application/fcle_providers.dart
//
// FCLE prep state: bundled question bank, per-domain readiness (rolling
// accuracy from the local answer log), practice-set assembly, and the
// answer recorder that writes locally and mirrors to the server outbox.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/daos/fcle_answers_dao.dart';
import '../../../core/database/drift/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/question_bank_loader.dart';
import '../domain/fcle_question.dart';
import '../domain/server_ids.dart';

final questionBankProvider = FutureProvider<QuestionBank>(
  (ref) => QuestionBankLoader().load(),
);

/// Bumped after every recorded answer so readiness views refetch.
final fcleTickProvider = StateProvider<int>((ref) => 0);

class DomainReadiness {
  const DomainReadiness({
    required this.domain,
    required this.accuracy,
    required this.answerCount,
  });

  final FcleDomain domain;

  /// Rolling accuracy over the last 50 answers; null = no history yet.
  final double? accuracy;
  final int answerCount;

  /// Readiness v1 = rolling accuracy (matches the server read model).
  double? get readiness => accuracy;
}

final readinessProvider = FutureProvider<Map<FcleDomain, DomainReadiness>>(
  (ref) async {
    ref.watch(fcleTickProvider);
    final dao = ref.watch(databaseProvider).fcleAnswersDao;
    return {
      for (final d in FcleDomain.values)
        d: DomainReadiness(
          domain: d,
          accuracy: await dao.rollingAccuracy(d.code),
          answerCount: await dao.answerCount(d.code),
        ),
    };
  },
);

/// The weakest domain with history, or null before any answers exist.
final weakestDomainProvider = FutureProvider<FcleDomain?>((ref) async {
  final readiness = await ref.watch(readinessProvider.future);
  FcleDomain? weakest;
  var weakestAccuracy = double.infinity;
  for (final r in readiness.values) {
    final a = r.accuracy;
    if (a != null && a < weakestAccuracy) {
      weakestAccuracy = a;
      weakest = r.domain;
    }
  }
  return weakest;
});

final fcleAnswerRecorderProvider = Provider<FcleAnswerRecorder>(
  (ref) => FcleAnswerRecorder(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
    () => ref.read(fcleTickProvider.notifier).state++,
  ),
);

class FcleAnswerRecorder {
  FcleAnswerRecorder(this._db, this._sync, this._tick);

  final AppDatabase _db;
  final SyncEngine _sync;
  final void Function() _tick;

  /// Local log always; server outbox only when configured + signed in
  /// (SyncEngine no-ops otherwise). Ids cross the wire as the same
  /// deterministic UUIDs the content ingest wrote.
  Future<void> record({
    required FcleQuestion question,
    required String chosenKey,
    required bool inMock,
  }) async {
    await _db.fcleAnswersDao.log(
      questionId: question.id,
      domain: question.domain.code,
      correct: question.isCorrect(chosenKey),
      inMock: inMock,
      answeredAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _sync.enqueueAnswer(
      questionId: serverUuidForQuestion(question.id),
      chosenKey: chosenKey,
    );
    _tick();
  }
}

/// Builds a practice set for one domain: recently missed questions first,
/// then never-seen ones, then anything else, shuffled within each tier.
///
/// When [objective] is given, the domain pool is narrowed to questions tagged
/// with that objective code, so the blueprint's per-objective taps and the
/// focus-next CTA practice exactly that competency.
Future<List<FcleQuestion>> buildPracticeSet({
  required QuestionBank bank,
  required FcleAnswersDao dao,
  required FcleDomain domain,
  String? objective,
  int count = 10,
  Random? random,
}) async {
  final r = random ?? Random();
  final domainPool = bank.byDomain[domain] ?? const <FcleQuestion>[];
  final pool = objective == null
      ? domainPool
      : [
          for (final q in domainPool)
            if (q.objective == objective) q,
        ];
  if (pool.isEmpty) return const [];

  final byId = {for (final q in pool) q.id: q};
  final missedIds = await dao.missedQuestionIds(domain.code);
  final answered = await dao.answeredQuestionIds(domain.code);

  final missed = [
    for (final id in missedIds)
      if (byId.containsKey(id)) byId[id]!,
  ]..shuffle(r);
  final unseen = [
    for (final q in pool)
      if (!answered.contains(q.id)) q,
  ]..shuffle(r);
  final rest = [
    for (final q in pool)
      if (answered.contains(q.id) && !missedIds.contains(q.id)) q,
  ]..shuffle(r);

  final seen = <String>{};
  final result = <FcleQuestion>[];
  for (final q in [...missed, ...unseen, ...rest]) {
    if (seen.add(q.id)) result.add(q);
    if (result.length == count) break;
  }
  return result;
}
