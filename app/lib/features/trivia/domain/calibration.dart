// lib/features/trivia/domain/calibration.dart
//
// Calibration: how often a student was right when they said Guess, Pretty
// sure, or Certain. Shown on FCLE practice, mock and live result screens
// as plain sentences ("When you said Certain, you were right 80% of the
// time"). Pure logic over answers already graded elsewhere.
//
// Calibration is feedback, never a score: nothing here feeds readiness,
// mock scoring, efficacy, or FSRS scheduling, and it carries no points.

import 'trivia_question.dart';

/// One answered question with the confidence the student gave.
class ConfidenceOutcome {
  const ConfidenceOutcome({required this.confidence, required this.correct});

  final TriviaConfidence confidence;
  final bool correct;
}

/// Tally for one confidence label.
class CalibrationRow {
  const CalibrationRow({
    required this.confidence,
    required this.answered,
    required this.correct,
  });

  final TriviaConfidence confidence;
  final int answered;
  final int correct;

  /// Whole-number percent right, rounded half up.
  int get percentRight => answered == 0 ? 0 : (correct * 100 / answered).round();

  /// "When you said Certain, you were right 80% of the time (4 of 5)."
  String get sentence =>
      'When you said ${confidence.plainLabel}, you were right '
      '$percentRight% of the time ($correct of $answered).';
}

/// Rows for the labels actually used, in Guess, Pretty sure, Certain order.
/// Empty when no answer carried a confidence.
List<CalibrationRow> calibrate(Iterable<ConfidenceOutcome> outcomes) {
  final answered = <TriviaConfidence, int>{};
  final correct = <TriviaConfidence, int>{};
  for (final o in outcomes) {
    answered[o.confidence] = (answered[o.confidence] ?? 0) + 1;
    if (o.correct) correct[o.confidence] = (correct[o.confidence] ?? 0) + 1;
  }
  return [
    for (final c in TriviaConfidence.values)
      if ((answered[c] ?? 0) > 0)
        CalibrationRow(
          confidence: c,
          answered: answered[c]!,
          correct: correct[c] ?? 0,
        ),
  ];
}
