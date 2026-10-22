// The onboarding diagnostic deals 5 quick questions: every domain covered,
// and only the shorter, easier items in each domain qualify, so the first
// thing a new student does takes about a minute.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/onboarding/presentation/onboarding_screen.dart';

/// Per domain: items 0..9 are short and easy, items 10..19 are long or
/// hard. A quick pick must only ever come from the first group.
QuestionBank mixedBank() => QuestionBank({
      for (final d in FcleDomain.values)
        d: [
          for (var i = 0; i < 20; i++)
            FcleQuestion(
              id: '${d.code}-$i',
              domain: d,
              stem: i < 10 ? 'Short $i?' : 'Long ${'x' * 300} $i?',
              options: const [
                FcleOption(key: 'a', text: 'Yes'),
                FcleOption(key: 'b', text: 'No'),
              ],
              answerKey: 'a',
              explanation: 'e',
              citation: 'c',
              difficulty: i < 10 ? 2 : (i.isEven ? 5 : 2),
            ),
        ],
    });

void main() {
  test('deals exactly 5 questions covering all four domains', () {
    for (var seed = 0; seed < 30; seed++) {
      final picked = pickDiagnosticQuestions(mixedBank(), Random(seed));
      expect(picked.length, diagnosticQuestionCount);
      expect(picked.length, 5);
      expect(picked.map((q) => q.domain).toSet(), FcleDomain.values.toSet());
      expect(picked.map((q) => q.id).toSet().length, 5, reason: 'no repeats');
    }
  });

  test('only quick questions qualify: short and difficulty 3 or below', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final q in pickDiagnosticQuestions(mixedBank(), Random(seed))) {
        final n = int.parse(q.id.split('-').last);
        expect(n, lessThan(10), reason: '${q.id} is long or hard (seed $seed)');
      }
    }
  });

  test('a thin domain still fills from what it has', () {
    final bank = QuestionBank({
      for (final d in FcleDomain.values)
        d: [
          FcleQuestion(
            id: '${d.code}-only',
            domain: d,
            stem: 'Long ${'x' * 300}?',
            options: const [
              FcleOption(key: 'a', text: 'Yes'),
              FcleOption(key: 'b', text: 'No'),
            ],
            answerKey: 'a',
            explanation: 'e',
            citation: 'c',
            difficulty: 5,
          ),
          FcleQuestion(
            id: '${d.code}-two',
            domain: d,
            stem: 'Also long ${'y' * 300}?',
            options: const [
              FcleOption(key: 'a', text: 'Yes'),
              FcleOption(key: 'b', text: 'No'),
            ],
            answerKey: 'a',
            explanation: 'e',
            citation: 'c',
            difficulty: 4,
          ),
        ],
    });
    final picked = pickDiagnosticQuestions(bank, Random(1));
    expect(picked.length, 5);
    expect(picked.map((q) => q.domain).toSet(), FcleDomain.values.toSet());
  });
}
