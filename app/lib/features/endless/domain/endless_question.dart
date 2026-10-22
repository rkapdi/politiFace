import '../../../core/database/drift/app_database.dart';

/// Four MCQ exercise variants over the same card data.
enum QuestionMode {
  photoToName,   // Show face. Pick the right name.
  nameToPhoto,   // Show name. Pick the right face.
  titleToWho,    // Show title (e.g. "Attorney General"). Pick the right face.
  photoToTitle,  // Show face. Pick the right title.
}

/// A single MCQ. [options] has length 4; [correctIndex] points to the correct
/// one. The "prompt" is implied by [mode] — UI decides what to render based
/// on it.
class EndlessQuestion {
  const EndlessQuestion({
    required this.mode,
    required this.correct,
    required this.options,
    required this.correctIndex,
  });

  final QuestionMode mode;
  final LocalCard correct;
  final List<LocalCard> options;
  final int correctIndex;
}
