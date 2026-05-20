import 'package:drift/drift.dart';

import '../../../core/database/drift/app_database.dart';
import '../domain/fsrs_algorithm.dart';
import '../domain/session_queue.dart';

MemoryState memoryStateFromRow(CardMemoryState row) {
  return MemoryState(
    difficulty: row.difficulty,
    stability: row.stability,
    retrievability: row.retrievability,
    lapses: row.lapses,
    reviewCount: row.reviewCount,
  );
}

CardMemoryStatesCompanion memoryStateToCompanion({
  required String cardId,
  required FSRSResult result,
  required DateTime now,
}) {
  return CardMemoryStatesCompanion(
    cardId: Value(cardId),
    difficulty: Value(result.nextState.difficulty),
    stability: Value(result.nextState.stability),
    retrievability: Value(result.nextState.retrievability),
    lastReviewedAt: Value(now.millisecondsSinceEpoch ~/ 1000),
    nextReviewAt: Value(result.nextReviewAt.millisecondsSinceEpoch ~/ 1000),
    intervalDays: Value(result.intervalDays),
    lapses: Value(result.nextState.lapses),
    reviewCount: Value(result.nextState.reviewCount),
    isNew: const Value(false),
  );
}

SessionCard sessionCardFromRows({
  required LocalCard card,
  required CardMemoryState? state,
  required CardPhase phase,
}) {
  final stability = state?.stability ?? 1.0;
  return SessionCard(
    cardId: card.id,
    externalId: card.externalId,
    politicianName: card.politicianName,
    title: card.title,
    photoUrl: card.photoUrl,
    lqipBase64: card.lqipBase64,
    oneLiner: card.oneLiner,
    phase: phase,
    stability: stability,
    priority: phase == CardPhase.dueReview ? stability : 1.0,
  );
}
