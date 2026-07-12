import 'dart:math' as math;

import 'card_evaluation.dart';
import 'node_state.dart';
import 'tier_mastery.dart';

/// Pure-Dart progression rules. No Drift, no Flutter, no clock — every
/// time-dependent input is passed in as `nowUnix`. This is deliberate so the
/// logic is portable to a Postgres SECURITY DEFINER RPC later without any
/// translation step: the same predicates run on a row in Dart today and on
/// a row in PL/pgSQL tomorrow.
class ProgressionStateMachine {
  const ProgressionStateMachine({
    this.minDemonstratedAttempts = 2,
    this.minLastGrade = 2, // FSRSGrade.good == 2
    this.minRetrievability = 0.80,
  });

  /// Minimum number of grade attempts (real FSRS reviews + practice taps)
  /// required for a single card to count toward tier mastery. Two means
  /// "you've recalled this in one real session, then again in a same-day
  /// practice pass" — enough to demonstrate retention without making the
  /// unlock impossible in a single sitting.
  final int minDemonstratedAttempts;

  /// Minimum last-grade value to count a card. Default 2 = Good. A card
  /// whose most recent grade was Again (0) or Hard (1) doesn't count even
  /// if it's been seen many times.
  final int minLastGrade;

  /// Minimum FSRS retrievability for a card to count. Default 0.80 = "you
  /// can still recall this with at least 80% probability right now."
  final double minRetrievability;

  /// The unlock gate. Tier is mastered iff *every* card in it passes all
  /// three predicates. One failing card holds the gate.
  bool isTierMastered({
    required List<CardEvaluation> cards,
    required int nowUnix,
  }) {
    if (cards.isEmpty) return false;
    return cards.every((c) => _passesGate(c, nowUnix));
  }

  /// Per-tier rollup including a soft progress fraction for the UI.
  TierMasteryStatus evaluateTier({
    required int tier,
    required List<CardEvaluation> cards,
    required int nowUnix,
  }) {
    if (cards.isEmpty) {
      return TierMasteryStatus(
        tier: tier,
        totalCards: 0,
        passingCards: 0,
        progressFraction: 0,
        isMastered: false,
      );
    }
    var passing = 0;
    var progressSum = 0.0;
    for (final c in cards) {
      if (_passesGate(c, nowUnix)) passing++;
      progressSum += _cardProgressTowardGate(c, nowUnix);
    }
    return TierMasteryStatus(
      tier: tier,
      totalCards: cards.length,
      passingCards: passing,
      progressFraction: progressSum / cards.length,
      isMastered: passing == cards.length,
    );
  }

  /// Compute a node's overall state given its parent's state and per-tier
  /// rollups. Pure function — no I/O.
  NodeState computeNodeState({
    required NodeState parentState,
    required List<TierMasteryStatus> tiers,
  }) {
    // Locked until the parent is mastered. Root nodes pass parentState
    // = mastered or available — caller's choice.
    if (parentState == NodeState.locked) return NodeState.locked;
    if (!parentState.isStarted && parentState != NodeState.available) {
      return NodeState.locked;
    }

    final populatedTiers = tiers.where((t) => !t.isEmpty).toList();
    if (populatedTiers.isEmpty) {
      // Unlocked node with no content yet — show as available so the user
      // sees the node exists in the map.
      return NodeState.available;
    }

    final allMastered = populatedTiers.every((t) => t.isMastered);
    if (allMastered) return NodeState.mastered;

    final anyTouched = populatedTiers.any((t) =>
        t.passingCards > 0 || t.progressFraction > 0,);
    return anyTouched ? NodeState.progress : NodeState.available;
  }

  bool _passesGate(CardEvaluation c, int nowUnix) {
    if (c.isNew) return false;
    if (c.demonstratedAttempts < minDemonstratedAttempts) return false;
    if (c.lastGrade < minLastGrade) return false;
    if (c.retrievabilityAt(nowUnix) < minRetrievability) return false;
    return true;
  }

  /// Soft progress in [0, 1] for a single card toward the unlock gate.
  /// Mean of the three component fractions (attempts, lastGrade, recall) —
  /// this is what powers the per-tier bar before the binary "passing" flag.
  double _cardProgressTowardGate(CardEvaluation c, int nowUnix) {
    if (c.isNew) return 0;
    final attemptsFraction =
        (c.demonstratedAttempts / minDemonstratedAttempts).clamp(0.0, 1.0);
    final lastGradeFraction =
        (c.lastGrade / 3.0).clamp(0.0, 1.0); // 3 = Easy
    final recallFraction =
        (c.retrievabilityAt(nowUnix) / 1.0).clamp(0.0, 1.0);
    return (attemptsFraction + lastGradeFraction + recallFraction) / 3.0;
  }
}

/// Compatibility helper kept here so external callers can compute a card's
/// retrievability without depending on FSRS internals.
double cardRetrievabilityNow({
  required double stability,
  required int lastReviewedAtUnix,
  required int nowUnix,
}) {
  if (lastReviewedAtUnix == 0 || stability <= 0) return 0;
  final elapsedDays = (nowUnix - lastReviewedAtUnix) / 86400.0;
  if (elapsedDays <= 0) return 1;
  return math.pow(1.0 + elapsedDays / (9.0 * stability), -1).toDouble();
}
