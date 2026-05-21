import 'dart:math' as math;

/// Maps FSRS stability (days until retention drops to 90%) to a 0–5
/// "mastery level" suitable for end-user display.
///
/// Buckets are intentionally generous early so the user sees motion within
/// the first few reviews and slow afterward so 5-star takes real practice:
///   ☆ 0 — never seen (new card)
///   ★ 1 — < 3 days
///   ★ 2 — < 7 days
///   ★ 3 — < 14 days
///   ★ 4 — < 30 days
///   ★ 5 — ≥ 30 days (mastered)
int masteryLevelFromStability({
  required bool isNewCard,
  required double stability,
}) {
  if (isNewCard) return 0;
  if (stability < 3) return 1;
  if (stability < 7) return 2;
  if (stability < 14) return 3;
  if (stability < 30) return 4;
  return 5;
}

/// Continuous per-card mastery in [0, 1] — moves on any review, not just
/// the FSRS bucket-tier crossings. Used wherever a smooth progress signal
/// beats a discrete tier number (node bar, in-card stars).
///
/// Three-component curve combining game-feel and memory science:
///   - effortBase  = 0.30 + 0.10 × min(reviewCount, 5)
///       Linear 0.40 → 0.80 across the first five reviews. Punchy
///       early-game feedback.
///   - effortBonus = 0.15 × (1 - exp(-(reviewCount-5)/4))   for N > 5
///       Asymptotes toward +0.15 with diminishing returns so the bar keeps
///       climbing past five reviews but slowly — grinding the same card a
///       hundred times can't trivially hit 100%.
///   - retention   = 0.05 × sqrt(stability / 30)
///       The science layer. Reserves the final ~5% for genuine ★5 long-term
///       mastery rather than just play volume.
///
/// Sample trajectory at very low stability (same-day rapid replays):
///   review 1 → 40 %    review 2 → 50 %    review 5 → 80 %
///   review 6 → 83 %    review 8 → 88 %    review 15 → 94 %
double cardMasteryFraction({
  required bool isNewCard,
  required double stability,
  required int reviewCount,
}) {
  if (isNewCard || reviewCount == 0) return 0.0;
  final effortBase = 0.30 + 0.10 * math.min(reviewCount, 5);
  final effortBonus = reviewCount > 5
      ? 0.15 * (1 - math.exp(-(reviewCount - 5) / 4.0))
      : 0.0;
  final retention = 0.05 * math.sqrt((stability / 30.0).clamp(0.0, 1.0));
  return (effortBase + effortBonus + retention).clamp(0.0, 1.0);
}

/// Same curve as [cardMasteryFraction] but in star-count units [0, 5]. For
/// partial-fill star widgets.
double cardStarFill({
  required bool isNewCard,
  required double stability,
  required int reviewCount,
}) =>
    cardMasteryFraction(
      isNewCard: isNewCard,
      stability: stability,
      reviewCount: reviewCount,
    ) *
    5;

/// User-facing label for a mastery level. Use sparingly — the bar usually
/// speaks for itself.
String masteryLabelFor(int level) {
  switch (level) {
    case 0:
      return 'New';
    case 1:
      return 'Learning';
    case 2:
      return 'Familiar';
    case 3:
      return 'Strong';
    case 4:
      return 'Solid';
    case 5:
      return 'Mastered';
    default:
      return '';
  }
}
