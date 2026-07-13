import '../../../core/database/drift/app_database.dart';
import '../../progression/domain/card_evaluation.dart';
import '../domain/curriculum.dart';

/// Read-time per-deck progress for a chapter's declared decks. Pure
/// queries over LocalDecks/LocalCards/CardMemoryStates; no writes, no
/// FSRS mutation.
class ChapterDeckProgress {
  const ChapterDeckProgress({
    required this.ref,
    required this.deckName,
    required this.totalCards,
    required this.studiedCards,
    required this.strongCards,
  });

  final ChapterDeckRef ref;

  /// DB deck name when seeded; falls back to ref.title otherwise.
  final String deckName;
  final int totalCards;

  /// Cards with at least one encounter (CardMemoryStates.isNew == false).
  final int studiedCards;

  /// Cards with a real review and current retrievability >= 0.8.
  final int strongCards;

  bool get isAvailable => totalCards > 0;
  double get studiedFraction => totalCards == 0 ? 0 : studiedCards / totalCards;
}

class ChapterDeckProgressService {
  ChapterDeckProgressService(this._db);
  final AppDatabase _db;

  static const double _strongThreshold = 0.8;

  Future<List<ChapterDeckProgress>> forChapter(Chapter chapter) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final result = <ChapterDeckProgress>[];
    for (final ref in chapter.decks) {
      if (ref.planned) {
        result.add(
          ChapterDeckProgress(
            ref: ref,
            deckName: ref.title,
            totalCards: 0,
            studiedCards: 0,
            strongCards: 0,
          ),
        );
        continue;
      }
      final deck = await _db.decksDao.deckByExternalId(ref.id);
      if (deck == null) {
        result.add(
          ChapterDeckProgress(
            ref: ref,
            deckName: ref.title,
            totalCards: 0,
            studiedCards: 0,
            strongCards: 0,
          ),
        );
        continue;
      }
      final cards = await _db.cardsDao.cardsByDeckId(deck.id);
      final active = [
        for (final c in cards)
          if (c.isActive) c,
      ];
      final states =
          await _db.reviewsDao.statesForCards([for (final c in active) c.id]);
      var studied = 0;
      var strong = 0;
      for (final s in states) {
        if (s.isNew) continue;
        studied++;
        final eval = CardEvaluation(
          cardId: s.cardId,
          isNew: s.isNew,
          stability: s.stability,
          lastReviewedAtUnix: s.lastReviewedAt,
          reviewCount: s.reviewCount,
          practiceCountSinceReview: s.practiceCountSinceReview,
          lastGrade: s.lastGrade,
        );
        if (s.reviewCount > 0 &&
            eval.retrievabilityAt(now) >= _strongThreshold) {
          strong++;
        }
      }
      result.add(
        ChapterDeckProgress(
          ref: ref,
          deckName: deck.name,
          totalCards: active.length,
          studiedCards: studied,
          strongCards: strong,
        ),
      );
    }
    return result;
  }
}
