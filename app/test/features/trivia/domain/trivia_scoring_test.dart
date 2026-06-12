import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/trivia/domain/trivia_question.dart';
import 'package:politiface/features/trivia/domain/trivia_scoring.dart';

TriviaQuestion _question({int correctIndex = 0}) => TriviaQuestion(
    cardId: 'c',
    format: TriviaFormat.photoToName,
    prompt: 'Who is this?',
    photoUrl: null,
    options: const ['A', 'B', 'C', 'D'],
    correctIndex: correctIndex,
  );

TriviaAnswer _answer({
  required bool correct,
  required TriviaConfidence confidence,
}) => TriviaAnswer(
    question: _question(),
    answerIndex: correct ? 0 : 1,
    confidence: confidence,
  );

void main() {
  group('scoreAnswer matrix', () {
    test('correct + guess = +5', () {
      final s = scoreAnswer(
        isCorrect: true,
        confidence: TriviaConfidence.guess,
      );
      expect(s.points, 5);
    });
    test('correct + pretty sure = +10', () {
      expect(
        scoreAnswer(isCorrect: true, confidence: TriviaConfidence.prettySure)
            .points,
        10,
      );
    });
    test('correct + certain = +15', () {
      expect(
        scoreAnswer(isCorrect: true, confidence: TriviaConfidence.certain)
            .points,
        15,
      );
    });
    test('wrong + guess = +2 (the honest miss)', () {
      expect(
        scoreAnswer(isCorrect: false, confidence: TriviaConfidence.guess)
            .points,
        2,
      );
    });
    test('wrong + pretty sure = -3', () {
      expect(
        scoreAnswer(isCorrect: false, confidence: TriviaConfidence.prettySure)
            .points,
        -3,
      );
    });
    test('wrong + certain = -10 (Dunning-Kruger)', () {
      expect(
        scoreAnswer(isCorrect: false, confidence: TriviaConfidence.certain)
            .points,
        -10,
      );
    });

    test('reason strings are present and distinctive', () {
      // Spot-check that each cell has a unique blurb — the per-question
      // reveal animations key off these.
      final reasons = <String>{
        for (final isCorrect in [true, false])
          for (final c in TriviaConfidence.values)
            scoreAnswer(isCorrect: isCorrect, confidence: c).reason,
      };
      expect(reasons.length, 6);
    });
  });

  group('gridEmojiFor', () {
    test('certain right → blue', () {
      expect(
        gridEmojiFor(isCorrect: true, confidence: TriviaConfidence.certain),
        '🟦',
      );
    });
    test('hedged right → green', () {
      expect(
        gridEmojiFor(isCorrect: true, confidence: TriviaConfidence.prettySure),
        '🟩',
      );
      expect(
        gridEmojiFor(isCorrect: true, confidence: TriviaConfidence.guess),
        '🟩',
      );
    });
    test('honest miss → orange', () {
      expect(
        gridEmojiFor(isCorrect: false, confidence: TriviaConfidence.guess),
        '🟧',
      );
      expect(
        gridEmojiFor(isCorrect: false, confidence: TriviaConfidence.prettySure),
        '🟧',
      );
    });
    test('Dunning-Kruger → red', () {
      expect(
        gridEmojiFor(isCorrect: false, confidence: TriviaConfidence.certain),
        '🟥',
      );
    });
  });

  group('assignArchetype thresholds', () {
    test('high accuracy + high confidence → Civic Scholar', () {
      final a = assignArchetype(accuracy: 0.9, averageConfidence: 2.5);
      expect(a, TriviaArchetype.civicScholar);
    });
    test('high accuracy + low confidence → Lucky Guesser', () {
      final a = assignArchetype(accuracy: 0.9, averageConfidence: 1.6);
      expect(a, TriviaArchetype.luckyGuesser);
    });
    test('low accuracy + high confidence → Civic Bullshitter', () {
      final a = assignArchetype(accuracy: 0.2, averageConfidence: 2.8);
      expect(a, TriviaArchetype.civicBullshitter);
    });
    test('low accuracy + low confidence → Humble Apprentice', () {
      final a = assignArchetype(accuracy: 0.2, averageConfidence: 1.2);
      expect(a, TriviaArchetype.humbleApprentice);
    });
    test('exact 0.6 accuracy + exact 2.3 confidence → Scholar', () {
      // Both thresholds are inclusive on the "high" side.
      final a = assignArchetype(accuracy: 0.6, averageConfidence: 2.3);
      expect(a, TriviaArchetype.civicScholar);
    });
  });

  group('summarize end-to-end', () {
    test('empty answers → safe default', () {
      final r = summarize(const []);
      expect(r.totalQuestions, 0);
      expect(r.totalScore, 0);
      expect(r.archetype, TriviaArchetype.humbleApprentice);
      expect(r.gridEmojis, isEmpty);
    });

    test('all 10 correct + certain → max 150', () {
      final answers = List.generate(
        10,
        (_) => _answer(correct: true, confidence: TriviaConfidence.certain),
      );
      final r = summarize(answers);
      expect(r.totalScore, 150);
      expect(r.correctCount, 10);
      expect(r.accuracy, 1.0);
      expect(r.averageConfidence, 3.0);
      expect(r.archetype, TriviaArchetype.civicScholar);
      expect(r.gridEmojis, List.filled(10, '🟦'));
    });

    test('all 10 wrong + certain → min -100, Civic Bullshitter', () {
      final answers = List.generate(
        10,
        (_) => _answer(correct: false, confidence: TriviaConfidence.certain),
      );
      final r = summarize(answers);
      expect(r.totalScore, -100);
      expect(r.correctCount, 0);
      expect(r.accuracy, 0.0);
      expect(r.averageConfidence, 3.0);
      expect(r.archetype, TriviaArchetype.civicBullshitter);
      expect(r.gridEmojis, List.filled(10, '🟥'));
    });

    test('hedged perfect run → 100 score, Lucky Guesser', () {
      // 10 correct on Guess confidence = 10×5 = 50? No, that's low.
      // Pretty Sure × 10 correct = 100 score; avgConf 2.0 < 2.3 → Lucky.
      final answers = List.generate(
        10,
        (_) =>
            _answer(correct: true, confidence: TriviaConfidence.prettySure),
      );
      final r = summarize(answers);
      expect(r.totalScore, 100);
      expect(r.archetype, TriviaArchetype.luckyGuesser);
    });

    test('mixed run lands a sensible archetype', () {
      // 6 correct hedged + 4 wrong guessed = 6×10 + 4×2 = 68 score, accuracy
      // 0.6 (just at threshold), avg conf = (6×2 + 4×1)/10 = 1.6 → Lucky.
      final answers = <TriviaAnswer>[
        for (var i = 0; i < 6; i++)
          _answer(correct: true, confidence: TriviaConfidence.prettySure),
        for (var i = 0; i < 4; i++)
          _answer(correct: false, confidence: TriviaConfidence.guess),
      ];
      final r = summarize(answers);
      expect(r.totalScore, 68);
      expect(r.correctCount, 6);
      expect(r.archetype, TriviaArchetype.luckyGuesser);
    });
  });
}
