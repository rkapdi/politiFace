import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'chapter_progress_dao.g.dart';

/// Low-level CRUD over [ChapterProgress]. Business rules (advancing to the
/// next chapter when reaching `days`, season-completion handling) live in
/// `ChapterProgressService` — this DAO just talks to the table.
@DriftAccessor(tables: [ChapterProgress])
class ChapterProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ChapterProgressDaoMixin {
  ChapterProgressDao(AppDatabase db) : super(db);

  /// Returns the in-progress chapter entry for this user + season, or null
  /// if no chapter has been started yet. There is at most one in-progress
  /// chapter per season at any time (enforced by the service layer).
  Future<ChapterProgressEntry?> getInProgress({
    required String userId,
    required String seasonId,
  }) {
    return (select(chapterProgress)
          ..where((t) =>
              t.userId.equals(userId) &
              t.seasonId.equals(seasonId) &
              t.completedAt.isNull()))
        .getSingleOrNull();
  }

  /// Returns the specific chapter entry if it exists (in-progress OR
  /// completed). Used by [insertOrAdvance] to decide insert vs. update.
  Future<ChapterProgressEntry?> get({
    required String userId,
    required String seasonId,
    required String chapterId,
  }) {
    return (select(chapterProgress)
          ..where((t) =>
              t.userId.equals(userId) &
              t.seasonId.equals(seasonId) &
              t.chapterId.equals(chapterId)))
        .getSingleOrNull();
  }

  /// Returns all entries for this user + season, ordered by startedAt
  /// ascending. Used by the home-screen Season Spine widget to render
  /// completed chapters with checkmarks.
  Future<List<ChapterProgressEntry>> listForSeason({
    required String userId,
    required String seasonId,
  }) {
    return (select(chapterProgress)
          ..where((t) =>
              t.userId.equals(userId) & t.seasonId.equals(seasonId))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<void> upsert(ChapterProgressCompanion entry) {
    return into(chapterProgress).insertOnConflictUpdate(entry);
  }

  /// Test/debug helper: wipe all chapter progress for a user. Not used in
  /// app code — exposed for tests that need a clean slate between cases.
  Future<int> deleteAllForUser(String userId) {
    return (delete(chapterProgress)..where((t) => t.userId.equals(userId)))
        .go();
  }
}
