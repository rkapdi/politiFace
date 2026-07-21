import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../../core/sync/app_state_sync.dart';
import '../../curriculum/data/chapter_progress_service.dart';
import '../../curriculum/domain/curriculum.dart';
import '../../session/data/card_review_repository.dart';
import '../../session/domain/fsrs_algorithm.dart';
import '../../trivia/data/trivia_generator.dart';
import '../../trivia/domain/trivia_question.dart';
import '../../trivia/domain/trivia_scoring.dart';
import '../data/chapter_content_sampler.dart';
import '../domain/round_state.dart';

/// Orchestrates one daily round: cards → trivia → reveal → done.
///
/// Phase 2 scope (NO UI YET):
///   - Loads today's round (resume) or creates a new one
///   - Samples 5 cards + 10 trivia questions from the current chapter
///   - Tracks per-card grades + per-trivia answers in memory + persists
///     after every state change so backgrounding is safe
///   - Calls `ChapterProgressService.recordRoundCompletion` on completion
///   - Calls `ProfileService.recordReview` per graded card so XP + streak
///     flow continues to work
///
/// Out of scope (later phases):
///   - The Daily Round screen UI (Phase 3)
///   - Home redesign showing the round CTA (Phase 4)
///   - Removing the old DailyChallenge flow (Phase 5)
class DailyRoundController extends AsyncNotifier<DailyRoundState> {
  static const _userId = ChapterProgressService.defaultUserId;
  static const int cardsPerRound = 5;
  static const int triviaPerRound = 10;

  ChapterProgressService get _progressService =>
      ref.read(chapterProgressServiceProvider);
  ChapterContentSampler get _sampler => ref.read(chapterContentSamplerProvider);
  CardReviewRepository get _reviewRepository =>
      ref.read(cardReviewRepositoryProvider);
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  Future<DailyRoundState> build() async {
    final curriculum = await ref.watch(curriculumProvider.future);
    final dateIso = _todayIso();
    final existing = await _db.dailyRoundsDao.get(
      userId: _userId,
      dateIso: dateIso,
    );
    if (existing != null) {
      return _deserialize(existing, curriculum);
    }
    return _createNewRound(curriculum: curriculum, dateIso: dateIso);
  }

  Future<DailyRoundState> _createNewRound({
    required Curriculum curriculum,
    required String dateIso,
  }) async {
    final progress = await _progressService.currentProgress(curriculum);
    if (progress == null) {
      throw const _SeasonComplete();
    }
    final chapter = curriculum.chapterById(progress.chapterId);
    if (chapter == null) {
      throw StateError(
        'Active chapter ${progress.chapterId} not in curriculum.',
      );
    }

    final lessons = chapter.lessonsForDay(progress.dayInChapter);
    final cardSample = await _sampler.sampleCards(
      chapter: chapter,
      count: cardsPerRound,
      dateIso: dateIso,
      curriculum: curriculum,
      preferItemIds: [
        for (final l in lessons) ...l.relatedCardIds,
      ],
    );
    final triviaSample = await _sampler.sampleTrivia(
      chapter: chapter,
      count: triviaPerRound,
      dateIso: dateIso,
      curriculum: curriculum,
    );

    if (cardSample.isEmpty && triviaSample.isEmpty) {
      throw const _NoContent();
    }

    final cards = <RoundCard>[];
    for (final c in cardSample.cards) {
      if (c.cardType == 'concept') {
        // Teach-first: a never-reviewed concept renders as a lesson with
        // "Got it"; afterwards the recall prompt fronts the flip card.
        final memory = await _db.reviewsDao.stateFor(c.id);
        cards.add(
          RoundCard(
            cardId: c.id,
            prompt: c.recallPrompt ?? c.politicianName,
            answer: c.body ?? c.title,
            cardType: 'concept',
            body: c.body,
            teachFirst: memory?.isNew ?? true,
          ),
        );
      } else {
        cards.add(
          RoundCard(
            cardId: c.id,
            prompt: '${c.politicianName} · ${c.title}',
            answer: c.oneLiner ?? c.title,
            politicianName: c.politicianName,
            photoUrl: c.photoUrl,
          ),
        );
      }
    }
    final triviaQuestions = const TriviaGenerator()
        .generate(date: DateTime.now(), cards: triviaSample.cards);
    final trivia =
        triviaQuestions.map((q) => RoundTrivia(question: q)).toList();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final initial = DailyRoundState(
      dateIso: dateIso,
      chapterId: chapter.id,
      chapterTitle: chapter.title,
      chapterSubtitle: chapter.subtitle,
      dayInChapter: progress.dayInChapter,
      daysInChapter: chapter.days,
      // Days with authored lessons open on the briefing; others go
      // straight to cards (content not authored yet — back-compat).
      phase: lessons.isEmpty ? RoundPhase.cards : RoundPhase.briefing,
      cards: cards,
      trivia: trivia,
      lessons: lessons,
      nextChapterTitle: curriculum.chapterAfter(chapter.id)?.title,
    );

    await _persist(initial, startedAt: now);

    // Efficacy plumbing: session boundaries feed the cohort engagement
    // metrics. No-op unless a backend is configured AND the user signed in.
    unawaited(ref.read(syncEngineProvider).enqueueSessionStart());
    return initial;
  }

  /// Advance briefing → cards once the user has read today's lessons.
  /// No-op outside the briefing phase.
  Future<void> completeBriefing() async {
    final s = state.value;
    if (s == null || s.phase != RoundPhase.briefing) return;
    final next = s.copyWith(phase: RoundPhase.cards);
    state = AsyncData(next);
    await _persist(next);
  }

  /// Grade the card at [index] with [grade] (0..3). Routes the grade
  /// through [CardReviewRepository.recordGrade] so the existing FSRS
  /// pipeline + profile XP/streak update — same path the free-explore
  /// session uses. Advances to the trivia phase when the last card is
  /// graded.
  Future<void> gradeCard(int index, int grade) async {
    final s = state.value;
    if (s == null || s.phase != RoundPhase.cards) return;
    if (index < 0 || index >= s.cards.length) return;
    if (s.cards[index].grade != null) return; // already graded

    // Hand the grade to the spaced-repetition pipeline. This updates
    // FSRS memory state for the card AND increments profile XP + streak
    // via ProfileService.recordReview inside the repository.
    final fsrsGrade = FSRSGrade.values[grade.clamp(0, 3)];
    await _reviewRepository.recordGrade(
      cardId: s.cards[index].cardId,
      grade: fsrsGrade,
    );
    // Profile + map widgets watch sessionTickProvider for invalidation.
    ref.read(sessionTickProvider.notifier).state++;

    final updatedCards = [...s.cards];
    updatedCards[index] = updatedCards[index].copyWith(grade: grade);

    var nextState = s.copyWith(cards: updatedCards);
    final allGraded = updatedCards.every((c) => c.grade != null);
    if (allGraded) {
      // Skip directly to reveal if there's no trivia (sparse chapter
      // content). Otherwise move to the trivia phase.
      nextState = nextState.copyWith(
        phase: s.trivia.isEmpty ? RoundPhase.reveal : RoundPhase.trivia,
      );
      if (s.trivia.isEmpty) {
        nextState = nextState.copyWith(result: _emptyResult());
      }
    }
    state = AsyncData(nextState);
    await _persist(nextState);
  }

  /// Answer the trivia question at [index]. Advances to reveal phase when
  /// the last question is answered.
  Future<void> answerTrivia(
    int index,
    int optionIdx,
    TriviaConfidence confidence,
  ) async {
    final s = state.value;
    if (s == null || s.phase != RoundPhase.trivia) return;
    if (index < 0 || index >= s.trivia.length) return;
    if (s.trivia[index].answer != null) return;

    final answer = TriviaAnswer(
      question: s.trivia[index].question,
      answerIndex: optionIdx,
      confidence: confidence,
    );
    final updatedTrivia = [...s.trivia];
    updatedTrivia[index] = updatedTrivia[index].copyWith(answer: answer);

    var nextState = s.copyWith(trivia: updatedTrivia);
    final allAnswered = updatedTrivia.every((t) => t.answer != null);
    if (allAnswered) {
      final answers = updatedTrivia.map((t) => t.answer!).toList();
      nextState = nextState.copyWith(
        phase: RoundPhase.reveal,
        result: summarize(answers),
      );
    }
    state = AsyncData(nextState);
    await _persist(nextState);
  }

  /// Mark the round complete. Advances the chapter day; bumps streak/XP
  /// via the session-tick provider that the daily-challenge flow already
  /// uses. Idempotent — calling twice doesn't double-advance.
  Future<void> completeRound() async {
    final s = state.value;
    if (s == null || s.phase == RoundPhase.done) return;
    if (s.phase != RoundPhase.reveal) {
      throw StateError(
        'completeRound called in phase ${s.phase}; expected reveal.',
      );
    }
    final curriculum = await ref.read(curriculumProvider.future);
    await _progressService.recordRoundCompletion(curriculum);

    final next = s.copyWith(phase: RoundPhase.done);
    state = AsyncData(next);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _persist(next, completedAt: now);

    // History row — best-effort, never blocks completion.
    unawaited(_writeHistoryRow(next, completedAt: now));

    // Efficacy plumbing counterpart to the session_start in _createNewRound.
    unawaited(ref.read(syncEngineProvider).enqueueSessionEnd());

    // Cross-device sync: chapter position and XP settle here, so one
    // app_state upsert per completed round (never per XP tick). No-op when
    // signed out or unconfigured.
    unawaited(
      pushAppState(
        db: _db,
        sync: ref.read(syncEngineProvider),
        curriculum: curriculum,
      ),
    );

    // Force any chapter-aware UI to refetch.
    ref.read(sessionTickProvider.notifier).state++;
  }

  Future<void> _writeHistoryRow(
    DailyRoundState s, {
    required int completedAt,
  }) async {
    try {
      final result = s.result;
      final correct = result?.correctCount;
      final total = result?.totalQuestions;
      // Salt the id so re-completing the same chapter on the same day (rare
      // but possible — backgrounded, reloaded, replayed) inserts a fresh
      // history row instead of upserting over the original.
      final salt = math.Random().nextInt(1 << 32);
      await _db.completedRunsDao.insert(
        CompletedRunsCompanion.insert(
          id: 'round_${s.dateIso}_${s.chapterId}_$salt',
          mode: 'round',
          completedAt: completedAt,
          score: Value(result?.totalScore),
          correctCount: Value(correct),
          totalCount: Value(total),
          summary: Value(s.chapterTitle),
          payload: Value(
            jsonEncode({
              'dateIso': s.dateIso,
              'chapterId': s.chapterId,
              'chapterTitle': s.chapterTitle,
              'dayInChapter': s.dayInChapter,
              'daysInChapter': s.daysInChapter,
              'cards': _serializeCards(s.cards),
              'grades': s.cards.map((c) => c.grade).toList(),
              'trivia': _serializeTrivia(s.trivia),
              'answers': _serializeAnswers(s.trivia),
            }),
          ),
        ),
      );
    } catch (_) {
      // Swallow — history-write failures must not block round completion.
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────

  Future<void> _persist(
    DailyRoundState s, {
    int? startedAt,
    int? completedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final existing = await _db.dailyRoundsDao.get(
      userId: _userId,
      dateIso: s.dateIso,
    );
    final startedAtValue = startedAt ?? existing?.startedAt ?? now;
    final completedAtValue = completedAt ?? existing?.completedAt;

    await _db.dailyRoundsDao.upsert(
      DailyRoundsCompanion(
        userId: const Value(_userId),
        dateIso: Value(s.dateIso),
        chapterId: Value(s.chapterId),
        dayInChapter: Value(s.dayInChapter),
        cardIdsJson: Value(jsonEncode(_serializeCards(s.cards))),
        triviaJson: Value(jsonEncode(_serializeTrivia(s.trivia))),
        gradesJson: Value(jsonEncode(s.cards.map((c) => c.grade).toList())),
        answersJson: Value(jsonEncode(_serializeAnswers(s.trivia))),
        phase: Value(s.phase.wireName),
        startedAt: Value(startedAtValue),
        completedAt: Value(completedAtValue),
        updatedAt: Value(now),
      ),
    );
  }

  Future<DailyRoundState> _deserialize(
    DailyRoundEntry row,
    Curriculum curriculum,
  ) async {
    final chapter = curriculum.chapterById(row.chapterId);
    if (chapter == null) {
      throw StateError(
        'Persisted round references unknown chapter ${row.chapterId}.',
      );
    }
    final cardData = (jsonDecode(row.cardIdsJson) as List<dynamic>)
        .cast<Map<dynamic, dynamic>>();
    final grades = jsonDecode(row.gradesJson) as List<dynamic>;
    final cards = <RoundCard>[];
    for (var i = 0; i < cardData.length; i++) {
      final m = cardData[i];
      cards.add(
        RoundCard(
          cardId: m['cardId'] as String,
          prompt: m['prompt'] as String,
          answer: m['answer'] as String,
          politicianName: m['politicianName'] as String?,
          photoUrl: m['photoUrl'] as String?,
          grade: i < grades.length ? grades[i] as int? : null,
          // Pre-v9 rows lack these keys — default to face-card behavior.
          cardType: (m['cardType'] as String?) ?? 'face',
          body: m['body'] as String?,
          teachFirst: (m['teachFirst'] as bool?) ?? false,
        ),
      );
    }
    final triviaData = (jsonDecode(row.triviaJson) as List<dynamic>)
        .cast<Map<dynamic, dynamic>>();
    final answerData = jsonDecode(row.answersJson) as List<dynamic>;
    final trivia = <RoundTrivia>[];
    for (var i = 0; i < triviaData.length; i++) {
      final q = _deserializeQuestion(triviaData[i]);
      TriviaAnswer? a;
      if (i < answerData.length && answerData[i] != null) {
        final raw = answerData[i] as Map<dynamic, dynamic>;
        a = TriviaAnswer(
          question: q,
          answerIndex: raw['optionIdx'] as int,
          confidence: TriviaConfidence.values
              .firstWhere((c) => c.name == raw['confidence']),
        );
      }
      trivia.add(RoundTrivia(question: q, answer: a));
    }

    final phase = RoundPhaseSerialization.fromWire(row.phase);
    final result = phase == RoundPhase.reveal || phase == RoundPhase.done
        ? summarize(
            trivia
                .where((t) => t.answer != null)
                .map((t) => t.answer!)
                .toList(),
          )
        : null;

    return DailyRoundState(
      dateIso: row.dateIso,
      chapterId: chapter.id,
      chapterTitle: chapter.title,
      chapterSubtitle: chapter.subtitle,
      dayInChapter: row.dayInChapter,
      daysInChapter: chapter.days,
      phase: phase,
      cards: cards,
      trivia: trivia,
      lessons: chapter.lessonsForDay(row.dayInChapter),
      nextChapterTitle: curriculum.chapterAfter(chapter.id)?.title,
      result: result,
    );
  }

  List<Map<String, dynamic>> _serializeCards(List<RoundCard> cards) => [
        for (final c in cards)
          {
            'cardId': c.cardId,
            'prompt': c.prompt,
            'answer': c.answer,
            'politicianName': c.politicianName,
            'photoUrl': c.photoUrl,
            'cardType': c.cardType,
            'body': c.body,
            'teachFirst': c.teachFirst,
          },
      ];

  List<Map<String, dynamic>> _serializeTrivia(List<RoundTrivia> trivia) => [
        for (final t in trivia) _serializeQuestion(t.question),
      ];

  Map<String, dynamic> _serializeQuestion(TriviaQuestion q) => {
        'cardId': q.cardId,
        'format': q.format.name,
        'prompt': q.prompt,
        'photoUrl': q.photoUrl,
        'options': q.options,
        'correctIndex': q.correctIndex,
      };

  TriviaQuestion _deserializeQuestion(Map<dynamic, dynamic> m) =>
      TriviaQuestion(
        cardId: m['cardId'] as String,
        format: TriviaFormat.values.firstWhere((f) => f.name == m['format']),
        prompt: m['prompt'] as String,
        photoUrl: m['photoUrl'] as String?,
        options: (m['options'] as List<dynamic>).cast<String>(),
        correctIndex: m['correctIndex'] as int,
      );

  List<Map<String, dynamic>?> _serializeAnswers(List<RoundTrivia> trivia) => [
        for (final t in trivia)
          if (t.answer == null)
            null
          else
            {
              'optionIdx': t.answer!.answerIndex,
              'confidence': t.answer!.confidence.name,
            },
      ];

  TriviaResult _emptyResult() => summarize(const []);

  String _todayIso() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}

// ── Internal exception types ──────────────────────────────────────────────
// Surfaced via AsyncError so the UI can branch on them without parsing strings.

class _SeasonComplete implements Exception {
  const _SeasonComplete();
  @override
  String toString() => 'SeasonComplete';
}

class _NoContent implements Exception {
  const _NoContent();
  @override
  String toString() => 'NoContent';
}

/// Public surface for the UI to check error types.
bool isSeasonCompleteError(Object? err) => err is _SeasonComplete;
bool isNoContentError(Object? err) => err is _NoContent;
