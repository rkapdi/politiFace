import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/session/domain/session_queue.dart';

SessionCard _card(String id, {CardPhase phase = CardPhase.dueReview, double stability = 1.0}) {
  return SessionCard(
    cardId: id,
    externalId: id,
    politicianName: id,
    title: 't',
    phase: phase,
    stability: stability,
    priority: phase == CardPhase.dueReview ? stability : 1.0,
  );
}

void main() {
  group('SessionQueue.buildSession', () {
    test('empty queue when no cards given', () {
      final q = SessionQueue();
      q.buildSession(dueCards: const [], newCards: const [], targetSize: 20);
      expect(q.isEmpty, isTrue);
      expect(q.next(), isNull);
    });

    test('all due cards become available', () {
      final q = SessionQueue();
      q.buildSession(
        dueCards: [_card('a', stability: 5), _card('b', stability: 2), _card('c', stability: 8)],
        newCards: const [],
        targetSize: 20,
      );
      expect(q.remaining, 3);
    });

    test('lowest stability is shown first (most at risk)', () {
      final q = SessionQueue();
      q.buildSession(
        dueCards: [_card('a', stability: 5), _card('b', stability: 2), _card('c', stability: 8)],
        newCards: const [],
        targetSize: 20,
      );
      expect(q.next()?.cardId, 'b'); // stability 2
      expect(q.next()?.cardId, 'a'); // stability 5
      expect(q.next()?.cardId, 'c'); // stability 8
      expect(q.next(), isNull);
    });

    test('due cards precede new cards', () {
      final q = SessionQueue();
      q.buildSession(
        dueCards: [_card('due-a', stability: 10)],
        newCards: [_card('new-a', phase: CardPhase.newCard)],
        targetSize: 20,
      );
      expect(q.next()?.cardId, 'due-a');
      expect(q.next()?.cardId, 'new-a');
    });
  });

  group('SessionQueue.requeueAfterFailure', () {
    test('failed card is shown again later in the session', () {
      final q = SessionQueue();
      q.buildSession(
        dueCards: [
          _card('a', stability: 1),
          _card('b', stability: 2),
          _card('c', stability: 3),
        ],
        newCards: const [],
        targetSize: 20,
      );
      final a = q.next()!;
      expect(a.cardId, 'a');
      q.requeueAfterFailure(a);
      // b and c come out, then a again
      final seenOrder = <String>[];
      while (!q.isEmpty) {
        final c = q.next();
        if (c != null) seenOrder.add(c.cardId);
      }
      expect(seenOrder.contains('a'), isTrue, reason: 'requeued card must come back');
      expect(seenOrder.indexOf('b'), lessThan(seenOrder.indexOf('a')),
          reason: 'b should be shown before requeued a');
    });
  });

  group('SessionQueue.next bounded recent-buffer (regression for freeze)', () {
    test('does not loop forever when only card in heap is recent', () {
      final q = SessionQueue();
      q.buildSession(
        dueCards: [_card('only', stability: 1)],
        newCards: const [],
        targetSize: 20,
      );
      final first = q.next();
      expect(first?.cardId, 'only');
      // Re-queue (simulating a failed grade) — the card was just shown, so
      // it's in the recent buffer. Without the bound, the next call loops.
      q.requeueAfterFailure(first!);
      // This must terminate.
      final second = q.next();
      expect(second?.cardId, 'only',
          reason: 'after exhausting requeue budget, recent card returns anyway');
    });

    test('returns null when heap empty', () {
      final q = SessionQueue();
      q.buildSession(dueCards: const [], newCards: const [], targetSize: 20);
      expect(q.next(), isNull);
    });
  });
}
