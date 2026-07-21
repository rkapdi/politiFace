import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/core/sync/app_state_sync.dart';
import 'package:politiface/core/sync/sync_engine.dart';
import 'package:politiface/features/curriculum/data/chapter_progress_service.dart';
import 'package:politiface/features/curriculum/domain/curriculum.dart';
import 'package:politiface/features/profile/data/profile_service.dart';

class _RecordingTransport implements SyncTransport {
  _RecordingTransport({this.signedIn = true});

  bool signedIn;
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

Curriculum _curriculum() => Curriculum(
      version: 1,
      locale: 'en-US',
      season: const Season(
        id: 'season-1',
        title: 'Civic Foundations',
        subtitle: '',
        totalChapters: 2,
        estimatedDays: 6,
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
      ],
      branches: const [],
    );

Future<void> _seedDeck(
  AppDatabase db, {
  required String id,
  required String externalId,
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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('readLocalChapterPosition', () {
    test('fresh install maps to chapter 1 day 1', () async {
      expect(await readLocalChapterPosition(db, _curriculum()), (1, 1));
    });

    test('in-progress entry maps to its chapter order and day', () async {
      await db.chapterProgressDao.upsert(
        const ChapterProgressCompanion(
          userId: Value(ChapterProgressService.defaultUserId),
          seasonId: Value('season-1'),
          chapterId: Value('ch2'),
          dayInChapter: Value(2),
          roundsCompleted: Value(1),
          startedAt: Value(1000),
          completedAt: Value(null),
          updatedAt: Value(1000),
        ),
      );
      expect(await readLocalChapterPosition(db, _curriculum()), (2, 2));
    });

    test('season complete maps to final chapter final day', () async {
      for (final id in ['ch1', 'ch2']) {
        await db.chapterProgressDao.upsert(
          ChapterProgressCompanion(
            userId: const Value(ChapterProgressService.defaultUserId),
            seasonId: const Value('season-1'),
            chapterId: Value(id),
            dayInChapter: const Value(3),
            roundsCompleted: const Value(3),
            startedAt: const Value(1000),
            completedAt: const Value(2000),
            updatedAt: const Value(2000),
          ),
        );
      }
      expect(await readLocalChapterPosition(db, _curriculum()), (2, 3));
    });
  });

  group('pushAppState', () {
    test(
        'after a subscription toggle, one app_state event covers ALL decks '
        'with current flags', () async {
      await _seedDeck(db, id: 'deck-1', externalId: 'ext-a');
      await _seedDeck(db, id: 'deck-2', externalId: 'ext-b');
      await db.metaDao.set(ProfileService.kXp, '120');
      final transport = _RecordingTransport();
      final sync = SyncEngine(db, transport);

      // The toggle write path is DecksDao.setSubscribed; the sync push
      // rides behind it (see setDeckSubscribed in deck_providers.dart).
      await db.decksDao.setSubscribed(deckId: 'deck-2', subscribed: false);
      await pushAppState(db: db, sync: sync, curriculum: _curriculum());
      await sync.flush();

      final event = transport.delivered.single;
      expect(event.type, 'app_state');
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      expect(payload['deck_subscriptions'], {
        'ext-a': true,
        'ext-b': false,
      });
      expect(payload['xp'], 120);
      expect(payload['chapter_number'], 1);
      expect(payload['day_in_chapter'], 1);
    });

    test('signed out: pushAppState enqueues nothing', () async {
      final transport = _RecordingTransport(signedIn: false);
      final sync = SyncEngine(db, transport);
      await pushAppState(db: db, sync: sync, curriculum: _curriculum());
      expect(transport.delivered, isEmpty);
      expect(await db.outboxDao.pendingCount(), 0);
    });
  });
}
