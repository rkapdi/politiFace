import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/mock_engine.dart';

FcleQuestion _q(FcleDomain d, int i) => FcleQuestion(
      id: '${d.code}-$i',
      domain: d,
      stem: 'Question $i of ${d.code}?',
      options: const [
        FcleOption(key: 'a', text: 'A'),
        FcleOption(key: 'b', text: 'B'),
      ],
      answerKey: 'b',
      explanation: 'Because b.',
      citation: 'https://example.gov',
      difficulty: 3,
    );

QuestionBank _bank(int perDomain) => QuestionBank({
      for (final d in FcleDomain.values)
        d: [for (var i = 0; i < perDomain; i++) _q(d, i)],
    });

void main() {
  const engine = MockEngine();

  test('bank knows when a mock is possible', () {
    expect(_bank(19).canAssembleMock, isFalse);
    expect(_bank(20).canAssembleMock, isTrue);
    expect(_bank(19).mockBankProgress, 76);
    expect(_bank(25).mockBankProgress, 80);
  });

  test('assembles 80 questions, 20 per domain, in domain order, no repeats',
      () {
    final assembly = engine.assemble(_bank(25), random: Random(7));
    expect(assembly.questions.length, 80);
    expect(assembly.questions.map((q) => q.id).toSet().length, 80);
    for (var i = 0; i < 4; i++) {
      final section = assembly.questions.sublist(i * 20, (i + 1) * 20);
      expect(
        section.every((q) => q.domain == FcleDomain.values[i]),
        isTrue,
        reason: 'section $i must be all ${FcleDomain.values[i].code}',
      );
    }
  });

  test('throws when a domain is short', () {
    expect(() => engine.assemble(_bank(19)), throwsStateError);
  });

  test('grades score, pass line, and per-domain breakdown', () {
    final assembly = engine.assemble(_bank(20), random: Random(1));
    // 56 correct answers, the rest wrong; unanswered count as wrong.
    final answers = <String, String>{};
    for (var i = 0; i < assembly.questions.length; i++) {
      answers[assembly.questions[i].id] = i < 56 ? 'b' : 'a';
    }
    final result = engine.grade(assembly, answers);
    expect(result.score, 56);
    expect(result.total, 80);
    expect(result.passed, isTrue); // 48 needed
    expect(
      result.perDomain.values.fold<int>(0, (s, d) => s + d.total),
      80,
    );
    expect(
      result.perDomain.values.fold<int>(0, (s, d) => s + d.correct),
      56,
    );
    // First 56 in exam order = first two domains perfect (20+20), third 16.
    expect(result.perDomain[FcleDomain.americanDemocracy]!.correct, 20);
    expect(result.perDomain[FcleDomain.usConstitution]!.correct, 20);
    expect(result.perDomain[FcleDomain.foundingDocuments]!.correct, 16);
    expect(result.perDomain[FcleDomain.landmarkImpact]!.correct, 0);
    expect(result.weakestDomain, FcleDomain.landmarkImpact);
  });

  test('47 of 80 fails, 48 passes', () {
    final assembly = engine.assemble(_bank(20), random: Random(2));
    Map<String, String> answersWith(int correct) => {
          for (var i = 0; i < assembly.questions.length; i++)
            assembly.questions[i].id: i < correct ? 'b' : 'a',
        };
    expect(engine.grade(assembly, answersWith(47)).passed, isFalse);
    expect(engine.grade(assembly, answersWith(48)).passed, isTrue);
  });

  test('unanswered questions count as wrong', () {
    final assembly = engine.assemble(_bank(20), random: Random(3));
    final result = engine.grade(assembly, const {});
    expect(result.score, 0);
    expect(result.passed, isFalse);
  });
}
