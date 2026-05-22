import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/progression/domain/card_evaluation.dart';
import 'package:politiface/features/progression/domain/node_state.dart';
import 'package:politiface/features/progression/domain/progression_state_machine.dart';
import 'package:politiface/features/progression/domain/tier_mastery.dart';

const _now = 1800000000; // arbitrary unix seconds

CardEvaluation _eval({
  bool isNew = false,
  double stability = 5.0,
  int lastReviewedAtUnix = _now,
  int reviewCount = 1,
  int practiceCountSinceReview = 2,
  int lastGrade = 2, // Good
  String cardId = 'c1',
}) {
  return CardEvaluation(
    cardId: cardId,
    isNew: isNew,
    stability: stability,
    lastReviewedAtUnix: lastReviewedAtUnix,
    reviewCount: reviewCount,
    practiceCountSinceReview: practiceCountSinceReview,
    lastGrade: lastGrade,
  );
}

void main() {
  const sm = ProgressionStateMachine();

  group('isTierMastered', () {
    test('empty tier never masters', () {
      expect(sm.isTierMastered(cards: const [], nowUnix: _now), isFalse);
    });

    test('all cards passing → mastered', () {
      // 1 real review + 2 practice = 3 attempts, lastGrade Good, stability 5
      // → retrievability at zero elapsed time = 1.0, gate passes.
      expect(
        sm.isTierMastered(
          cards: [_eval(cardId: 'a'), _eval(cardId: 'b')],
          nowUnix: _now,
        ),
        isTrue,
      );
    });

    test('one card failing any predicate holds the gate', () {
      final failing = _eval(cardId: 'b', lastGrade: 1); // Hard
      expect(
        sm.isTierMastered(
          cards: [_eval(cardId: 'a'), failing],
          nowUnix: _now,
        ),
        isFalse,
      );
    });

    test('new card never passes', () {
      expect(
        sm.isTierMastered(cards: [_eval(isNew: true)], nowUnix: _now),
        isFalse,
      );
    });

    test('insufficient attempts blocks the gate', () {
      // 1 review + 0 practice = 1 attempt, below default min of 2
      final c = _eval(reviewCount: 1, practiceCountSinceReview: 0);
      expect(sm.isTierMastered(cards: [c], nowUnix: _now), isFalse);
    });

    test('Again on last grade blocks the gate even with many attempts', () {
      final c = _eval(reviewCount: 5, practiceCountSinceReview: 5, lastGrade: 0);
      expect(sm.isTierMastered(cards: [c], nowUnix: _now), isFalse);
    });

    test('low retrievability (stale review) blocks the gate', () {
      // Reviewed long ago: stability 1 day, elapsed 30 days → R is tiny.
      final c = _eval(
        stability: 1.0,
        lastReviewedAtUnix: _now - 30 * 86400,
      );
      expect(sm.isTierMastered(cards: [c], nowUnix: _now), isFalse);
    });
  });

  group('evaluateTier', () {
    test('empty returns zeroed status', () {
      final t = sm.evaluateTier(tier: 1, cards: const [], nowUnix: _now);
      expect(t.isEmpty, isTrue);
      expect(t.isMastered, isFalse);
      expect(t.progressFraction, 0.0);
      expect(t.passingCards, 0);
    });

    test('progressFraction is monotonic w.r.t. attempts', () {
      final low = sm.evaluateTier(
        tier: 1,
        cards: [_eval(practiceCountSinceReview: 0)],
        nowUnix: _now,
      );
      final high = sm.evaluateTier(
        tier: 1,
        cards: [_eval(practiceCountSinceReview: 5)],
        nowUnix: _now,
      );
      expect(high.progressFraction, greaterThan(low.progressFraction));
    });

    test('partial passing reflects in passingCards count', () {
      final passing = _eval(cardId: 'a');
      final failing = _eval(cardId: 'b', lastGrade: 0);
      final t = sm.evaluateTier(
        tier: 1,
        cards: [passing, failing],
        nowUnix: _now,
      );
      expect(t.totalCards, 2);
      expect(t.passingCards, 1);
      expect(t.isMastered, isFalse);
    });
  });

  group('computeNodeState', () {
    final emptyTiers = [
      const TierMasteryStatus(
        tier: 1,
        totalCards: 0,
        passingCards: 0,
        progressFraction: 0,
        isMastered: false,
      ),
    ];

    test('locked parent forces locked child', () {
      expect(
        sm.computeNodeState(parentState: NodeState.locked, tiers: emptyTiers),
        NodeState.locked,
      );
    });

    test('available parent allows unlock', () {
      // available parent + no content yet on child → child is available
      expect(
        sm.computeNodeState(
          parentState: NodeState.available,
          tiers: emptyTiers,
        ),
        NodeState.available,
      );
    });

    test('mastered parent + no content → available', () {
      expect(
        sm.computeNodeState(
          parentState: NodeState.mastered,
          tiers: emptyTiers,
        ),
        NodeState.available,
      );
    });

    test('mastered parent + some progress on tier → progress', () {
      final tiers = [
        const TierMasteryStatus(
          tier: 1,
          totalCards: 3,
          passingCards: 1,
          progressFraction: 0.45,
          isMastered: false,
        ),
      ];
      expect(
        sm.computeNodeState(parentState: NodeState.mastered, tiers: tiers),
        NodeState.progress,
      );
    });

    test('all populated tiers mastered → node mastered', () {
      final tiers = [
        const TierMasteryStatus(
          tier: 1,
          totalCards: 3,
          passingCards: 3,
          progressFraction: 1.0,
          isMastered: true,
        ),
        const TierMasteryStatus(
          tier: 2,
          totalCards: 0, // no content yet — ignored
          passingCards: 0,
          progressFraction: 0.0,
          isMastered: false,
        ),
      ];
      expect(
        sm.computeNodeState(parentState: NodeState.mastered, tiers: tiers),
        NodeState.mastered,
      );
    });

    test('mastered parent + ALL tiers empty → still available (not mastered)',
        () {
      final tiers = [
        const TierMasteryStatus(
          tier: 1,
          totalCards: 0,
          passingCards: 0,
          progressFraction: 0,
          isMastered: false,
        ),
        const TierMasteryStatus(
          tier: 2,
          totalCards: 0,
          passingCards: 0,
          progressFraction: 0,
          isMastered: false,
        ),
      ];
      expect(
        sm.computeNodeState(parentState: NodeState.mastered, tiers: tiers),
        NodeState.available,
        reason:
            'A node with no authored content should NOT auto-master — the '
            'visible "available" state tells the user the node exists but '
            'has nothing to do yet.',
      );
    });
  });

  group('cardRetrievabilityNow', () {
    test('zero elapsed → R = 1', () {
      expect(
        cardRetrievabilityNow(
          stability: 5,
          lastReviewedAtUnix: _now,
          nowUnix: _now,
        ),
        1.0,
      );
    });

    test('never reviewed → R = 0', () {
      expect(
        cardRetrievabilityNow(
          stability: 5,
          lastReviewedAtUnix: 0,
          nowUnix: _now,
        ),
        0.0,
      );
    });

    test('R decays as elapsed grows', () {
      final near = cardRetrievabilityNow(
        stability: 5,
        lastReviewedAtUnix: _now - 1 * 86400,
        nowUnix: _now,
      );
      final far = cardRetrievabilityNow(
        stability: 5,
        lastReviewedAtUnix: _now - 30 * 86400,
        nowUnix: _now,
      );
      expect(near, greaterThan(far));
      expect(near, lessThan(1.0));
      expect(far, greaterThan(0.0));
    });
  });
}
