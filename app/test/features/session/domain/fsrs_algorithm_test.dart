// test/features/session/domain/fsrs_algorithm_test.dart
//
// Full unit test suite for FSRS-4.5.
// Run: flutter test test/features/session/domain/fsrs_algorithm_test.dart
//
// These tests must pass before any UI work begins.
// Bugs in the scheduling algorithm cause silent churn — users just stop returning.

import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/session/domain/fsrs_algorithm.dart';

void main() {
  const fsrs = FSRS();

  group('FSRS Initial Scheduling (new cards)', () {
    test('again: low stability, high difficulty', () {
      final result = fsrs.scheduleNew(grade: FSRSGrade.again);
      expect(result.intervalDays, equals(1));
      expect(result.nextState.difficulty, greaterThan(6.0));
      expect(result.nextState.stability, lessThan(2.0));
      expect(result.nextState.lapses, equals(1));
      expect(result.nextState.reviewCount, equals(1));
    });

    test('hard: low-moderate stability', () {
      final result = fsrs.scheduleNew(grade: FSRSGrade.hard);
      expect(result.intervalDays, greaterThanOrEqualTo(1));
      expect(result.nextState.stability, lessThan(5.0));
      expect(result.nextState.lapses, equals(0));
    });

    test('good: moderate stability', () {
      final result = fsrs.scheduleNew(grade: FSRSGrade.good);
      expect(result.intervalDays, greaterThan(1));
      expect(result.nextState.stability, greaterThan(2.0));
      expect(result.nextState.lapses, equals(0));
    });

    test('easy: high stability, long interval', () {
      final result = fsrs.scheduleNew(grade: FSRSGrade.easy);
      expect(result.intervalDays, greaterThan(10));
      expect(result.nextState.stability, greaterThan(10.0));
      expect(result.nextState.lapses, equals(0));
    });

    test('difficulty is clamped to 1.0-10.0', () {
      for (final grade in FSRSGrade.values) {
        final result = fsrs.scheduleNew(grade: grade);
        expect(result.nextState.difficulty, greaterThanOrEqualTo(1.0));
        expect(result.nextState.difficulty, lessThanOrEqualTo(10.0));
      }
    });

    test('stability is always positive', () {
      for (final grade in FSRSGrade.values) {
        final result = fsrs.scheduleNew(grade: grade);
        expect(result.nextState.stability, greaterThan(0.0));
      }
    });

    test('interval is always at least 1 day', () {
      for (final grade in FSRSGrade.values) {
        final result = fsrs.scheduleNew(grade: grade);
        expect(result.intervalDays, greaterThanOrEqualTo(1));
      }
    });

    test('nextReviewAt is in the future', () {
      for (final grade in FSRSGrade.values) {
        final result = fsrs.scheduleNew(grade: grade);
        expect(result.nextReviewAt.isAfter(DateTime.now()), isTrue);
      }
    });
  });

  group('FSRS Review Scheduling (repeat reviews)', () {
    const wellLearnedState = MemoryState(
      difficulty: 4,
      stability: 30,
      retrievability: 0.9,
      lapses: 0,
      reviewCount: 10,
    );

    final lastReview = DateTime.now().subtract(const Duration(days: 30));

    test('good review increases stability', () {
      final before = wellLearnedState.stability;
      final result = fsrs.schedule(
        current: wellLearnedState,
        grade: FSRSGrade.good,
        lastReviewedAt: lastReview,
      );
      expect(result.nextState.stability, greaterThan(before));
    });

    test('again review decreases stability', () {
      final before = wellLearnedState.stability;
      final result = fsrs.schedule(
        current: wellLearnedState,
        grade: FSRSGrade.again,
        lastReviewedAt: lastReview,
      );
      expect(result.nextState.stability, lessThan(before));
    });

    test('again increments lapses', () {
      final result = fsrs.schedule(
        current: wellLearnedState,
        grade: FSRSGrade.again,
        lastReviewedAt: lastReview,
      );
      expect(result.nextState.lapses, equals(wellLearnedState.lapses + 1));
    });

    test('good/hard/easy do not increment lapses', () {
      for (final grade in [FSRSGrade.hard, FSRSGrade.good, FSRSGrade.easy]) {
        final result = fsrs.schedule(
          current: wellLearnedState,
          grade: grade,
          lastReviewedAt: lastReview,
        );
        expect(result.nextState.lapses, equals(wellLearnedState.lapses));
      }
    });

    test('easy gives longer interval than good', () {
      final goodResult = fsrs.schedule(
        current: wellLearnedState, grade: FSRSGrade.good, lastReviewedAt: lastReview,);
      final easyResult = fsrs.schedule(
        current: wellLearnedState, grade: FSRSGrade.easy, lastReviewedAt: lastReview,);
      expect(easyResult.intervalDays, greaterThan(goodResult.intervalDays));
    });

    test('hard gives shorter interval than good', () {
      final hardResult = fsrs.schedule(
        current: wellLearnedState, grade: FSRSGrade.hard, lastReviewedAt: lastReview,);
      final goodResult = fsrs.schedule(
        current: wellLearnedState, grade: FSRSGrade.good, lastReviewedAt: lastReview,);
      expect(hardResult.intervalDays, lessThanOrEqualTo(goodResult.intervalDays));
    });

    test('reviewCount always increments', () {
      for (final grade in FSRSGrade.values) {
        final result = fsrs.schedule(
          current: wellLearnedState,
          grade: grade,
          lastReviewedAt: lastReview,
        );
        expect(result.nextState.reviewCount, equals(wellLearnedState.reviewCount + 1));
      }
    });
  });

  group('FSRS Edge Cases', () {
    test('zero elapsed days does not crash', () {
      const state = MemoryState(
        difficulty: 5, stability: 5, retrievability: 1,
        lapses: 0, reviewCount: 1,
      );
      expect(
        () => fsrs.schedule(
          current: state,
          grade: FSRSGrade.good,
          lastReviewedAt: DateTime.now(),
        ),
        returnsNormally,
      );
    });

    test('very high stability does not produce infinite interval', () {
      const state = MemoryState(
        difficulty: 1, stability: 36500, retrievability: 0.9,
        lapses: 0, reviewCount: 100,
      );
      final result = fsrs.schedule(
        current: state, grade: FSRSGrade.good,
        lastReviewedAt: DateTime.now().subtract(const Duration(days: 36500)),
      );
      expect(result.intervalDays, lessThan(100000));
      expect(result.nextState.stability, lessThanOrEqualTo(36500.0));
    });

    test('very low stability (near 0) does not crash', () {
      const state = MemoryState(
        difficulty: 10, stability: 0.1, retrievability: 0.1,
        lapses: 50, reviewCount: 55,
      );
      expect(
        () => fsrs.schedule(
          current: state,
          grade: FSRSGrade.again,
          lastReviewedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        returnsNormally,
      );
    });

    test('retrievability is always between 0 and 1', () {
      const state = MemoryState(
        difficulty: 5, stability: 10, retrievability: 0.9,
        lapses: 0, reviewCount: 5,
      );
      for (final grade in FSRSGrade.values) {
        final result = fsrs.schedule(
          current: state, grade: grade,
          lastReviewedAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        expect(result.nextState.retrievability, greaterThanOrEqualTo(0.0));
        expect(result.nextState.retrievability, lessThanOrEqualTo(1.0));
      }
    });

    test('difficulty stays clamped through repeated again grades', () {
      var state = MemoryState.initial;
      for (var i = 0; i < 20; i++) {
        final result = fsrs.schedule(
          current: state,
          grade: FSRSGrade.again,
          lastReviewedAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        state = result.nextState;
        expect(state.difficulty, greaterThanOrEqualTo(1.0));
        expect(state.difficulty, lessThanOrEqualTo(10.0));
      }
    });

    test('100 alternating good/again reviews does not crash', () {
      var state = MemoryState.initial;
      var lastReview = DateTime.now().subtract(const Duration(days: 1));
      for (var i = 0; i < 100; i++) {
        final grade = i.isEven ? FSRSGrade.good : FSRSGrade.again;
        final result = fsrs.schedule(
          current: state, grade: grade, lastReviewedAt: lastReview,);
        state = result.nextState;
        lastReview = result.nextReviewAt.subtract(const Duration(days: 1));
        expect(state.stability, greaterThan(0.0));
        expect(result.intervalDays, greaterThanOrEqualTo(1));
      }
    });
  });

  group('FSRS Retrievability', () {
    test('retrievability at day 0 is near 1.0', () {
      expect(fsrs.retrievability(0, 10), closeTo(1.0, 0.01));
    });

    test('retrievability decreases over time', () {
      final r10 = fsrs.retrievability(10, 20);
      final r20 = fsrs.retrievability(20, 20);
      expect(r10, greaterThan(r20));
    });

    test('higher stability means higher retrievability at same elapsed time', () {
      final lowStability  = fsrs.retrievability(30, 10);
      final highStability = fsrs.retrievability(30, 60);
      expect(highStability, greaterThan(lowStability));
    });

    test('retrievabilityCurve matches the integer version at whole days', () {
      for (final day in [0, 1, 5, 30]) {
        expect(
          fsrs.retrievabilityCurve(day.toDouble(), 20),
          closeTo(fsrs.retrievability(day, 20), 1e-9),
        );
      }
    });

    test('retrievabilityCurve is monotonic across fractional days', () {
      final r05 = fsrs.retrievabilityCurve(0.5, 10);
      final r15 = fsrs.retrievabilityCurve(1.5, 10);
      final r25 = fsrs.retrievabilityCurve(2.5, 10);
      expect(r05, greaterThan(r15));
      expect(r15, greaterThan(r25));
      expect(r05, lessThan(1.0));
    });

    test('retrievabilityCurve crosses ~0.9 near one stability interval', () {
      // By construction, R reaches the 0.9 review target at t ≈ S.
      expect(fsrs.retrievabilityCurve(10, 10), closeTo(0.9, 0.01));
    });
  });

  group('FSRS Personalized Weights', () {
    test('custom weights produce valid results', () {
      // Slightly modified weights — still 17 values
      final customWeights = List<double>.from(FSRS.defaultWeights)
        ..[8] = 2.0  // increase recall stability gain
        ..[11] = 0.5; // decrease lapse stability

      final customFSRS = FSRS(w: customWeights);
      final result = customFSRS.scheduleNew(grade: FSRSGrade.good);
      expect(result.intervalDays, greaterThanOrEqualTo(1));
      expect(result.nextState.stability, greaterThan(0.0));
    });
  });
}
