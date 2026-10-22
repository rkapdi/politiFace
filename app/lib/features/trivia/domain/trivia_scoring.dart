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
}

/// Score a single answer using the confidence-weighted matrix.
///
///   Correct + Guess        → +5   (lucky)
///   Correct + Pretty Sure  → +10  (solid)
///   Correct + 100%         → +15  (knew it cold)
///   Wrong   + Guess        → +2   (honest "no idea")
///   Wrong   + Pretty Sure  → -3   (mild penalty)
///   Wrong   + 100%         → -10  (Dunning-Kruger)
///
/// The negative ceiling is the whole point — final score can land below
/// zero, which is the shareable joke.
AnswerScore scoreAnswer({
  required bool isCorrect,
  required TriviaConfidence confidence,
}) {
  if (isCorrect) {
    switch (confidence) {
      case TriviaConfidence.guess:
        return const AnswerScore(points: 5, reason: 'Right, lucky guess');
      case TriviaConfidence.prettySure:
        return const AnswerScore(points: 10, reason: 'Right, pretty sure');
      case TriviaConfidence.certain:
        return const AnswerScore(points: 15, reason: 'Right, and you knew it');
    }
  }
  switch (confidence) {
    case TriviaConfidence.guess:
      return const AnswerScore(points: 2, reason: 'Wrong, but you said so');
    case TriviaConfidence.prettySure:
      return const AnswerScore(points: -3, reason: 'Wrong, should have hedged');
    case TriviaConfidence.certain:
      return const AnswerScore(points: -10, reason: 'Wrong, and you SWORE');
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
