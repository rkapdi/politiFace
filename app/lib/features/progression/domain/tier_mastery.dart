/// Per-tier rollup used by the node detail sheet and the unlock decider.
class TierMasteryStatus {
  const TierMasteryStatus({
    required this.tier,
    required this.totalCards,
    required this.passingCards,
    required this.progressFraction,
    required this.isMastered,
  });

  /// 1-based tier index (1 = recognition, 2 = understanding, 3 = mastery).
  final int tier;
  final int totalCards;
  final int passingCards;

  /// 0..1 — soft progress signal for the UI bar. Mean of per-card progress
  /// toward the demonstrated-recall gate, so the bar moves before the binary
  /// "tier complete" flips.
  final double progressFraction;

  /// True iff every card in this tier passes the demonstrated-recall gate.
  /// This is what unlocks the next tier / node.
  final bool isMastered;

  bool get isEmpty => totalCards == 0;
}
