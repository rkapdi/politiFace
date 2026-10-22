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
  group('scoreAnswer: Brier rule', () {
    int pts(bool correct, TriviaConfidence c) =>
        scoreAnswer(isCorrect: correct, confidence: c).points;

    test('labels map to Guess 0.50, Pretty sure 0.75, Certain 0.95', () {
      expect(TriviaConfidence.guess.probability, 0.50);
      expect(TriviaConfidence.prettySure.probability, 0.75);
      expect(TriviaConfidence.certain.probability, 0.95);
    });

    test('points are exactly 101 - 400 * (outcome - p)^2', () {
      for (final c in TriviaConfidence.values) {
        for (final correct in [true, false]) {
          final outcome = correct ? 1.0 : 0.0;
          final d = outcome - c.probability;
          expect(pts(correct, c), (101 - 400 * d * d).round());
        }
      }
    });

    test('the table', () {
      expect(pts(true, TriviaConfidence.guess), 1);
      expect(pts(true, TriviaConfidence.prettySure), 76);
      expect(pts(true, TriviaConfidence.certain), 100);
      expect(pts(false, TriviaConfidence.guess), 1);
      expect(pts(false, TriviaConfidence.prettySure), -124);
      expect(pts(false, TriviaConfidence.certain), -260);
      expect(kMaxPointsPerAnswer, 100);
      expect(maxScoreFor(10), 1000);
    });

    test('honest reporting wins: over q in [0, 1] the best label is the '
        'one whose probability is nearest q', () {
      for (var i = 0; i <= 1000; i++) {
        final q = i / 1000;
        final best = TriviaConfidence.values
            .map((c) => expectedPoints(c, q))
            .reduce((a, b) => a > b ? a : b);
        final nearestDistance = TriviaConfidence.values
            .map((c) => (c.probability - q).abs())
            .reduce((a, b) => a < b ? a : b);
        for (final c in TriviaConfidence.values) {
          final isNearest =
              ((c.probability - q).abs() - nearestDistance).abs() < 1e-9;
          final isBest = (expectedPoints(c, q) - best).abs() < 1e-9;
          // At the exact midpoints (0.625, 0.85) two labels tie on both
          // counts; everywhere else the sets have exactly one member.
          expect(
            isBest,
            isNearest,
            reason: 'q=$q label=${c.name} '
                'expected=${expectedPoints(c, q)} best=$best',
          );
        }
      }
    });

    test('the old matrix rewarded overconfidence; this one does not', () {
      // Old matrix (+5/+10/+15 right, +2/-3/-10 wrong). Certain was the best
      // pick once you were only ~58% sure, and Pretty sure was never worse
      // than Guess from a coin flip up (tied at exactly 50%, ahead above).
      double oldExpected(TriviaConfidence c, double q) {
        const right = {
          TriviaConfidence.guess: 5,
          TriviaConfidence.prettySure: 10,
          TriviaConfidence.certain: 15,
        };
        const wrong = {
          TriviaConfidence.guess: 2,
          TriviaConfidence.prettySure: -3,
          TriviaConfidence.certain: -10,
        };
        return q * right[c]! + (1 - q) * wrong[c]!;
      }

      // Sanity: the old cases really held.
      expect(
        oldExpected(TriviaConfidence.certain, 0.6),
        greaterThan(oldExpected(TriviaConfidence.prettySure, 0.6)),
      );
      expect(
        oldExpected(TriviaConfidence.certain, 0.6),
        greaterThan(oldExpected(TriviaConfidence.guess, 0.6)),
      );
      expect(
        oldExpected(TriviaConfidence.prettySure, 0.5),
        greaterThanOrEqualTo(oldExpected(TriviaConfidence.guess, 0.5)),
      );
      expect(
        oldExpected(TriviaConfidence.prettySure, 0.55),
        greaterThan(oldExpected(TriviaConfidence.guess, 0.55)),
      );

      // And now they do not.
      for (final q in [0.58, 0.6, 0.7, 0.8]) {
        expect(
          expectedPoints(TriviaConfidence.certain, q),
          lessThan(expectedPoints(TriviaConfidence.prettySure, q)),
          reason: 'Certain must not pay at q=$q',
        );
      }
      for (final q in [0.5, 0.55, 0.6]) {
        expect(
          expectedPoints(TriviaConfidence.prettySure, q),
          lessThan(expectedPoints(TriviaConfidence.guess, q)),
          reason: 'Pretty sure must not beat Guess at q=$q',
        );
      }
      expect(
        expectedPoints(TriviaConfidence.certain, 0.6),
        lessThan(expectedPoints(TriviaConfidence.guess, 0.6)),
      );
    });

    test('reason strings are present and distinctive', () {
      // Spot-check that each cell has a unique blurb; the per-question
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

    test('all 10 correct + certain → max 1000', () {
      final answers = List.generate(
        10,
        (_) => _answer(correct: true, confidence: TriviaConfidence.certain),
      );
      final r = summarize(answers);
      expect(r.totalScore, 1000);
      expect(r.maxScore, 1000);
      expect(r.correctCount, 10);
      expect(r.accuracy, 1.0);
      expect(r.averageConfidence, 3.0);
      expect(r.archetype, TriviaArchetype.civicScholar);
      expect(r.gridEmojis, List.filled(10, '🟦'));
    });

    test('all 10 wrong + certain → min -2600, Civic Bullshitter', () {
      final answers = List.generate(
        10,
        (_) => _answer(correct: false, confidence: TriviaConfidence.certain),
      );
      final r = summarize(answers);
      expect(r.totalScore, -2600);
      expect(r.correctCount, 0);
      expect(r.accuracy, 0.0);
      expect(r.averageConfidence, 3.0);
      expect(r.archetype, TriviaArchetype.civicBullshitter);
      expect(r.gridEmojis, List.filled(10, '🟥'));
    });

    test('hedged perfect run → 760 score, Lucky Guesser', () {
      // Pretty Sure × 10 correct = 10×76 = 760; avgConf 2.0 < 2.3 → Lucky.
      final answers = List.generate(
        10,
        (_) =>
            _answer(correct: true, confidence: TriviaConfidence.prettySure),
      );
      final r = summarize(answers);
      expect(r.totalScore, 760);
      expect(r.isStrongScore, isTrue);
      expect(r.archetype, TriviaArchetype.luckyGuesser);
    });

    test('mixed run lands a sensible archetype', () {
      // 6 correct hedged + 4 wrong guessed = 6×76 + 4×1 = 460 score, accuracy
      // 0.6 (just at threshold), avg conf = (6×2 + 4×1)/10 = 1.6 → Lucky.
      final answers = <TriviaAnswer>[
        for (var i = 0; i < 6; i++)
          _answer(correct: true, confidence: TriviaConfidence.prettySure),
        for (var i = 0; i < 4; i++)
          _answer(correct: false, confidence: TriviaConfidence.guess),
      ];
      final r = summarize(answers);
      expect(r.totalScore, 460);
      expect(r.correctCount, 6);
      expect(r.archetype, TriviaArchetype.luckyGuesser);
    });
  });
}
