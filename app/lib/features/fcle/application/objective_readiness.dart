// lib/features/fcle/application/objective_readiness.dart
//
// Objective-level FCLE readiness. Joins the local answer log to the in-memory
// question bank (questionId -> objective) to compute per-objective rolling
// accuracy, then rolls those up into a single qualitative verdict for the
// blueprint screen. No predicted-score number is ever produced: per the
// positioning rule in CLAUDE.md, mocks are practice, not predictors.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/objectives_loader.dart';
import '../domain/fcle_question.dart';
import '../domain/objective.dart';
import 'fcle_providers.dart';

/// The 32-objective FCLE taxonomy, loaded from the bundled YAML.
final objectivesProvider = FutureProvider<List<Objective>>(
  (ref) => ObjectivesLoader().load(),
);

/// Per-objective readiness bucket.
enum ReadinessState { unseen, practicing, needsWork, onTrack, solid }

/// Accuracy over an objective's most recent answers is bucketed with these
/// thresholds. They sit DELIBERATELY ABOVE the 60% FCLE pass line: practice
/// on a small local bank over-predicts real-exam performance, so we hold a
/// higher bar before calling an objective "solid" than the exam does before
/// calling it a pass. Tunable pending efficacy calibration (once we can
/// compare in-app readiness against real first-attempt pass rates).
const kNeedsWorkBelow = 0.70; // count>=4 and accuracy < 0.70 -> needsWork
const kSolidAtOrAbove = 0.85; // accuracy >= 0.85 -> solid

/// How many recent answers per objective feed the rolling accuracy, matching
/// the per-domain readiness window.
const kObjectiveRollingWindow = 50;

/// The minimum attempts before accuracy is trusted enough to grade.
const kConfidentCount = 4;

ReadinessState readinessStateFor(
    {required double? accuracy, required int count,}) {
  if (count == 0) return ReadinessState.unseen;
  if (count < kConfidentCount) return ReadinessState.practicing;
  // count >= 4 from here: accuracy is non-null (there are answers).
  final a = accuracy ?? 0;
  if (a < kNeedsWorkBelow) return ReadinessState.needsWork;
  if (a < kSolidAtOrAbove) return ReadinessState.onTrack;
  return ReadinessState.solid;
}

class ObjectiveReadiness {
  const ObjectiveReadiness({
    required this.code,
    required this.domain,
    required this.description,
    required this.accuracy,
    required this.count,
    required this.state,
  });

  final String code;
  final FcleDomain domain;
  final String description;

  /// Rolling accuracy over the most recent answers; null when [count] == 0.
  final double? accuracy;

  /// Total attempts recorded for this objective.
  final int count;
  final ReadinessState state;
}

/// Readiness for all 32 objectives (unseen ones included, accuracy null),
/// keyed by objective code.
final objectiveReadinessProvider =
    FutureProvider<Map<String, ObjectiveReadiness>>((ref) async {
  ref.watch(fcleTickProvider);
  final objectives = await ref.watch(objectivesProvider.future);
  final bank = await ref.watch(questionBankProvider.future);
  final dao = ref.watch(databaseProvider).fcleAnswersDao;
  final log = await dao.answerLog(); // newest first

  // questionId -> objective code, from the loaded bank.
  final objectiveOf = <String, String>{
    for (final q in bank.all)
      if (q.objective != null) q.id: q.objective!,
  };

  // Bucket answers by objective, preserving newest-first order.
  final byObjective = <String, List<bool>>{};
  for (final row in log) {
    final code = objectiveOf[row.questionId];
    if (code == null) continue;
    (byObjective[code] ??= <bool>[]).add(row.correct);
  }

  final result = <String, ObjectiveReadiness>{};
  for (final o in objectives) {
    final answers = byObjective[o.code] ?? const <bool>[];
    final count = answers.length;
    double? accuracy;
    if (count > 0) {
      final window = answers.take(kObjectiveRollingWindow).toList();
      final correct = window.where((c) => c).length;
      accuracy = correct / window.length;
    }
    result[o.code] = ObjectiveReadiness(
      code: o.code,
      domain: o.domain,
      description: o.description,
      accuracy: accuracy,
      count: count,
      state: readinessStateFor(accuracy: accuracy, count: count),
    );
  }
  return result;
});

/// Where the blueprint points the student next: either the single weakest
/// graded objective, or (before enough data) the domain with the most
/// untouched objectives.
class FocusNext {
  const FocusNext({required this.domain, this.objective});

  final FcleDomain domain;

  /// Null => focus the whole domain (nothing graded yet); non-null => this
  /// specific weakest objective.
  final ObjectiveReadiness? objective;

  bool get isObjective => objective != null;
}

/// Qualitative readiness ladder. Deliberately NOT a percentage or predicted
/// score — coverage and per-domain solidity only.
enum ExamOverallState {
  justStarting,
  buildingCoverage,
  mostAreasCovered,
  strongAcrossTheBoard,
}

class ExamReadiness {
  const ExamReadiness({
    required this.covered,
    required this.total,
    required this.solid,
    required this.needsWork,
    required this.unseen,
    required this.overallState,
    required this.focusNext,
  });

  /// Objectives with at least one recorded attempt.
  final int covered;
  final int total; // always 32
  final int solid;
  final int needsWork;
  final int unseen;
  final ExamOverallState overallState;

  /// Null only if the taxonomy failed to load (no objectives at all).
  final FocusNext? focusNext;
}

/// Pure aggregation of per-objective readiness into the single verdict.
/// Extracted so it can be unit-tested without Riverpod or assets.
ExamReadiness aggregateExamReadiness(Map<String, ObjectiveReadiness> byCode) {
  final all = byCode.values.toList();
  final total = all.length;
  final covered = all.where((o) => o.count > 0).length;
  final solid = all.where((o) => o.state == ReadinessState.solid).length;
  final needsWork =
      all.where((o) => o.state == ReadinessState.needsWork).length;
  final unseen = all.where((o) => o.state == ReadinessState.unseen).length;

  // Per-domain solidity: does every domain have at least one solid objective?
  final domainsWithObjectives = all.map((o) => o.domain).toSet();
  final domainsWithSolid = all
      .where((o) => o.state == ReadinessState.solid)
      .map((o) => o.domain)
      .toSet();
  final everyDomainHasSolid = domainsWithObjectives.isNotEmpty &&
      domainsWithSolid.length == domainsWithObjectives.length;

  final ExamOverallState overall;
  if (covered == 0) {
    overall = ExamOverallState.justStarting;
  } else if (covered < total / 2) {
    overall = ExamOverallState.buildingCoverage;
  } else if (covered >= (total * 3) ~/ 4 && everyDomainHasSolid) {
    overall = ExamOverallState.strongAcrossTheBoard;
  } else {
    overall = ExamOverallState.mostAreasCovered;
  }

  return ExamReadiness(
    covered: covered,
    total: total,
    solid: solid,
    needsWork: needsWork,
    unseen: unseen,
    overallState: overall,
    focusNext: _focusNext(all),
  );
}

FocusNext? _focusNext(List<ObjectiveReadiness> all) {
  if (all.isEmpty) return null;

  // The weakest graded objective (count >= confident threshold), lowest
  // accuracy first; ties broken by code for determinism.
  final graded = [
    for (final o in all)
      if (o.count >= kConfidentCount && o.accuracy != null) o,
  ]..sort((a, b) {
      final byAcc = a.accuracy!.compareTo(b.accuracy!);
      return byAcc != 0 ? byAcc : a.code.compareTo(b.code);
    });
  if (graded.isNotEmpty) {
    final weakest = graded.first;
    return FocusNext(domain: weakest.domain, objective: weakest);
  }

  // Otherwise steer toward the domain with the most untouched objectives.
  final unseenByDomain = <FcleDomain, int>{};
  for (final o in all) {
    if (o.state == ReadinessState.unseen) {
      unseenByDomain.update(o.domain, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  if (unseenByDomain.isEmpty) return null;
  FcleDomain? bestDomain;
  var bestCount = 0;
  // Iterate in enum order so ties resolve to the earliest domain.
  for (final d in FcleDomain.values) {
    final n = unseenByDomain[d] ?? 0;
    if (n > bestCount) {
      bestCount = n;
      bestDomain = d;
    }
  }
  if (bestDomain == null) return null;
  return FocusNext(domain: bestDomain);
}

final examReadinessProvider = FutureProvider<ExamReadiness>((ref) async {
  final byCode = await ref.watch(objectiveReadinessProvider.future);
  return aggregateExamReadiness(byCode);
});
