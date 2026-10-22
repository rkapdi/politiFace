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
///
/// Each label maps to the probability of being right it stands for. The
/// trivia score is a proper scoring rule over these probabilities (see
/// trivia_scoring.dart), so reporting how sure you really are is always
/// the best strategy. FCLE, mock and live answers record the same labels as
/// metadata only ([wireValue]); they never change grading or scheduling.
enum TriviaConfidence {
  /// "I'm guessing."
  guess(
    label: 'Guess',
    plainLabel: 'Guess',
    wireValue: 'guess',
    probability: 0.50,
    value: 1,
  ),

  /// "Pretty sure."
  prettySure(
    label: 'Pretty Sure',
    plainLabel: 'Pretty sure',
    wireValue: 'pretty_sure',
    probability: 0.75,
    value: 2,
  ),

  /// "I know this."
  certain(
    label: '100%',
    plainLabel: 'Certain',
    wireValue: 'certain',
    probability: 0.95,
    value: 3,
  );

  const TriviaConfidence({
    required this.label,
    required this.plainLabel,
    required this.wireValue,
    required this.probability,
    required this.value,
  });

  /// Button text on the trivia game surfaces.
  final String label;

  /// Sentence-case name for institutional surfaces and calibration copy
  /// ("When you said Certain, ...").
  final String plainLabel;

  /// Server vocabulary (events.confidence / live_answers.confidence).
  final String wireValue;

  /// The chance of being right this label claims. Drives the trivia score.
  final double probability;

  /// 1..3 ordinal, used for the archetype's average confidence.
  final int value;

  static TriviaConfidence? fromWire(String? wire) {
    for (final c in values) {
      if (c.wireValue == wire) return c;
    }
    return null;
  }
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
