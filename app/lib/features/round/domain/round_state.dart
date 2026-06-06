import '../../trivia/domain/trivia_question.dart';
import '../../trivia/domain/trivia_scoring.dart';

/// The four phases a daily round walks through, in order.
enum RoundPhase {
  /// 5 flashcards drawn from the current chapter. Grade each → advance.
  cards,

  /// 10 confidence-scored trivia questions drawn from the current chapter.
  trivia,

  /// Archetype + score reveal screen with share card.
  reveal,

  /// Round persisted, chapter day advanced. Terminal.
  done,
}

extension RoundPhaseSerialization on RoundPhase {
  String get wireName {
    switch (this) {
      case RoundPhase.cards:
        return 'cards';
      case RoundPhase.trivia:
        return 'trivia';
      case RoundPhase.reveal:
        return 'reveal';
      case RoundPhase.done:
        return 'done';
    }
  }

  static RoundPhase fromWire(String s) {
    switch (s) {
      case 'cards':
        return RoundPhase.cards;
      case 'trivia':
        return RoundPhase.trivia;
      case 'reveal':
        return RoundPhase.reveal;
      case 'done':
        return RoundPhase.done;
      default:
        throw ArgumentError('Unknown RoundPhase: $s');
    }
  }
}

/// One flashcard inside the cards phase. Holds just enough to render the
/// prompt + answer pair; FSRS state updates happen separately via the
/// existing `CardReviewRepository` when the user grades.
class RoundCard {
  const RoundCard({
    required this.cardId,
    required this.prompt,
    required this.answer,
    this.politicianName,
    this.photoUrl,
    this.grade,
  });

  /// The `LocalCards.id` this card was sampled from.
  final String cardId;

  /// What the user sees on the front of the card (e.g. politician's name +
  /// title, or — once concept decks ship — a curriculum prompt).
  final String prompt;

  /// What flips into view (e.g. one_liner, source, photo URL, or concept
  /// answer).
  final String answer;

  /// Display name of the politician this card is about. Used as fallback for
  /// the avatar's initials when no portrait is available. Null for concept
  /// flashcards once those ship.
  final String? politicianName;

  /// Bundled-asset path or HTTP(S) URL to the politician's portrait. Drives
  /// the avatar shown on the card's reveal side. Null for text-only cards.
  final String? photoUrl;

  /// 0..3 once graded; null while the card is still face-down.
  final int? grade;

  RoundCard copyWith({int? grade}) {
    return RoundCard(
      cardId: cardId,
      prompt: prompt,
      answer: answer,
      politicianName: politicianName,
      photoUrl: photoUrl,
      grade: grade ?? this.grade,
    );
  }
}

/// One trivia MCQ inside the trivia phase. The question + answer match
/// the existing `TriviaQuestion` + `TriviaAnswer` shape so the existing
/// trivia UI widgets can render this without changes.
class RoundTrivia {
  const RoundTrivia({
    required this.question,
    this.answer,
  });

  final TriviaQuestion question;

  /// Set once the user picks an option + confidence; null while pending.
  final TriviaAnswer? answer;

  RoundTrivia copyWith({TriviaAnswer? answer}) {
    return RoundTrivia(question: question, answer: answer ?? this.answer);
  }

  bool get isAnswered => answer != null;
}

/// Immutable snapshot of a single day's round. Held by
/// `DailyRoundController`; replaced wholesale on every state transition.
class DailyRoundState {
  const DailyRoundState({
    required this.dateIso,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterSubtitle,
    required this.dayInChapter,
    required this.daysInChapter,
    required this.phase,
    required this.cards,
    required this.trivia,
    this.result,
  });

  final String dateIso;

  final String chapterId;
  final String chapterTitle;
  final String chapterSubtitle;
  final int dayInChapter;
  final int daysInChapter;

  final RoundPhase phase;

  /// Always 5 entries (or fewer when chapter content is sparse during
  /// Phase 0 authoring backlog).
  final List<RoundCard> cards;

  /// Always 10 entries (or fewer; same reason).
  final List<RoundTrivia> trivia;

  /// Computed when the round enters [RoundPhase.reveal]. The
  /// existing trivia archetype scoring lives in `trivia_scoring.dart`.
  final TriviaResult? result;

  bool get isCardsPhase => phase == RoundPhase.cards;
  bool get isTriviaPhase => phase == RoundPhase.trivia;
  bool get isRevealPhase => phase == RoundPhase.reveal;
  bool get isDone => phase == RoundPhase.done;

  /// Index of the next card to grade, or null if all cards are graded.
  int? get nextUngradedCard {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].grade == null) return i;
    }
    return null;
  }

  /// Index of the next trivia to answer, or null if all are answered.
  int? get nextUnansweredTrivia {
    for (var i = 0; i < trivia.length; i++) {
      if (trivia[i].answer == null) return i;
    }
    return null;
  }

  /// Trailing run of consecutive correct trivia answers. Drives the streak
  /// chip in the trivia phase — borrows the visual vocabulary of Endless's
  /// score bar so the game-feel reads the same in both modes.
  int get currentCorrectStreak {
    var streak = 0;
    for (final t in trivia) {
      final a = t.answer;
      if (a == null) break;
      if (a.isCorrect) {
        streak++;
      } else {
        streak = 0;
      }
    }
    return streak;
  }

  DailyRoundState copyWith({
    RoundPhase? phase,
    List<RoundCard>? cards,
    List<RoundTrivia>? trivia,
    TriviaResult? result,
  }) {
    return DailyRoundState(
      dateIso: dateIso,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      chapterSubtitle: chapterSubtitle,
      dayInChapter: dayInChapter,
      daysInChapter: daysInChapter,
      phase: phase ?? this.phase,
      cards: cards ?? this.cards,
      trivia: trivia ?? this.trivia,
      result: result ?? this.result,
    );
  }
}

/// Reason a round can't be started — surfaced to the UI as a structured
/// error rather than a thrown exception.
enum RoundUnavailableReason {
  /// User has completed every chapter in the active season; no more
  /// rounds to play until new content ships.
  seasonComplete,

  /// Today's chapter resolves zero playable cards (e.g., concept decks
  /// for the chapter haven't been authored yet). UI should show a
  /// "content coming soon" state.
  noContent,
}

/// Returned by the controller when a round can't be constructed for
/// today's date.
class RoundUnavailable {
  const RoundUnavailable(this.reason, this.message);
  final RoundUnavailableReason reason;
  final String message;
}
