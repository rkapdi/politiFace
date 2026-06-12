// lib/features/session/domain/fsrs_algorithm.dart
//
// FSRS-4.5: Free Spaced Repetition Scheduler
// Pure Dart — no Flutter imports, no external dependencies.
// Trained on 1.7 billion Anki reviews. Empirically superior to SM-2.
//
// Reference: https://github.com/open-spaced-repetition/fsrs4anki
//
// ALL methods are O(1) time and space — pure arithmetic, no allocations.

import 'dart:math';

// ── Grade ─────────────────────────────────────────────────────────────────────
// Maps to the 4-button rating in Anki / Politiface
enum FSRSGrade {
  again(0), // Complete failure. Reset.
  hard(1),  // Correct but very difficult. Small interval increase.
  good(2),  // Correct with effort. Standard increase.
  easy(3);  // Trivially correct. Large interval increase.

  final int value;
  const FSRSGrade(this.value);
}

// ── Memory state ──────────────────────────────────────────────────────────────
class MemoryState {
  /// D (Difficulty): intrinsic card difficulty. Range: 1.0–10.0.
  final double difficulty;

  /// S (Stability): days until retrievability drops to [requestedRetention].
  /// A stability of 30 means the user will recall the card after 30 days
  /// with [requestedRetention] probability (default 90%).
  final double stability;

  /// R (Retrievability): current probability of recall. Range: 0.0–1.0.
  final double retrievability;

  /// Number of times the card was forgotten (grade == again).
  final int lapses;

  /// Total number of reviews (including failures).
  final int reviewCount;

  const MemoryState({
    required this.difficulty,
    required this.stability,
    required this.retrievability,
    required this.lapses,
    required this.reviewCount,
  });

  // Default state for a brand-new card
  static const initial = MemoryState(
    difficulty: 5,
    stability: 1,
    retrievability: 1,
    lapses: 0,
    reviewCount: 0,
  );
}

// ── Result ────────────────────────────────────────────────────────────────────
class FSRSResult {
  final MemoryState nextState;
  final int intervalDays;
  final DateTime nextReviewAt;

  const FSRSResult({
    required this.nextState,
    required this.intervalDays,
    required this.nextReviewAt,
  });
}

// ── Algorithm ─────────────────────────────────────────────────────────────────
class FSRS {
  // Default weights trained on 1.7B Anki reviews.
  // Override with personalized weights after user has 1000+ reviews.
  static const List<double> defaultWeights = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0589,
    1.5330, 0.1544, 0.9898, 1.9864, 0.1073, 0.3126, 2.2975, 0.2502, 2.9898,
  ];

  final List<double> w;

  /// Target retention probability. 0.9 = user recalls card 90% of the time
  /// at the scheduled review date. Higher = shorter intervals, more reviews.
  final double requestedRetention;

  const FSRS({
    this.w = defaultWeights,
    this.requestedRetention = 0.9,
  });

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Schedule a card review. Call this every time the user answers a card.
  /// [current]: memory state before this review (use MemoryState.initial for new cards)
  /// [grade]:   how well the user recalled the card
  /// [lastReviewedAt]: when the card was last reviewed (for elapsed days calculation)
  ///
  /// O(1) time and space.
  FSRSResult schedule({
    required MemoryState current,
    required FSRSGrade grade,
    required DateTime lastReviewedAt,
  }) {
    final now = DateTime.now();
    // Use fractional days, not the whole-day integer .inDays gives back.
    // .inDays of "23h59m" is 0 — which makes (1 - r) collapse to 0 in
    // _stabilityAfterRecall and pins same-day repeat reviews to their
    // initial stability forever. Microsecond math fixes that.
    final elapsedDays = now.difference(lastReviewedAt).inMicroseconds /
        Duration.microsecondsPerDay;
    final currentR = _forgettingCurve(elapsedDays, current.stability);

    // Clamp difficulty before using it in stability calculations: stability
    // formulas call pow(d, ...) with a non-integer exponent, which returns NaN
    // for negative d.
    final newD = _nextDifficulty(current.difficulty, grade).clamp(1.0, 10.0);
    double newS;

    if (grade == FSRSGrade.again) {
      newS = _stabilityAfterLapse(newD, current.stability, currentR);
    } else {
      newS = _stabilityAfterRecall(newD, current.stability, currentR, grade);
    }

    newS = newS.clamp(0.1, 36500.0); // max ~100 years

    final interval = _optimalInterval(newS);
    final nextReview = now.add(Duration(days: interval));

    return FSRSResult(
      nextState: MemoryState(
        difficulty: newD,
        stability: newS,
        retrievability: currentR,
        lapses: grade == FSRSGrade.again
            ? current.lapses + 1
            : current.lapses,
        reviewCount: current.reviewCount + 1,
      ),
      intervalDays: interval,
      nextReviewAt: nextReview,
    );
  }

  /// Initial stability for a brand-new card based on first answer grade.
  /// Use this instead of [schedule] for the very first review of a card.
  FSRSResult scheduleNew({required FSRSGrade grade}) {
    final s = _initialStability(grade);
    final d = _initialDifficulty(grade);
    final interval = _optimalInterval(s);

    return FSRSResult(
      nextState: MemoryState(
        difficulty: d.clamp(1.0, 10.0),
        stability: s.clamp(0.1, 36500.0),
        retrievability: 1,
        lapses: grade == FSRSGrade.again ? 1 : 0,
        reviewCount: 1,
      ),
      intervalDays: interval,
      nextReviewAt: DateTime.now().add(Duration(days: interval)),
    );
  }

  /// Current retrievability for a card given elapsed days and stability.
  /// Use for display purposes (e.g., showing memory strength).
  double retrievability(int elapsedDays, double stability) => _forgettingCurve(elapsedDays.toDouble(), stability);

  // ── Private: FSRS-4.5 equations ────────────────────────────────────────────

  // Ebbinghaus forgetting curve: R(t,S) = (1 + t/(9*S))^-1
  // Approximation of e^(-t/S) that is computationally cheaper
  double _forgettingCurve(double t, double s) {
    if (s <= 0) return 0;
    return pow(1.0 + t / (9.0 * s), -1).toDouble();
  }

  // Optimal interval: solve R(t,S) = requestedRetention for t
  // t = S * (R^(-1/1) - 1) * 9
  int _optimalInterval(double stability) {
    final t = 9.0 * stability * (pow(requestedRetention, -1.0) - 1.0);
    return max(1, t.round());
  }

  // Initial stability by grade (first time seeing a card)
  double _initialStability(FSRSGrade grade) => w[grade.value];

  // Initial difficulty by grade
  double _initialDifficulty(FSRSGrade grade) => w[4] - exp(w[5] * (grade.value - 1)) + 1;

  // Next difficulty after review. Mean-reverts toward w[4].
  // grade 2 (good) = neutral. Higher = easier. Lower = harder.
  double _nextDifficulty(double d, FSRSGrade grade) {
    final delta = -w[6] * (grade.value - 3);
    return w[4] - exp(w[5] * delta) + (d - w[4]) * 0.9;
  }

  // Stability after successful recall
  double _stabilityAfterRecall(
    double d, double s, double r, FSRSGrade grade,) {
    final hardPenalty  = grade == FSRSGrade.hard ? w[15] : 1.0;
    final easyBonus    = grade == FSRSGrade.easy ? w[16] : 1.0;
    return s * (
      exp(w[8]) *
      (11.0 - d) *
      pow(s, -w[9]) *
      (exp((1.0 - r) * w[10]) - 1.0) *
      hardPenalty *
      easyBonus + 1.0
    );
  }

  // Stability after lapse (forgetting)
  double _stabilityAfterLapse(double d, double s, double r) => w[11] *
      pow(d, -w[12]) *
      (pow(s + 1.0, w[13]) - 1.0) *
      exp((1.0 - r) * w[14]);
}
