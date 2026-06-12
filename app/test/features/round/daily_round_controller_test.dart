import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/round/domain/round_state.dart';
import 'package:politiface/features/trivia/domain/trivia_question.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ],);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<void> seedDeck(int count) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.into(db.localDecks).insert(LocalDecksCompanion.insert(
          id: 'd',
          externalId: 'd',
          name: 'd',
          updatedAt: now,
        ),);
    for (var i = 0; i < count; i++) {
      await db.into(db.localCards).insert(LocalCardsCompanion.insert(
            id: 'c$i',
            deckId: 'd',
            externalId: 'c${i}_ext',
            politicianName: 'Politician $i',
            title: 'Title $i',
            sourceUrl: '',
            updatedAt: now,
          ),);
    }
  }

  test('build creates a new round for today in cards phase', () async {
    await seedDeck(20);
    final state =
        await container.read(dailyRoundControllerProvider.future);
    expect(state.phase, RoundPhase.cards);
    expect(state.cards.length, 5);
    expect(state.trivia.length, 10);
    expect(state.chapterId, isNotEmpty);
    expect(state.dayInChapter, 1);
    expect(state.result, isNull);
  });

  test('build resumes a persisted round mid-cards-phase', () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    await container.read(dailyRoundControllerProvider.future);

    // Grade two cards, then dispose and rebuild a fresh container that
    // shares the same database — the persisted round should hydrate with
    // the same grades.
    await notifier.gradeCard(0, 2);
    await notifier.gradeCard(1, 3);

    final container2 = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ],);
    addTearDown(container2.dispose);
    final hydrated =
        await container2.read(dailyRoundControllerProvider.future);

    expect(hydrated.phase, RoundPhase.cards);
    expect(hydrated.cards[0].grade, 2);
    expect(hydrated.cards[1].grade, 3);
    expect(hydrated.cards[2].grade, isNull);
  });

  test('grading the last card flips to trivia phase', () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    final initial =
        await container.read(dailyRoundControllerProvider.future);

    for (var i = 0; i < initial.cards.length; i++) {
      await notifier.gradeCard(i, 2);
    }
    final after = container.read(dailyRoundControllerProvider).value!;
    expect(after.phase, RoundPhase.trivia);
  });

  test('answering the last trivia flips to reveal phase with a result',
      () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    final initial =
        await container.read(dailyRoundControllerProvider.future);

    // Burn through the cards phase to reach trivia.
    for (var i = 0; i < initial.cards.length; i++) {
      await notifier.gradeCard(i, 2);
    }
    // Answer all trivia (always pick option 0 with guess confidence).
    final mid = container.read(dailyRoundControllerProvider).value!;
    for (var i = 0; i < mid.trivia.length; i++) {
      await notifier.answerTrivia(i, 0, TriviaConfidence.guess);
    }
    final after = container.read(dailyRoundControllerProvider).value!;
    expect(after.phase, RoundPhase.reveal);
    expect(after.result, isNotNull);
    expect(after.result!.totalQuestions, mid.trivia.length);
  });

  test('completeRound advances phase to done + advances chapter day',
      () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    final initial =
        await container.read(dailyRoundControllerProvider.future);

    for (var i = 0; i < initial.cards.length; i++) {
      await notifier.gradeCard(i, 2);
    }
    final mid = container.read(dailyRoundControllerProvider).value!;
    for (var i = 0; i < mid.trivia.length; i++) {
      await notifier.answerTrivia(i, 0, TriviaConfidence.guess);
    }
    await notifier.completeRound();
    final after = container.read(dailyRoundControllerProvider).value!;
    expect(after.phase, RoundPhase.done);

    // Chapter progress should have ticked.
    final progress = await db.chapterProgressDao.getInProgress(
      userId: 'local-user',
      seasonId: 'us-civics-season-1',
    );
    expect(progress?.roundsCompleted, 1);
    expect(progress?.dayInChapter, 2);
  });

  test('gradeCard outside cards phase is a no-op', () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    final initial =
        await container.read(dailyRoundControllerProvider.future);
    for (var i = 0; i < initial.cards.length; i++) {
      await notifier.gradeCard(i, 2);
    }
    // Now in trivia phase. Grading again should be ignored.
    await notifier.gradeCard(0, 0);
    final after = container.read(dailyRoundControllerProvider).value!;
    expect(after.cards[0].grade, 2,
        reason: 'gradeCard should not overwrite once past cards phase',);
  });

  test('answerTrivia is no-op until cards phase completes', () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    await container.read(dailyRoundControllerProvider.future);

    await notifier.answerTrivia(0, 1, TriviaConfidence.certain);
    final after = container.read(dailyRoundControllerProvider).value!;
    expect(after.trivia[0].answer, isNull);
    expect(after.phase, RoundPhase.cards);
  });

  test('completeRound throws when called before reveal phase', () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    await container.read(dailyRoundControllerProvider.future);

    expect(notifier.completeRound, throwsStateError);
  });

  test('reload on same date returns the same persisted round', () async {
    await seedDeck(20);
    await container.read(dailyRoundControllerProvider.future);

    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    await notifier.gradeCard(0, 1);

    // Re-read; should be the same state (no rebuild because provider is
    // already initialized + state was set synchronously).
    final again = container.read(dailyRoundControllerProvider).value!;
    expect(again.cards[0].grade, 1);
  });

  test('gradeCard routes through FSRS pipeline + ticks profile XP',
      () async {
    await seedDeck(20);
    final notifier =
        container.read(dailyRoundControllerProvider.notifier);
    final initial =
        await container.read(dailyRoundControllerProvider.future);
    final firstCardId = initial.cards.first.cardId;

    // Profile starts empty (no XP, streak 0).
    final beforeProfile =
        await container.read(profileServiceProvider).load();
    expect(beforeProfile.xpTotal, 0);
    expect(beforeProfile.streakDays, 0);

    // Card memory state starts new (no row yet).
    final beforeMemory =
        await db.reviewsDao.stateFor(firstCardId);
    expect(beforeMemory, isNull);

    await notifier.gradeCard(0, 2); // FSRSGrade.good

    // After grading: FSRS state should exist + reviewCount = 1.
    final afterMemory = await db.reviewsDao.stateFor(firstCardId);
    expect(afterMemory, isNotNull,
        reason: 'gradeCard should have created a CardMemoryStates row',);
    expect(afterMemory!.reviewCount, greaterThanOrEqualTo(1));

    // Profile should have advanced — XP added + streak hits 1.
    final afterProfile =
        await container.read(profileServiceProvider).load();
    expect(afterProfile.xpTotal, greaterThan(0),
        reason: 'Profile XP should increment via recordReview',);
    expect(afterProfile.streakDays, 1,
        reason: 'Streak should tick on the first review of the day',);
  });
}
