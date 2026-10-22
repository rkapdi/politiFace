import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/trivia/domain/calibration.dart';
import 'package:politiface/features/trivia/domain/trivia_question.dart';

ConfidenceOutcome _o(TriviaConfidence c, bool correct) =>
    ConfidenceOutcome(confidence: c, correct: correct);

void main() {
  test('empty when no answer carried a confidence', () {
    expect(calibrate(const []), isEmpty);
  });

  test('only labels used, in Guess, Pretty sure, Certain order', () {
    final rows = calibrate([
      _o(TriviaConfidence.certain, true),
      _o(TriviaConfidence.guess, false),
      _o(TriviaConfidence.certain, false),
    ]);
    expect(rows.map((r) => r.confidence), [
      TriviaConfidence.guess,
      TriviaConfidence.certain,
    ]);
    expect(rows.last.answered, 2);
    expect(rows.last.correct, 1);
    expect(rows.last.percentRight, 50);
  });

  test('sentence reads plainly and rounds the percent', () {
    final rows = calibrate([
      _o(TriviaConfidence.prettySure, true),
      _o(TriviaConfidence.prettySure, true),
      _o(TriviaConfidence.prettySure, false),
    ]);
    expect(
      rows.single.sentence,
      'When you said Pretty sure, you were right 67% of the time (2 of 3).',
    );
  });

  test('wire values match the server vocabulary', () {
    expect(
      TriviaConfidence.values.map((c) => c.wireValue),
      ['guess', 'pretty_sure', 'certain'],
    );
    expect(TriviaConfidence.fromWire('pretty_sure'), TriviaConfidence.prettySure);
    expect(TriviaConfidence.fromWire('nope'), isNull);
    expect(TriviaConfidence.fromWire(null), isNull);
  });
}
