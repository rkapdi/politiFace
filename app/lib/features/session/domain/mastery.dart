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
