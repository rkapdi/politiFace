import 'endless_question.dart';

/// A single answered question kept in the endless run's review log. Caps at
/// 50 entries in [EndlessState] to bound memory while still showing a
/// meaningful "what did I just play" review screen.
class EndlessAnswer {
  const EndlessAnswer({
    required this.question,
    required this.pickedIndex,
  });

  final EndlessQuestion question;
  final int pickedIndex;

  bool get isCorrect => pickedIndex == question.correctIndex;
}
