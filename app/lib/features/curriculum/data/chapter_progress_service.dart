import 'package:drift/drift.dart';

import '../../../core/database/drift/app_database.dart';
import '../domain/curriculum.dart';

/// Tracks the player's position inside a [Season]. Read on every home-screen
/// render; advanced by the daily-round controller after each round completes.
///
/// The advancement rules:
///   1. First call to [currentProgress] for a season auto-creates a
///      Chapter 1 entry (dayInChapter=1, roundsCompleted=0).
///   2. [recordRoundCompletion] increments `dayInChapter` and
///      `roundsCompleted`. When `dayInChapter` would exceed `chapter.days`,
///      the chapter is marked complete and the next chapter's entry is
///      created (dayInChapter=1 again).
///   3. After the final chapter completes, [currentProgress] returns null —
///      the season is done. UI shows a "season complete" state.
class ChapterProgressService {
  ChapterProgressService(this._db);

  final AppDatabase _db;

  static const String defaultUserId = 'local-user';

  /// Returns the current (in-progress) chapter entry for [season]. Creates
  /// a Chapter 1 entry on first call. Returns null when every chapter in
  /// the season has been completed.
  ///
  /// Uses curriculum chapter order (not completedAt timestamps) as the
  /// source of truth for "where am I" — tests complete multiple chapters
  /// within the same second so timestamp ordering is unstable.
  Future<ChapterProgressEntry?> currentProgress(
    Curriculum curriculum, {
    String userId = defaultUserId,
  }) async {
    final seasonId = curriculum.season.id;
    final existing = await _db.chapterProgressDao.getInProgress(
      userId: userId,
      seasonId: seasonId,
    );
    if (existing != null) return existing;

    // No in-progress entry. Walk the chapters in declaration order and
    // seed the first one whose entry doesn't yet exist. That's the next
    // chapter to start. If every chapter already has a row (and none are
    // in progress, per the check above), the season is complete.
    final all = await _db.chapterProgressDao.listForSeason(
      userId: userId,
      seasonId: seasonId,
    );
    final completedIds = {
      for (final e in all)
        if (e.completedAt != null) e.chapterId,
    };
    for (final chapter in curriculum.chapters) {
      if (!completedIds.contains(chapter.id)) {
        return _startChapter(chapter,
            userId: userId, seasonId: seasonId,);
      }
    }
    return null; // Season complete.
  }

  /// Returns true if the season has any completed chapters yet. Used by the
  /// home screen to decide between "Start Chapter 1" and "Continue".
  Future<bool> hasStartedSeason(
    String seasonId, {
    String userId = defaultUserId,
  }) async {
    final all = await _db.chapterProgressDao.listForSeason(
      userId: userId,
      seasonId: seasonId,
    );
    return all.isNotEmpty;
  }

  /// Returns all chapter entries (in-progress + completed) for the season,
  /// in start-order. Drives the Season Spine widget.
  Future<List<ChapterProgressEntry>> seasonProgress(
    String seasonId, {
    String userId = defaultUserId,
  }) => _db.chapterProgressDao.listForSeason(
      userId: userId,
      seasonId: seasonId,
    );

  /// Called by the daily-round controller after a round completes. Advances
  /// `dayInChapter`. If that pushes past `chapter.days`, marks the chapter
  /// complete; the next call to [currentProgress] will seed the next
  /// chapter automatically.
  ///
  /// Returns the resulting entry (either the same chapter with incremented
  /// day, or the just-completed chapter row).
  Future<ChapterProgressEntry> recordRoundCompletion(
    Curriculum curriculum, {
    String userId = defaultUserId,
  }) async {
    final current = await _db.chapterProgressDao.getInProgress(
      userId: userId,
      seasonId: curriculum.season.id,
    );
    if (current == null) {
      throw StateError(
        'recordRoundCompletion called with no in-progress chapter. '
        'Call currentProgress first to seed.',
      );
    }
    final chapter = curriculum.chapterById(current.chapterId);
    if (chapter == null) {
      throw StateError(
        'In-progress chapter ${current.chapterId} not found in curriculum.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newDay = current.dayInChapter + 1;
    final newRounds = current.roundsCompleted + 1;
    final isChapterDone = newDay > chapter.days;

    final updated = ChapterProgressCompanion(
      userId: Value(current.userId),
      seasonId: Value(current.seasonId),
      chapterId: Value(current.chapterId),
      dayInChapter: Value(isChapterDone ? chapter.days : newDay),
      roundsCompleted: Value(newRounds),
      startedAt: Value(current.startedAt),
      completedAt: Value(isChapterDone ? now : null),
      updatedAt: Value(now),
    );
    await _db.chapterProgressDao.upsert(updated);

    return ChapterProgressEntry(
      userId: current.userId,
      seasonId: current.seasonId,
      chapterId: current.chapterId,
      dayInChapter: isChapterDone ? chapter.days : newDay,
      roundsCompleted: newRounds,
      startedAt: current.startedAt,
      completedAt: isChapterDone ? now : null,
      updatedAt: now,
    );
  }

  Future<ChapterProgressEntry> _startChapter(
    Chapter chapter, {
    required String userId,
    required String seasonId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = ChapterProgressCompanion(
      userId: Value(userId),
      seasonId: Value(seasonId),
      chapterId: Value(chapter.id),
      dayInChapter: const Value(1),
      roundsCompleted: const Value(0),
      startedAt: Value(now),
      completedAt: const Value(null),
      updatedAt: Value(now),
    );
    await _db.chapterProgressDao.upsert(entry);
    return ChapterProgressEntry(
      userId: userId,
      seasonId: seasonId,
      chapterId: chapter.id,
      dayInChapter: 1,
      roundsCompleted: 0,
      startedAt: now,
      updatedAt: now,
    );
  }
}
