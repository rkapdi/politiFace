import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/core/sync/restore_service.dart';
import 'package:politiface/core/sync/sync_engine.dart';
import 'package:politiface/features/curriculum/data/chapter_progress_service.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';
import 'package:politiface/features/profile/data/profile_service.dart';

class _RecordingTransport implements SyncTransport {
  bool signedIn = true;
  final delivered = <OutboxEvent>[];

  @override
  bool get isSignedIn => signedIn;

  Future<void> _send(OutboxEvent e) async => delivered.add(e);

  @override
  Future<void> sendAnswer(OutboxEvent e) => _send(e);
  @override
  Future<void> sendReview(OutboxEvent e) => _send(e);
  @override
  Future<void> sendSessionEvent(OutboxEvent e) => _send(e);
  @override
  Future<void> sendMockFinalize(OutboxEvent e) => _send(e);
  @override
  Future<void> upsertCardState(OutboxEvent e) => _send(e);
  @override
  Future<void> upsertAppState(OutboxEvent e) => _send(e);
}

class _FakeRestoreApi implements RestoreApi {
  Map<String, dynamic>? appState;
  List<Map<String, dynamic>> cardStates = [];
  Map<String, dynamic>? streak;
  bool fail = false;

  void _maybeFail() {
    if (fail) throw Exception('socket closed');
  }

  @override
  Future<Map<String, dynamic>?> fetchAppState() async {
    _maybeFail();
    return appState;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCardStates() async {
    _maybeFail();
    return cardStates;
  }

  @override
  Future<Map<String, dynamic>?> fetchStreak() async {
    _maybeFail();
    return streak;
  }
}

Curriculum _curriculum() => Curriculum(
      version: 1,
      locale: 'en-US',
      season: const Season(
        id: 'season-1',
        title: 'Civic Foundations',
        subtitle: '',
        totalChapters: 3,
        estimatedDays: 9,
      ),
      chapters: const [
        Chapter(
          id: 'ch1',
          order: 1,
          title: 'One',
          subtitle: '',
          days: 3,
          itemIds: [],
        ),
        Chapter(
          id: 'ch2',
          order: 2,
          title: 'Two',
          subtitle: '',
          days: 3,
          itemIds: [],
        ),
        Chapter(
          id: 'ch3',
          order: 3,
          title: 'Three',
          subtitle: '',
          days: 3,
          itemIds: [],
        ),
      ],
      branches: const [],
    );

Future<void> _seedDeck(
  AppDatabase db, {
  String id = 'deck-1',
  String externalId = 'deck-ext-1',
  bool subscribed = true,
}) =>
    db.decksDao.upsertDeck(
      LocalDecksCompanion.insert(
        id: id,
        externalId: externalId,
        name: 'Deck $id',
        updatedAt: 0,
        isSubscribed: Value(subscribed),
      ),
    );

Future<void> _seedCard(
  AppDatabase db, {
  required String rowId,
  required String externalId,
  String deckId = 'deck-1',
}) =>
    db.cardsDao.upsertCard(
      LocalCardsCompanion.insert(
        id: rowId,
        deckId: deckId,
        externalId: externalId,
        politicianName: 'Name $rowId',
        title: 'Title',
        sourceUrl: 'about:blank',
        updatedAt: 0,
      ),
    );

Future<void> _seedMemoryState(
  AppDatabase db, {
  required String cardId,
  required int lastReviewedAt,
  double stability = 2,
  double difficulty = 4,
  int reviewCount = 2,
  int lapses = 0,
  bool isNew = false,
}) =>
    db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: Value(cardId),
        stability: Value(stability),
        difficulty: Value(difficulty),
        retrievability: const Value(0.9),
        lastReviewedAt: Value(lastReviewedAt),
        nextReviewAt: Value(lastReviewedAt + 86400),
        intervalDays: const Value(1),
        lapses: Value(lapses),
        reviewCount: Value(reviewCount),
        isNew: Value(isNew),
      ),
    );

Map<String, dynamic> _serverCard(
  String cardId, {
  int? lastReviewedAt,
  int? dueAt,
  double stability = 9,
  double difficulty = 6,
  int reps = 9,
  int lapses = 1,
  bool isNew = false,
}) =>
    {
      'card_id': cardId,
      'stability': stability,
      'difficulty': difficulty,
      'due_at': dueAt == null ? null : isoFromUnixSeconds(dueAt),
      'last_reviewed_at':
          lastReviewedAt == null ? null : isoFromUnixSeconds(lastReviewedAt),
      'reps': reps,
      'lapses': lapses,
      'is_new': isNew,
    };

Future<void> _seedChapterEntry(
  AppDatabase db, {
  required String chapterId,
  required int dayInChapter,
  int? completedAt,
  int startedAt = 1000,
}) =>
    db.chapterProgressDao.upsert(
      ChapterProgressCompanion(
        userId: const Value(ChapterProgressService.defaultUserId),
        seasonId: const Value('season-1'),
        chapterId: Value(chapterId),
        dayInChapter: Value(dayInChapter),
        roundsCompleted: Value(dayInChapter - 1),
        startedAt: Value(startedAt),
        completedAt: Value(completedAt),
        updatedAt: Value(startedAt),
      ),
    );

void main() {
  const t1 = 1721000000; // older review instant (unix seconds)
  const t2 = 1721500000; // newer review instant

  late AppDatabase db;
  late _RecordingTransport transport;
  late _FakeRestoreApi api;
  late RestoreService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transport = _RecordingTransport();
    api = _FakeRestoreApi();
    service = RestoreService(
      db: db,
      api: api,
      sync: SyncEngine(db, transport),
      loadCurriculum: () async => _curriculum(),
    );
  });

  tearDown(() => db.close());

  List<OutboxEvent> delivered(String type) =>
      transport.delivered.where((e) => e.type == type).toList();

  group('decideCardMerge', () {
    test('newest wins in both directions, ties are skips', () {
      expect(
        decideCardMerge(localLastReviewedAt: t1, serverLastReviewedAt: t2),
        CardMergeDecision.takeServer,
      );
      expect(
        decideCardMerge(localLastReviewedAt: t2, serverLastReviewedAt: t1),
        CardMergeDecision.pushLocal,
      );
      expect(
        decideCardMerge(localLastReviewedAt: t1, serverLastReviewedAt: t1),
        CardMergeDecision.skip,
      );
    });

    test('unreviewed sides resolve toward whoever has data', () {
      expect(
        decideCardMerge(localLastReviewedAt: null, serverLastReviewedAt: t1),
        CardMergeDecision.takeServer,
      );
      expect(
        decideCardMerge(localLastReviewedAt: t1, serverLastReviewedAt: null),
        CardMergeDecision.pushLocal,
      );
      expect(
        decideCardMerge(localLastReviewedAt: null, serverLastReviewedAt: null),
        CardMergeDecision.skip,
      );
    });
  });

  group('card merge', () {
    test('server-newer overwrites local FSRS fields', () async {
      await _seedDeck(db);
      await _seedCard(db, rowId: 'row1', externalId: 'ext1');
      await _seedMemoryState(db, cardId: 'row1', lastReviewedAt: t1);
      api.cardStates = [
        _serverCard('ext1', lastReviewedAt: t2, dueAt: t2 + 12 * 86400),
      ];

      final summary = await service.restoreNow();

      expect(summary.cardsRestored, 1);
      final state = await db.reviewsDao.stateFor('row1');
      expect(state!.stability, 9);
      expect(state.difficulty, 6);
      expect(state.reviewCount, 9);
      expect(state.lapses, 1);
      expect(state.isNew, isFalse);
      expect(state.lastReviewedAt, t2);
      expect(state.nextReviewAt, t2 + 12 * 86400);
    });

    test('local-newer card is kept and pushed back up', () async {
      await _seedDeck(db);
      await _seedCard(db, rowId: 'row1', externalId: 'ext1');
      await _seedMemoryState(db, cardId: 'row1', lastReviewedAt: t2);
      api.cardStates = [_serverCard('ext1', lastReviewedAt: t1)];

      final summary = await service.restoreNow();

      expect(summary.cardsRestored, 0);
      final state = await db.reviewsDao.stateFor('row1');
      expect(state!.stability, 2, reason: 'local FSRS state untouched');
      final pushes = delivered('card_state');
      expect(pushes.length, 1);
      final payload = jsonDecode(pushes.single.payload) as Map<String, dynamic>;
      expect(payload['card_id'], 'ext1');
      expect(payload['stability'], 2);
    });

    test('server card ids with no local card are skipped without error',
        () async {
      await _seedDeck(db);
      api.cardStates = [_serverCard('ghost-card', lastReviewedAt: t2)];

      final summary = await service.restoreNow();

      expect(summary.failed, isFalse);
      expect(summary.cardsRestored, 0);
    });

    test('local new/unreviewed row adopts server state', () async {
      await _seedDeck(db);
      await _seedCard(db, rowId: 'row1', externalId: 'ext1');
      await _seedMemoryState(
        db,
        cardId: 'row1',
        lastReviewedAt: 0,
        isNew: true,
      );
      api.cardStates = [
        _serverCard('ext1', lastReviewedAt: t2, dueAt: t2 + 86400),
      ];

      final summary = await service.restoreNow();

      expect(summary.cardsRestored, 1);
      final state = await db.reviewsDao.stateFor('row1');
      expect(state!.isNew, isFalse);
      expect(state.stability, 9);
    });

    test('running restore twice restores nothing the second time', () async {
      await _seedDeck(db);
      await _seedCard(db, rowId: 'row1', externalId: 'ext1');
      await _seedMemoryState(db, cardId: 'row1', lastReviewedAt: t1);
      api.cardStates = [
        _serverCard('ext1', lastReviewedAt: t2, dueAt: t2 + 86400),
      ];

      final first = await service.restoreNow();
      final second = await service.restoreNow();

      expect(first.cardsRestored, 1);
      expect(second.cardsRestored, 0, reason: 'merge must be idempotent');
    });
  });

  group('app-state merge', () {
    test('server further chapter position is applied', () async {
      await _seedChapterEntry(db, chapterId: 'ch1', dayInChapter: 2);
      api.appState = {
        'chapter_number': 2,
        'day_in_chapter': 2,
        'xp': 0,
        'deck_subscriptions': <String, dynamic>{},
      };

      final summary = await service.restoreNow();

      expect(summary.appStateChanged, isTrue);
      final ch1 = await db.chapterProgressDao.get(
        userId: ChapterProgressService.defaultUserId,
        seasonId: 'season-1',
        chapterId: 'ch1',
      );
      expect(ch1!.completedAt, isNotNull);
      final ch2 = await db.chapterProgressDao.get(
        userId: ChapterProgressService.defaultUserId,
        seasonId: 'season-1',
        chapterId: 'ch2',
      );
      expect(ch2!.completedAt, isNull);
      expect(ch2.dayInChapter, 2);
    });

    test('local further chapter position is kept and pushed', () async {
      await _seedChapterEntry(
        db,
        chapterId: 'ch1',
        dayInChapter: 3,
        completedAt: 2000,
      );
      await _seedChapterEntry(db, chapterId: 'ch2', dayInChapter: 1);
      api.appState = {
        'chapter_number': 1,
        'day_in_chapter': 1,
        'xp': 0,
        'deck_subscriptions': <String, dynamic>{},
      };

      final summary = await service.restoreNow();

      expect(summary.appStateChanged, isFalse);
      final ch2 = await db.chapterProgressDao.get(
        userId: ChapterProgressService.defaultUserId,
        seasonId: 'season-1',
        chapterId: 'ch2',
      );
      expect(ch2!.completedAt, isNull, reason: 'local position untouched');
      final pushes = delivered('app_state');
      expect(pushes.length, 1);
      final payload = jsonDecode(pushes.single.payload) as Map<String, dynamic>;
      expect(payload['chapter_number'], 2);
      expect(payload['day_in_chapter'], 1);
    });

    test('xp: server max wins', () async {
      await db.metaDao.set(ProfileService.kXp, '100');
      api.appState = {
        'chapter_number': 1,
        'day_in_chapter': 1,
        'xp': 250,
        'deck_subscriptions': <String, dynamic>{},
      };

      final summary = await service.restoreNow();

      expect(summary.appStateChanged, isTrue);
      expect(await db.metaDao.get(ProfileService.kXp), '250');
    });

    test('xp: local max is kept and pushed', () async {
      await db.metaDao.set(ProfileService.kXp, '300');
      api.appState = {
        'chapter_number': 1,
        'day_in_chapter': 1,
        'xp': 250,
        'deck_subscriptions': <String, dynamic>{},
      };

      await service.restoreNow();

      expect(await db.metaDao.get(ProfileService.kXp), '300');
      final pushes = delivered('app_state');
      expect(pushes.length, 1);
      final payload = jsonDecode(pushes.single.payload) as Map<String, dynamic>;
      expect(payload['xp'], 300);
    });

    test('streak: server run adopted when at least the local run', () async {
      await db.metaDao.set(ProfileService.kStreak, '3');
      await db.metaDao.set(ProfileService.kLastReview, '2026-07-10');
      api.streak = {
        'current': 5,
        'longest': 9,
        'last_active_date': '2026-07-20',
      };

      final summary = await service.restoreNow();

      expect(summary.appStateChanged, isTrue);
      expect(await db.metaDao.get(ProfileService.kStreak), '5');
      expect(await db.metaDao.get(ProfileService.kLastReview), '2026-07-20');
    });

    test('streak: shorter server run is ignored', () async {
      await db.metaDao.set(ProfileService.kStreak, '4');
      await db.metaDao.set(ProfileService.kLastReview, '2026-07-21');
      api.streak = {
        'current': 2,
        'longest': 2,
        'last_active_date': '2026-07-01',
      };

      await service.restoreNow();

      expect(await db.metaDao.get(ProfileService.kStreak), '4');
      expect(await db.metaDao.get(ProfileService.kLastReview), '2026-07-21');
    });

    test('deck map applies to local decks; extra local decks trigger one push',
        () async {
      await _seedDeck(db, externalId: 'ext-a');
      await _seedDeck(db, id: 'deck-2', externalId: 'ext-b');
      api.appState = {
        'chapter_number': 1,
        'day_in_chapter': 1,
        'xp': 0,
        // ext-b is unknown to the server: it must survive locally and get
        // pushed up; ext-a flips off per the server.
        'deck_subscriptions': {'ext-a': false},
      };

      final summary = await service.restoreNow();

      expect(summary.appStateChanged, isTrue);
      final deckA = await db.decksDao.deckById('deck-1');
      final deckB = await db.decksDao.deckById('deck-2');
      expect(deckA!.isSubscribed, isFalse);
      expect(deckB!.isSubscribed, isTrue);
      final pushes = delivered('app_state');
      expect(pushes.length, 1);
      final payload = jsonDecode(pushes.single.payload) as Map<String, dynamic>;
      expect(payload['deck_subscriptions'], {
        'ext-a': false,
        'ext-b': true,
      });
    });
  });

  group('triggers and failure', () {
    test('cold-start restore is throttled by sync.last_pull', () async {
      final now = DateTime.now();
      await db.metaDao.set(
        RestoreService.lastPullMetaKey,
        now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch
            .toString(),
      );
      expect(await service.maybeRestoreOnColdStart(now: now), isNull);

      await db.metaDao.set(
        RestoreService.lastPullMetaKey,
        now
            .subtract(const Duration(hours: 7))
            .millisecondsSinceEpoch
            .toString(),
      );
      final summary = await service.maybeRestoreOnColdStart(now: now);
      expect(summary, isNotNull);
      expect(summary!.failed, isFalse);
      // A successful pull re-stamps the throttle key.
      expect(
        await db.metaDao.get(RestoreService.lastPullMetaKey),
        now.millisecondsSinceEpoch.toString(),
      );
    });

    test('cold-start restore never runs signed out', () async {
      transport.signedIn = false;
      expect(await service.maybeRestoreOnColdStart(), isNull);
    });

    test('a failing pull reports failed and leaves local state alone',
        () async {
      await db.metaDao.set(ProfileService.kXp, '100');
      api.fail = true;

      final summary = await service.restoreNow();

      expect(summary.failed, isTrue);
      expect(summary.cardsRestored, 0);
      expect(await db.metaDao.get(ProfileService.kXp), '100');
      expect(
        await db.metaDao.get(RestoreService.lastPullMetaKey),
        isNull,
        reason: 'failed pulls must not re-stamp the throttle',
      );
    });
  });
}
