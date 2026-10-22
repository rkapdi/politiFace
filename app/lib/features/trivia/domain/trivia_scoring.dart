import 'trivia_question.dart';

/// One of four endgame personality buckets the user lands in. The point of
/// the whole feature: people share archetypes, not scores. "I'm a Civic
/// Bullshitter" >>> "I scored 87."
enum TriviaArchetype {
  /// High score, well-calibrated confidence. Flex-worthy.
  civicScholar(
    emoji: '🎓',
    name: 'Civic Scholar',
    blurb: 'High score, well-calibrated. You actually know your government.',
  ),

  /// High score, low confidence. "I vibed my way through."
  luckyGuesser(
    emoji: '🍀',
    name: 'Lucky Guesser',
    blurb:
        "You doubted yourself the whole way and still nailed it. Don't tell anyone.",
  ),

  /// Low score, high confidence. The viral one — negative-score territory.
  /// Display name softened from "Civic Bullshitter" for App Store review;
  /// enum identifier stays the same to avoid breaking persisted run history.
  civicBullshitter(
    emoji: '💩',
    name: 'Civic Bluffer',
    blurb: 'Confidently incorrect. Dunning-Kruger says hi.',
  ),

  /// Low score, low confidence. Charmingly self-aware.
  humbleApprentice(
    emoji: '🙏',
    name: 'Humble Apprentice',
    blurb: "You didn't know, you said you didn't know, and now you might.",);

  const TriviaArchetype({
    required this.emoji,
    required this.name,
    required this.blurb,
  });
  final String emoji;
  final String name;
  final String blurb;
}

/// Result of grading a single answer. The negative path is the joke.
class AnswerScore {
  const AnswerScore({required this.points, required this.reason});
  final int points;

  /// Human-readable explanation for the per-question reveal screen.
  final String reason;
}

/// Final result of a whole 10-question run.
class TriviaResult {
  const TriviaResult({
    required this.totalScore,
    required this.correctCount,
    required this.totalQuestions,
    required this.averageConfidence,
    required this.archetype,
    required this.gridEmojis,
  });

  final int totalScore;
  final int correctCount;
  final int totalQuestions;

  /// 1.0..3.0 — average of TriviaConfidence.value across all answers.
  final double averageConfidence;
  final TriviaArchetype archetype;

  /// One emoji per answer for the shareable Wordle-style result block.
  final List<String> gridEmojis;

  double get accuracy =>
      totalQuestions == 0 ? 0.0 : correctCount / totalQuestions;

  /// Best possible total for this run (every answer right and Certain).
  int get maxScore => maxScoreFor(totalQuestions);

  /// A "strong run" for color accents: two thirds of the maximum, the same
  /// share the old 100-of-150 cutoff used.
  bool get isStrongScore => totalScore > 0 && totalScore * 3 >= maxScore * 2;
}

/// Points for a perfect answer: right, and you said Certain.
const int kMaxPointsPerAnswer = 100;

/// Best possible total for a run of [questions] answers.
int maxScoreFor(int questions) => questions * kMaxPointsPerAnswer;

/// The Brier-score points for one answer, before any wording.
///
///   points = 101 - 400 * (outcome - p)^2
///
/// where outcome is 1 for right and 0 for wrong, and p is the probability
/// the chosen label claims (Guess 0.50, Pretty sure 0.75, Certain 0.95).
/// This is an affine transform of the Brier score, which is strictly
/// proper: whatever your true chance q of being right, your expected
/// points are highest when you pick the label whose p is nearest q. Saying
/// "Certain" only pays when you really are better than about 85% sure,
/// and "Pretty sure" only beats "Guess" above about 62.5%.
///
///   Right + Guess        ->  +1
///   Right + Pretty sure  -> +76
///   Right + Certain      -> +100
///   Wrong + Guess        ->  +1
///   Wrong + Pretty sure  -> -124
///   Wrong + Certain      -> -260
///
/// Every p is a multiple of 0.05, so the arithmetic is exact in integers:
/// 400 * (m / 100)^2 == m^2 / 25 for m in {5, 25, 50, 75, 95}.
int brierPoints({
  required bool isCorrect,
  required TriviaConfidence confidence,
}) {
  final pct = (confidence.probability * 100).round();
  final miss = isCorrect ? 100 - pct : pct;
  return 101 - (miss * miss) ~/ 25;
}

/// Expected points for reporting [confidence] when the true chance of
/// being right is [q] (0..1). Used by tests to prove honesty wins.
double expectedPoints(TriviaConfidence confidence, double q) =>
    q * brierPoints(isCorrect: true, confidence: confidence) +
    (1 - q) * brierPoints(isCorrect: false, confidence: confidence);

/// Score a single answer with the Brier rule above. A confident miss can
/// cost more than a confident hit earns; the final trivia score can land
/// below zero, which is the shareable joke.
AnswerScore scoreAnswer({
  required bool isCorrect,
  required TriviaConfidence confidence,
}) {
  final points = brierPoints(isCorrect: isCorrect, confidence: confidence);
  if (isCorrect) {
    switch (confidence) {
      case TriviaConfidence.guess:
        return AnswerScore(points: points, reason: 'Right, lucky guess');
      case TriviaConfidence.prettySure:
        return AnswerScore(points: points, reason: 'Right, pretty sure');
      case TriviaConfidence.certain:
        return AnswerScore(points: points, reason: 'Right, and you knew it');
    }
  }
  switch (confidence) {
    case TriviaConfidence.guess:
      return AnswerScore(points: points, reason: 'Wrong, but you said so');
    case TriviaConfidence.prettySure:
      return AnswerScore(points: points, reason: 'Wrong, should have hedged');
    case TriviaConfidence.certain:
      return AnswerScore(points: points, reason: 'Wrong, and you SWORE');
  }
}

/// Per-answer emoji for the share grid. Blue = confident correct, green =
/// hedged correct, orange = honest miss, red = Dunning-Kruger.
String gridEmojiFor({
  required bool isCorrect,
  required TriviaConfidence confidence,
}) {
  if (isCorrect) {
    return confidence == TriviaConfidence.certain ? '🟦' : '🟩';
  }
  return confidence == TriviaConfidence.certain ? '🟥' : '🟧';
}

/// Roll the four archetype thresholds. Cutoffs are tuned so that:
///   - Acing it confidently (correctness ≥ 0.7, avgConf ≥ 2.3) = Scholar
///   - Acing it nervously                                      = Lucky Guesser
///   - Bombing it confidently                                  = Bullshitter
///   - Bombing it humbly                                       = Apprentice
/// Mid-range runs round toward the most-emphatic adjacent archetype so the
/// share artifact always has a definite character.
TriviaArchetype assignArchetype({
  required double accuracy,
  required double averageConfidence,
}) {
  final highScore = accuracy >= 0.6;
  final highConfidence = averageConfidence >= 2.3;
  if (highScore && highConfidence) return TriviaArchetype.civicScholar;
  if (highScore && !highConfidence) return TriviaArchetype.luckyGuesser;
  if (!highScore && highConfidence) return TriviaArchetype.civicBullshitter;
  return TriviaArchetype.humbleApprentice;
}

/// Roll up a list of answers into the final shareable result.
TriviaResult summarize(List<TriviaAnswer> answers) {
  if (answers.isEmpty) {
    return const TriviaResult(
      totalScore: 0,
      correctCount: 0,
      totalQuestions: 0,
      averageConfidence: 1,
      archetype: TriviaArchetype.humbleApprentice,
      gridEmojis: [],
    );
  }
  var total = 0;
  var correct = 0;
  var confSum = 0;
  final grid = <String>[];
  for (final a in answers) {
    final s = scoreAnswer(isCorrect: a.isCorrect, confidence: a.confidence);
    total += s.points;
    if (a.isCorrect) correct++;
    confSum += a.confidence.value;
    grid.add(gridEmojiFor(isCorrect: a.isCorrect, confidence: a.confidence));
  }
  final accuracy = correct / answers.length;
  final avgConf = confSum / answers.length;
  return TriviaResult(
    totalScore: total,
    correctCount: correct,
    totalQuestions: answers.length,
    averageConfidence: avgConf,
    archetype: assignArchetype(
      accuracy: accuracy,
      averageConfidence: avgConf,
    ),
    gridEmojis: grid,
  );
}
