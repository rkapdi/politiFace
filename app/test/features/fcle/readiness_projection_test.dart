import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/domain/readiness_projection.dart';
import 'package:politiface/features/home/application/home_providers.dart';
import 'package:politiface/features/home/presentation/home_screen.dart';
import 'package:politiface/features/shared/widgets/neo/neo_kit.dart';

void main() {
  group('projectScore', () {
    test('needs a minimum of evidence before saying anything', () {
      expect(
        projectScore(const [
          (correct: 3, count: 3),
          (correct: 2, count: 4),
          (correct: 0, count: 0),
          (correct: 0, count: 0),
        ]),
        isNull,
      );
    });

    test('a cold 8/10 diagnostic projects wide and humble, never "ready"',
        () {
      // 3/3, 3/3, 1/2, 1/2: the exact case from beta feedback where the
      // old formula projected 53-73 and lit the "ready" chip.
      final p = projectScore(const [
        (correct: 3, count: 3),
        (correct: 3, count: 3),
        (correct: 1, count: 2),
        (correct: 1, count: 2),
      ]);
      expect(p, isNotNull);
      expect(p!.low, 21);
      expect(p.high, 53);
      // Never "ready" from 10 answers: ready needs low >= 48.
      expect(p.low < 48, isTrue);
    });

    test('an aced single domain cannot carry the projection', () {
      final p = projectScore(const [
        (correct: 8, count: 8),
        (correct: 0, count: 0),
        (correct: 0, count: 0),
        (correct: 0, count: 0),
      ]);
      expect(p, isNotNull);
      expect(p!.low < 48, isTrue);
    });

    test('sustained high accuracy across all domains earns locked in', () {
      final p = projectScore(const [
        (correct: 45, count: 50),
        (correct: 45, count: 50),
        (correct: 45, count: 50),
        (correct: 45, count: 50),
      ]);
      expect(p!.low, 58);
      expect(p.high, 70);
    });

    test('an all-wrong diagnostic lands clearly below the pass line', () {
      final p = projectScore(const [
        (correct: 0, count: 3),
        (correct: 0, count: 3),
        (correct: 0, count: 2),
        (correct: 0, count: 2),
      ]);
      expect(p!.high < 48, isTrue);
    });
  });

  group('fallbackProjection', () {
    test('mirrors the shrunk math when only a pooled score is known', () {
      final p = fallbackProjection(8, 10);
      expect(p.low, 22);
      expect(p.high, 54);
    });
  });

  group('stageFor thresholds', () {
    ReadinessSummary s(int low, int high) => ReadinessSummary(
          low: low,
          high: high,
          perDomain: const {},
          totalAnswers: 100,
        );

    test('locked in requires the LOW bound at 58', () {
      expect(ReadinessHero.stageFor(s(58, 70)), ReadinessStage.lockedIn);
      expect(ReadinessHero.stageFor(s(57, 80)), isNot(ReadinessStage.lockedIn));
    });

    test('ready requires the LOW bound past the pass line', () {
      expect(ReadinessHero.stageFor(s(48, 60)), ReadinessStage.ready);
      expect(ReadinessHero.stageFor(s(21, 53)), ReadinessStage.onTrack);
      expect(ReadinessHero.stageFor(s(11, 43)), ReadinessStage.notYet);
    });
  });
}
