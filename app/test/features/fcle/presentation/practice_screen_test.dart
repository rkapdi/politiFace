// Practice answers react in place: the chosen tile pops on a right answer
// and shakes on a wrong one, via the shared AnswerReaction wrapper.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/fcle/application/fcle_providers.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/presentation/practice_screen.dart';
import 'package:politiface/features/shared/widgets/feedback_motion.dart';

/// Two questions in one domain, both with the same two options, so the
/// walk below can answer the first correctly and the second incorrectly.
QuestionBank _fakeBank() => QuestionBank({
      FcleDomain.americanDemocracy: [
        for (var i = 0; i < 2; i++)
          FcleQuestion(
            id: 'ad-practice-q$i',
            domain: FcleDomain.americanDemocracy,
            stem: 'Practice question $i?',
            options: const [
              FcleOption(key: 'a', text: 'Right answer'),
              FcleOption(key: 'b', text: 'Wrong answer'),
            ],
            answerKey: 'a',
            explanation: 'Because the Constitution says so.',
            citation: 'U.S. Const. art. I',
            difficulty: 1,
          ),
      ],
    });

Finder _reactionWithKind(AnswerReactionKind kind) => find.byWidgetPredicate(
      (w) => w is AnswerReaction && w.kind == kind,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget host() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          practiceBankProvider.overrideWith((ref) => _fakeBank()),
        ],
        child: const MaterialApp(
          home: PracticeScreen(domainCode: 'american_democracy'),
        ),
      );

  testWidgets(
      'the chosen tile pops correct on a right answer and shakes wrong '
      'on a wrong one', (tester) async {
    await tester.pumpWidget(host());
    // Let practiceBankProvider + buildPracticeSet resolve.
    for (var f = 0; f < 4; f++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Right answer'), findsOneWidget);

    // Answer the first question correctly.
    await tester.tap(find.text('Right answer'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    for (var f = 0; f < 4; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_reactionWithKind(AnswerReactionKind.correct), findsOneWidget);
    expect(_reactionWithKind(AnswerReactionKind.wrong), findsNothing);

    // Move to the second question and answer it incorrectly.
    await tester.tap(find.text('NEXT'));
    for (var f = 0; f < 3; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Wrong answer'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    for (var f = 0; f < 4; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_reactionWithKind(AnswerReactionKind.wrong), findsOneWidget);
    expect(_reactionWithKind(AnswerReactionKind.correct), findsNothing);

    // Flush any pending drift work before teardown closes the database.
    await tester.runAsync(() => db.fcleAnswersDao.answerCount('american_democracy'));
  });
}
