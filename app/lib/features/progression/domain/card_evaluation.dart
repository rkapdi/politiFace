import 'dart:math' as math;

/// Minimum signals about a single card needed to evaluate the
/// demonstrated-recall unlock gate. Pure data — no Drift, no Flutter.
class CardEvaluation {
  const CardEvaluation({
    required this.cardId,
    required this.isNew,
    required this.stability,
    required this.lastReviewedAtUnix,
    required this.reviewCount,
    required this.practiceCountSinceReview,
    required this.lastGrade,
  });

  final String cardId;
  final bool isNew;
  final double stability;          // FSRS S, days
  final int lastReviewedAtUnix;    // 0 if never reviewed
  final int reviewCount;           // real FSRS reviews
  final int practiceCountSinceReview;
  final int lastGrade;             // FSRSGrade.value: 0..3

  /// Total demonstrated-recall attempts since the last real FSRS update.
  /// First real review counts as 1 attempt; subsequent practice taps add to
  /// that count. Used by the unlock gate.
  int get demonstratedAttempts =>
      (reviewCount > 0 ? 1 : 0) + practiceCountSinceReview;

  /// Current FSRS retrievability — probability of recall right now given
  /// elapsed days since last real review. R = (1 + t/(9S))^-1.
  /// Returns 0 if the card was never reviewed.
  double retrievabilityAt(int nowUnix) {
    if (lastReviewedAtUnix == 0 || stability <= 0) return 0;
    final elapsedDays = (nowUnix - lastReviewedAtUnix) / 86400.0;
    if (elapsedDays <= 0) return 1;
    return math.pow(1.0 + elapsedDays / (9.0 * stability), -1).toDouble();
  }
}
