/// The four question formats. All use the same 4-option MCQ shape; only the
/// prompt + answer slot differs.
enum TriviaFormat {
  /// Show a photo. Pick the name.
  photoToName,

  /// Show a photo. Pick the title.
  photoToTitle,

  /// Show a title (e.g. "Secretary of the Treasury"). Pick the name.
  titleToName,

  /// Show a name. Pick the title.
  nameToTitle,
}

/// One question + its four MCQ options + the index of the correct one.
class TriviaQuestion {
  const TriviaQuestion({
    required this.cardId,
    required this.format,
    required this.prompt,
    required this.photoUrl,
    required this.options,
    required this.correctIndex,
  });

  /// The card this question is "about" — used by news weighting and to keep
  /// the daily picker from repeating a card across multiple questions.
  final String cardId;

  final TriviaFormat format;

  /// Text prompt to render above the photo (e.g. "Who is this?"). For
  /// photo-prompted formats this stays generic; for text-prompted formats
  /// this is the full prompt string.
  final String prompt;

  /// Photo to display, or null if the prompt is purely textual.
  final String? photoUrl;

  /// Always 4 entries.
  final List<String> options;

  /// 0..3
  final int correctIndex;

  bool isCorrect(int answerIndex) => answerIndex == correctIndex;
}

/// User-facing confidence levels. Three buckets keeps the per-question UX
/// to two taps and reads instantly on screen.
enum TriviaConfidence {
  /// "I'm guessing."
  guess(label: 'Guess', value: 1),

  /// "Pretty sure."
  prettySure(label: 'Pretty Sure', value: 2),

  /// "I know this 100%."
  certain(label: '100%', value: 3);

  const TriviaConfidence({required this.label, required this.value});
  final String label;
  final int value;
}

/// A single graded answer.
class TriviaAnswer {
  const TriviaAnswer({
    required this.question,
    required this.answerIndex,
    required this.confidence,
  });

  final TriviaQuestion question;
  final int answerIndex;
  final TriviaConfidence confidence;

  bool get isCorrect => question.isCorrect(answerIndex);
}
