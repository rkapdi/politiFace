// lib/core/sync/app_state_sync.dart
//
// Builds and pushes the 'app_state' outbox event: the small cross-device
// snapshot of chapter position, XP, and the deck-subscription map (all
// decks, keyed by external id). Enqueued at round/session completion and on
// subscription toggles, never per XP tick; the server row is a plain upsert
// so the newest snapshot wins.

import '../../features/curriculum/data/chapter_progress_service.dart';
import '../../features/curriculum/domain/curriculum.dart';
import '../../features/profile/data/profile_service.dart';
import '../database/drift/app_database.dart';
import 'sync_engine.dart';

class AppStateSnapshot {
  const AppStateSnapshot({
    required this.chapterNumber,
    required this.dayInChapter,
    required this.xp,
    required this.deckSubscriptions,
  });

  /// 1-based curriculum order of the chapter the player is on.
  final int chapterNumber;
  final int dayInChapter;
  final int xp;

  /// Deck external id -> subscribed, covering every seeded deck.
  final Map<String, bool> deckSubscriptions;
}

/// Reads the local state that feeds the 'app_state' payload.
Future<AppStateSnapshot> readLocalAppState(
  AppDatabase db,
  Curriculum curriculum,
) async {
  final (chapterNumber, dayInChapter) =
      await readLocalChapterPosition(db, curriculum);
  final xp = int.tryParse(await db.metaDao.get(ProfileService.kXp) ?? '') ?? 0;
  final decks = await db.decksDao.allDecks();
  return AppStateSnapshot(
    chapterNumber: chapterNumber,
    dayInChapter: dayInChapter,
    xp: xp,
    deckSubscriptions: {for (final d in decks) d.externalId: d.isSubscribed},
  );
}

/// The player's position as (chapterNumber, dayInChapter): the next round
/// they would play. A completed season maps to the final chapter's final
/// day (the furthest expressible position).
Future<(int, int)> readLocalChapterPosition(
  AppDatabase db,
  Curriculum curriculum,
) async {
  final entries = await db.chapterProgressDao.listForSeason(
    userId: ChapterProgressService.defaultUserId,
    seasonId: curriculum.season.id,
  );
  ChapterProgressEntry? inProgress;
  final completedIds = <String>{};
  for (final e in entries) {
    if (e.completedAt == null) {
      inProgress = e;
    } else {
      completedIds.add(e.chapterId);
    }
  }
  if (inProgress != null) {
    final chapter = curriculum.chapterById(inProgress.chapterId);
    if (chapter != null) {
      return (chapter.order, inProgress.dayInChapter.clamp(1, chapter.days));
    }
  }
  for (final chapter in curriculum.chapters) {
    if (!completedIds.contains(chapter.id)) return (chapter.order, 1);
  }
  final last = curriculum.chapters.isEmpty ? null : curriculum.chapters.last;
  return (last?.order ?? 1, last?.days ?? 1);
}

/// Enqueues one app_state upsert reflecting the current local state.
/// No-op when signed out or unconfigured; best-effort, never throws.
Future<void> pushAppState({
  required AppDatabase db,
  required SyncEngine sync,
  required Curriculum curriculum,
}) async {
  if (!sync.isActive) return;
  try {
    final s = await readLocalAppState(db, curriculum);
    await sync.enqueueAppState(
      chapterNumber: s.chapterNumber,
      dayInChapter: s.dayInChapter,
      xp: s.xp,
      deckSubscriptions: s.deckSubscriptions,
    );
  } catch (_) {
    // A failed snapshot must never surface: the next completion retries.
  }
}
