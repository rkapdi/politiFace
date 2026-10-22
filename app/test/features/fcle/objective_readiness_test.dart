import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/application/objective_readiness.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';

ObjectiveReadiness _r(
  String code,
  FcleDomain domain, {
  double? accuracy,
  int count = 0,
}) =>
    ObjectiveReadiness(
      code: code,
      domain: domain,
      description: code,
      accuracy: accuracy,
      count: count,
      state: readinessStateFor(accuracy: accuracy, count: count),
    );

Map<String, ObjectiveReadiness> _byCode(List<ObjectiveReadiness> list) =>
    {for (final o in list) o.code: o};

void main() {
  group('readinessStateFor thresholds', () {
    test('count 0 is unseen regardless of accuracy', () {
      expect(readinessStateFor(accuracy: null, count: 0),
          ReadinessState.unseen,);
      expect(readinessStateFor(accuracy: 1, count: 0), ReadinessState.unseen);
    });

    test('count 1..3 is practicing regardless of accuracy', () {
      for (final c in [1, 2, 3]) {
        expect(readinessStateFor(accuracy: 0, count: c),
            ReadinessState.practicing, reason: 'count $c',);
        expect(readinessStateFor(accuracy: 1, count: c),
            ReadinessState.practicing, reason: 'count $c',);
      }
    });

    test('count 3 vs 4 boundary: 3 practicing, 4 graded', () {
      expect(readinessStateFor(accuracy: 0.5, count: 3),
          ReadinessState.practicing,);
      expect(readinessStateFor(accuracy: 0.5, count: 4),
          ReadinessState.needsWork,);
    });

    test('accuracy 0.70 boundary at count>=4', () {
      // Just below 0.70 is needsWork; exactly 0.70 crosses into onTrack.
      expect(readinessStateFor(accuracy: 0.69, count: 4),
          ReadinessState.needsWork,);
      expect(readinessStateFor(accuracy: 0.70, count: 4),
          ReadinessState.onTrack,);
    });

    test('accuracy 0.85 boundary at count>=4', () {
      // Just below 0.85 is onTrack; exactly 0.85 crosses into solid.
      expect(readinessStateFor(accuracy: 0.84, count: 4),
          ReadinessState.onTrack,);
      expect(readinessStateFor(accuracy: 0.85, count: 10),
          ReadinessState.solid,);
      expect(readinessStateFor(accuracy: 1, count: 10), ReadinessState.solid);
    });

    test('thresholds sit above the 60% pass line', () {
      // A "pass-line" 0.62 accuracy is only onTrack here, never solid.
      expect(readinessStateFor(accuracy: 0.62, count: 4),
          ReadinessState.needsWork,);
    });
  });

  group('aggregateExamReadiness', () {
    test('empty history: justStarting, focus the domain with most unseen', () {
      // American Democracy has more objectives, so it has the most unseen.
      final map = _byCode([
        _r('a1', FcleDomain.americanDemocracy),
        _r('a2', FcleDomain.americanDemocracy),
        _r('a3', FcleDomain.americanDemocracy),
        _r('c1', FcleDomain.usConstitution),
      ]);
      final exam = aggregateExamReadiness(map);
      expect(exam.covered, 0);
      expect(exam.total, 4);
      expect(exam.unseen, 4);
      expect(exam.overallState, ExamOverallState.justStarting);
      expect(exam.focusNext, isNotNull);
      expect(exam.focusNext!.isObjective, isFalse);
      expect(exam.focusNext!.domain, FcleDomain.americanDemocracy);
    });

    test('focusNext picks the weakest graded objective (count>=4)', () {
      final map = _byCode([
        _r('weak', FcleDomain.usConstitution, accuracy: 0.5, count: 6),
        _r('mid', FcleDomain.usConstitution, accuracy: 0.75, count: 8),
        // Lower accuracy but too few attempts to be trusted -> ignored.
        _r('few', FcleDomain.americanDemocracy, accuracy: 0.1, count: 2),
      ]);
      final exam = aggregateExamReadiness(map);
      expect(exam.focusNext!.isObjective, isTrue);
      expect(exam.focusNext!.objective!.code, 'weak');
      expect(exam.needsWork, 1);
      expect(exam.covered, 3);
    });

    test('strongAcrossTheBoard needs a solid in every domain + high coverage',
        () {
      // Four objectives, all solid, one per domain -> strong.
      final map = _byCode([
        _r('a', FcleDomain.americanDemocracy, accuracy: 0.9, count: 10),
        _r('b', FcleDomain.usConstitution, accuracy: 0.95, count: 10),
        _r('c', FcleDomain.foundingDocuments, accuracy: 1, count: 10),
        _r('d', FcleDomain.landmarkImpact, accuracy: 0.88, count: 10),
      ]);
      final exam = aggregateExamReadiness(map);
      expect(exam.solid, 4);
      expect(exam.overallState, ExamOverallState.strongAcrossTheBoard);
    });

    test('high coverage but a domain lacks a solid -> mostAreasCovered', () {
      final map = _byCode([
        _r('a', FcleDomain.americanDemocracy, accuracy: 0.9, count: 10),
        _r('b', FcleDomain.usConstitution, accuracy: 0.95, count: 10),
        _r('c', FcleDomain.foundingDocuments, accuracy: 0.72, count: 10),
        _r('d', FcleDomain.landmarkImpact, accuracy: 0.5, count: 10),
      ]);
      final exam = aggregateExamReadiness(map);
      expect(exam.overallState, ExamOverallState.mostAreasCovered);
    });

    test('partial coverage below half -> buildingCoverage', () {
      final map = _byCode([
        _r('a', FcleDomain.americanDemocracy, accuracy: 0.9, count: 10),
        _r('b', FcleDomain.usConstitution),
        _r('c', FcleDomain.foundingDocuments),
        _r('d', FcleDomain.landmarkImpact),
        _r('e', FcleDomain.landmarkImpact),
      ]);
      final exam = aggregateExamReadiness(map);
      expect(exam.covered, 1);
      expect(exam.overallState, ExamOverallState.buildingCoverage);
    });
  });
}
