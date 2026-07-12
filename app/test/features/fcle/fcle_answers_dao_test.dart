import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/fcle/application/fcle_providers.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> log(String qid, String domain, bool correct, int at) =>
      db.fcleAnswersDao.log(
        questionId: qid,
        domain: domain,
        correct: correct,
        inMock: false,
        answeredAt: at,
      );

  test('rollingAccuracy is null with no history', () async {
    expect(await db.fcleAnswersDao.rollingAccuracy('us_constitution'), isNull);
  });

  test('rollingAccuracy computes over the recent window per domain',
      () async {
    await log('q1', 'us_constitution', true, 1);
    await log('q2', 'us_constitution', false, 2);
    await log('q3', 'american_democracy', true, 3);

    expect(await db.fcleAnswersDao.rollingAccuracy('us_constitution'), 0.5);
    expect(await db.fcleAnswersDao.rollingAccuracy('american_democracy'), 1.0);
    expect(await db.fcleAnswersDao.answerCount('us_constitution'), 2);
  });

  test('rollingAccuracy only counts the latest 50 answers', () async {
    // 50 wrong then 50 right; window must only see the right ones.
    for (var i = 0; i < 50; i++) {
      await log('old$i', 'us_constitution', false, i);
    }
    for (var i = 0; i < 50; i++) {
      await log('new$i', 'us_constitution', true, 100 + i);
    }
    expect(await db.fcleAnswersDao.rollingAccuracy('us_constitution'), 1.0);
    expect(await db.fcleAnswersDao.answerCount('us_constitution'), 100);
  });

  test('missedQuestionIds uses the LATEST answer per question', () async {
    await log('q1', 'us_constitution', false, 1); // missed...
    await log('q1', 'us_constitution', true, 2); // ...then corrected
    await log('q2', 'us_constitution', true, 3); // never missed
    await log('q3', 'us_constitution', false, 4); // still missed

    final missed = await db.fcleAnswersDao.missedQuestionIds('us_constitution');
    expect(missed, ['q3']);
  });

  test('buildPracticeSet prefers missed, then unseen, then the rest',
      () async {
    FcleQuestion q(String id) => FcleQuestion(
          id: id,
          domain: FcleDomain.usConstitution,
          stem: 'Stem for $id?',
          options: const [
            FcleOption(key: 'a', text: 'A'),
            FcleOption(key: 'b', text: 'B'),
          ],
          answerKey: 'a',
          explanation: 'x',
          citation: 'https://example.gov',
          difficulty: 3,
        );
    final bank = QuestionBank({
      FcleDomain.usConstitution: [
        q('missed'),
        q('seen-right'),
        q('unseen1'),
        q('unseen2'),
      ],
    });
    await log('missed', 'us_constitution', false, 1);
    await log('seen-right', 'us_constitution', true, 2);

    final set = await buildPracticeSet(
      bank: bank,
      dao: db.fcleAnswersDao,
      domain: FcleDomain.usConstitution,
      count: 3,
      random: Random(1),
    );

    expect(set.length, 3);
    expect(set.first.id, 'missed');
    // The two unseen fill the remaining slots before 'seen-right'.
    expect(set.skip(1).map((x) => x.id).toSet(), {'unseen1', 'unseen2'});
  });

  test('answerLog returns every row, newest first', () async {
    await log('q1', 'us_constitution', true, 10);
    await log('q2', 'american_democracy', false, 30);
    await log('q3', 'us_constitution', true, 20);

    final rows = await db.fcleAnswersDao.answerLog();
    expect(rows.map((r) => r.questionId).toList(), ['q2', 'q3', 'q1']);
    expect(rows.first.correct, isFalse);
    expect(rows.first.answeredAt, 30);
  });

  test('buildPracticeSet filters the domain pool to one objective', () async {
    FcleQuestion q(String id, String? objective) => FcleQuestion(
          id: id,
          domain: FcleDomain.usConstitution,
          stem: 'Stem for $id?',
          options: const [
            FcleOption(key: 'a', text: 'A'),
            FcleOption(key: 'b', text: 'B'),
          ],
          answerKey: 'a',
          explanation: 'x',
          citation: 'https://example.gov',
          difficulty: 3,
          objective: objective,
        );
    final bank = QuestionBank({
      FcleDomain.usConstitution: [
        q('art1-a', 'SS.912.CG.3.3'),
        q('art1-b', 'SS.912.CG.3.3'),
        q('art5-a', 'SS.7.CG.3.5'),
        q('untagged', null),
      ],
    });

    final scoped = await buildPracticeSet(
      bank: bank,
      dao: db.fcleAnswersDao,
      domain: FcleDomain.usConstitution,
      objective: 'SS.912.CG.3.3',
    );
    expect(scoped.map((x) => x.id).toSet(), {'art1-a', 'art1-b'});

    // No objective filter still returns the whole domain pool.
    final all = await buildPracticeSet(
      bank: bank,
      dao: db.fcleAnswersDao,
      domain: FcleDomain.usConstitution,
    );
    expect(all.length, 4);
  });

  test('buildPracticeSet caps at the pool size', () async {
    const bank = QuestionBank({
      FcleDomain.usConstitution: [
        FcleQuestion(
          id: 'only',
          domain: FcleDomain.usConstitution,
          stem: 'The only one?',
          options: [
            FcleOption(key: 'a', text: 'A'),
            FcleOption(key: 'b', text: 'B'),
          ],
          answerKey: 'a',
          explanation: 'x',
          citation: 'https://example.gov',
          difficulty: 3,
        ),
      ],
    });
    final set = await buildPracticeSet(
      bank: bank,
      dao: db.fcleAnswersDao,
      domain: FcleDomain.usConstitution,
    );
    expect(set.map((x) => x.id).toList(), ['only']);
  });
}
