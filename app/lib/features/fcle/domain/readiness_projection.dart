// lib/features/fcle/domain/readiness_projection.dart
//
// The projected-score math behind the Home readiness hero and the
// diagnostic result screen. Pure functions, no IO.
//
// Honesty rules (beta feedback 2026-08-23: the projection must track real
// exam preparedness, not whatever was played recently):
//   * Evidence is windowed upstream to the last [kRecencyDays] days, so
//     stale mastery fades instead of lingering forever.
//   * Per-domain accuracy shrinks toward a conservative prior
//     ([kPriorAccuracy]) weighted as [kPriorWeight] pseudo-answers. A
//     handful of correct answers cannot claim a whole domain: 3/3 counts
//     as 7.8 correct of 15, not 100%.
//   * The band is widest when evidence is thin and narrows only with
//     volume; "ready" and "locked in" hang off the LOW bound, so they are
//     reachable only through sustained evidence in every domain.
//
// Positioning guard: this is a "practice projection", never a predictor
// (CLAUDE.md standing rule; FLDOE materials are not predictors either).

/// Answers older than this contribute nothing to the projection.
const kRecencyDays = 45;

/// Pseudo-answers of prior belief per domain (Bayesian shrinkage).
const kPriorWeight = 12;

/// The prior accuracy for an unstudied (or stale) domain: a risk, not a
/// blank.
const kPriorAccuracy = 0.40;

/// Below this many recent answers overall there is no honest signal.
const kMinAnswersForProjection = 8;

/// Projected exam-score range over the four 20-point FCLE domains, or
/// null when recent evidence is too thin to say anything honest.
/// [domains] must carry one entry per domain (zeros for unstudied).
({int low, int high})? projectScore(
  Iterable<({int correct, int count})> domains,
) {
  var total = 0;
  var mid = 0.0;
  for (final d in domains) {
    total += d.count;
    final shrunk =
        (d.correct + kPriorAccuracy * kPriorWeight) / (d.count + kPriorWeight);
    mid += shrunk * 20;
  }
  if (total < kMinAnswersForProjection) return null;
  final width = (16 - total ~/ 12).clamp(6, 16);
  return (
    low: (mid - width).round().clamp(0, 80),
    high: (mid + width).round().clamp(0, 80),
  );
}

/// The same shrunk math when only a pooled correct/total is known (the
/// diagnostic result screen's fallback while the shared provider loads).
({int low, int high}) fallbackProjection(int correct, int total) {
  final shrunk = (correct + 4 * kPriorAccuracy * kPriorWeight) /
      (total + 4 * kPriorWeight);
  final mid = shrunk * 80;
  final width = (16 - total ~/ 12).clamp(6, 16);
  return (
    low: (mid - width).round().clamp(0, 80),
    high: (mid + width).round().clamp(0, 80),
  );
}
