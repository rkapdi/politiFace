// lib/features/session/domain/session_queue.dart
//
// Session card selection and ordering.
// Uses HeapPriorityQueue (min-heap) for O(log n) insert/extract.
//
// Ordering rules:
//   1. Due review cards before new cards (always)
//   2. Within due reviews: lowest stability first (most at risk)
//   3. New cards interleaved at every 4th position
//   4. Cards seen < 10 min ago are re-queued (short-term interference)

import 'dart:math' show min;

import 'package:collection/collection.dart' show HeapPriorityQueue;

enum CardPhase { dueReview, newCard }

class SessionCard implements Comparable<SessionCard> {
  final String cardId;
  final String externalId;
  final String politicianName;
  final String title;
  final String? photoUrl;
  final String? lqipBase64;
  final String? oneLiner;
  // 'face' or 'concept'. Concept cards teach on first encounter (body)
  // and recall via recallPrompt afterward.
  final String cardType;
  final String? body;
  final String? recallPrompt;
  final CardPhase phase;
  final double stability;    // FSRS S (lower = more at risk)
  final int reviewCount;     // FSRS review count for this card
  final double priority;     // heap key

  const SessionCard({
    required this.cardId,
    required this.externalId,
    required this.politicianName,
    required this.title,
    required this.phase, required this.stability, required this.priority, this.photoUrl,
    this.lqipBase64,
    this.oneLiner,
    this.cardType = 'face',
    this.body,
    this.recallPrompt,
    this.reviewCount = 0,
  });

  bool get isConcept => cardType == 'concept';

  /// First encounter with a concept: render the lesson, not the quiz.
  bool get teachFirst => isConcept && phase == CardPhase.newCard;

  @override
  int compareTo(SessionCard other) => priority.compareTo(other.priority);
}

class SessionQueue {
  // Min-heap: smallest priority = shown first
  final _heap = HeapPriorityQueue<SessionCard>();

  // Short-term interference buffer: don't show same card within 10 min
  final _recentlyShown = <String, DateTime>{};
  static const _recentWindowMinutes = 10;
  static const _newCardEvery = 4; // interleave new card every N cards

  /// O(n log n) — called once per session build
  void buildSession({
    required List<SessionCard> dueCards,
    required List<SessionCard> newCards,
    required int targetSize,
    // Explicit card lists (chapter replay, teach-first round content) want
    // every requested card, not the every-Nth interleave ratio.
    bool includeAllNew = false,
  }) {
    _heap.clear();
    _recentlyShown.clear();

    // Due reviews: priority = stability. Lower stability (more at risk of
    // forgetting) is shown first. We add `_duePriorityOffset` so that even a
    // high-stability due card stays below any new card.
    for (final card in dueCards) {
      _heap.add(SessionCard(
        cardId: card.cardId,
        externalId: card.externalId,
        politicianName: card.politicianName,
        title: card.title,
        photoUrl: card.photoUrl,
        lqipBase64: card.lqipBase64,
        oneLiner: card.oneLiner,
        cardType: card.cardType,
        body: card.body,
        recallPrompt: card.recallPrompt,
        phase: CardPhase.dueReview,
        stability: card.stability,
        reviewCount: card.reviewCount,
        priority: card.stability,
      ),);
    }

    // New cards always follow due cards. The big offset keeps them strictly
    // above any plausible due stability.
    final newCardSlots = includeAllNew
        ? newCards.length
        : (targetSize / _newCardEvery).floor();
    final selectedNew = newCards.take(min(newCardSlots, newCards.length)).toList();

    for (var i = 0; i < selectedNew.length; i++) {
      final card = selectedNew[i];
      _heap.add(SessionCard(
        cardId: card.cardId,
        externalId: card.externalId,
        politicianName: card.politicianName,
        title: card.title,
        photoUrl: card.photoUrl,
        lqipBase64: card.lqipBase64,
        oneLiner: card.oneLiner,
        cardType: card.cardType,
        body: card.body,
        recallPrompt: card.recallPrompt,
        phase: CardPhase.newCard,
        stability: 0,
        reviewCount: card.reviewCount,
        priority: _newCardPriorityOffset + (i / selectedNew.length),
      ),);
    }
  }

  // Larger than any FSRS stability ever produced (clamp upper bound is 36500).
  static const double _newCardPriorityOffset = 1000000;

  /// O(log n) — returns null when session is complete
  SessionCard? next() {
    // Bound the recent-buffer rescheduling so a heap that contains only
    // recently-shown cards (e.g. a single requeued failure at session end)
    // can't spin forever. After heap.length re-queue attempts every card has
    // been considered once; on the next pop we just return it.
    final budget = _heap.length;
    var requeues = 0;
    while (_heap.isNotEmpty) {
      final candidate = _heap.removeFirst(); // O(log n)
      final lastShown = _recentlyShown[candidate.cardId];

      final isRecent = lastShown != null &&
          DateTime.now().difference(lastShown).inMinutes < _recentWindowMinutes;

      if (isRecent && requeues < budget) {
        _heap.add(SessionCard(
          cardId: candidate.cardId,
          externalId: candidate.externalId,
          politicianName: candidate.politicianName,
          title: candidate.title,
          photoUrl: candidate.photoUrl,
          lqipBase64: candidate.lqipBase64,
          oneLiner: candidate.oneLiner,
          cardType: candidate.cardType,
          body: candidate.body,
          recallPrompt: candidate.recallPrompt,
          phase: candidate.phase,
          stability: candidate.stability,
          reviewCount: candidate.reviewCount,
          priority: candidate.priority + 100.0,
        ),);
        requeues++;
        continue;
      }

      _recentlyShown[candidate.cardId] = DateTime.now();
      return candidate;
    }
    return null;
  }

  /// Re-queue a card after an incorrect answer.
  /// Shows it again later in the same session. O(log n).
  void requeueAfterFailure(SessionCard card) {
    _heap.add(SessionCard(
      cardId: card.cardId,
      externalId: card.externalId,
      politicianName: card.politicianName,
      title: card.title,
      photoUrl: card.photoUrl,
      lqipBase64: card.lqipBase64,
      oneLiner: card.oneLiner,
      cardType: card.cardType,
      body: card.body,
      recallPrompt: card.recallPrompt,
      phase: card.phase,
      stability: card.stability,
      reviewCount: card.reviewCount,
      // Re-insert after all current cards but before very-end cards
      priority: 50.0 + (_heap.length * 0.01),
    ),);
  }

  bool get isEmpty => _heap.isEmpty;
  int get remaining => _heap.length;

  /// Returns every card currently in the queue, in the order the queue would
  /// pop them. Used by [PendingSessionStore] to snapshot the remaining work
  /// for resume-after-crash.
  List<SessionCard> snapshot() => _heap.toList();
}
