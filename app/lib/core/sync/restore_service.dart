// lib/core/sync/restore_service.dart
//
// Cross-device restore: pulls the signed-in user's server-side state
// (public.card_states, public.user_app_state, public.streaks) and merges it
// into the local Drift database. The client owns the merge; the server rows
// are dumb snapshots (see 20260721000100_cross_device_state.sql).
//
// Merge rules:
//   - per card: newest last_reviewed_at wins. Local-newer cards are kept
//     AND pushed back up; server card ids with no local card are skipped
//     (content mismatch between app versions is expected, not an error).
//   - chapter position: the FURTHER position wins (chapter, then day).
//   - XP: max wins. Streak: adopt server current when it is at least the
//     local run. Deck subscriptions: the server map applies to decks that
//     exist locally.
//   - whenever local state is ahead of the server, one app_state push is
//     enqueued so the server catches up.
//
// The whole pass is idempotent (running it twice restores nothing new) and
// never throws to the UI: failures log and no-op.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../features/curriculum/data/chapter_progress_service.dart';
import '../../features/curriculum/domain/curriculum.dart';
import '../../features/profile/data/profile_service.dart';
import '../../features/session/domain/fsrs_algorithm.dart';
import '../database/drift/app_database.dart';
import 'app_state_sync.dart';
import 'sync_engine.dart';

/// What a restore pass changed, so the UI can (optionally) mention it.
class RestoreSummary {
  const RestoreSummary({
    required this.cardsRestored,
    required this.appStateChanged,
    this.failed = false,
  });

  /// Cards whose local FSRS state was overwritten from the server.
  final int cardsRestored;

  /// Whether chapter position, XP, streak, or deck subscriptions changed.
  final bool appStateChanged;

  /// True when the pull failed; local state is untouched.
  final bool failed;

  static const empty = RestoreSummary(cardsRestored: 0, appStateChanged: false);
}

/// Read side of the cross-device tables. Behind an interface so the merge
/// logic is unit-testable without a server.
abstract class RestoreApi {
  Future<Map<String, dynamic>?> fetchAppState();
  Future<List<Map<String, dynamic>>> fetchCardStates();
  Future<Map<String, dynamic>?> fetchStreak();
}

class SupabaseRestoreApi implements RestoreApi {
  SupabaseRestoreApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchAppState() =>
      _client.from('user_app_state').select().maybeSingle();

  @override
  Future<List<Map<String, dynamic>>> fetchCardStates() async {
    // RLS scopes rows to the signed-in user. The explicit limit is a
    // guardrail well above any realistic per-user card count.
    final rows = await _client.from('card_states').select().limit(5000);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>?> fetchStreak() =>
      _client.from('streaks').select().maybeSingle();
}

/// Per-card merge outcome. Pure decision so tests can cover the matrix.
enum CardMergeDecision { takeServer, pushLocal, skip }

/// Newest-wins on last_reviewed_at (unix seconds). Null means "no real
/// review on that side" (no row, isNew, or a zero sentinel).
CardMergeDecision decideCardMerge({
  required int? localLastReviewedAt,
  required int? serverLastReviewedAt,
}) {
  if (serverLastReviewedAt == null) {
    return localLastReviewedAt == null
        ? CardMergeDecision.skip
        : CardMergeDecision.pushLocal;
  }
  if (localLastReviewedAt == null) return CardMergeDecision.takeServer;
  if (serverLastReviewedAt > localLastReviewedAt) {
    return CardMergeDecision.takeServer;
  }
  if (serverLastReviewedAt < localLastReviewedAt) {
    return CardMergeDecision.pushLocal;
  }
  return CardMergeDecision.skip; // same instant: already in sync
}

class RestoreService {
  RestoreService({
    required AppDatabase db,
    required RestoreApi? api,
    required SyncEngine sync,
    required Future<Curriculum> Function() loadCurriculum,
    FSRS fsrs = const FSRS(),
  })  : _db = db,
        _api = api,
        _sync = sync,
        _loadCurriculum = loadCurriculum,
        _fsrs = fsrs;

  final AppDatabase _db;
  final RestoreApi? _api;
  final SyncEngine _sync;
  final Future<Curriculum> Function() _loadCurriculum;
  final FSRS _fsrs;

  /// AppMeta key holding the last successful pull (unix ms).
  static const lastPullMetaKey = 'sync.last_pull';

  /// Cold-start pulls are throttled to at most one per this interval.
  static const pullInterval = Duration(hours: 6);

  /// Cold-start trigger: runs a restore only when signed in and the last
  /// pull is older than [pullInterval]. Returns null when skipped.
  Future<RestoreSummary?> maybeRestoreOnColdStart({DateTime? now}) async {
    if (_api == null || !_sync.isActive) return null;
    final clock = now ?? DateTime.now();
    try {
      final last = int.tryParse(await _db.metaDao.get(lastPullMetaKey) ?? '');
      if (last != null &&
          clock.millisecondsSinceEpoch - last < pullInterval.inMilliseconds) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return restoreNow(now: clock);
  }

  /// Full pull + merge. Safe to run repeatedly; never throws.
  Future<RestoreSummary> restoreNow({DateTime? now}) async {
    final api = _api;
    if (api == null || !_sync.isActive) return RestoreSummary.empty;
    final clock = now ?? DateTime.now();
    try {
      final serverApp = await api.fetchAppState();
      final serverCards = await api.fetchCardStates();
      final serverStreak = await api.fetchStreak();

      final cardsRestored = await _mergeCardStates(serverCards, clock);
      final appStateChanged =
          await _mergeAppState(serverApp, serverStreak, clock);

      await _db.metaDao
          .set(lastPullMetaKey, clock.millisecondsSinceEpoch.toString());
      return RestoreSummary(
        cardsRestored: cardsRestored,
        appStateChanged: appStateChanged,
      );
    } catch (e, st) {
      // Restore is opportunistic: log, leave local state alone, move on.
      debugPrint('[restore] pull failed: $e\n$st');
      return const RestoreSummary(
        cardsRestored: 0,
        appStateChanged: false,
        failed: true,
      );
    }
  }

  // ── Cards ────────────────────────────────────────────────────────────────

  Future<int> _mergeCardStates(
    List<Map<String, dynamic>> serverRows,
    DateTime now,
  ) async {
    if (serverRows.isEmpty) return 0;
    final byExternalId = <String, Map<String, dynamic>>{
      for (final row in serverRows)
        if (row['card_id'] is String) row['card_id'] as String: row,
    };
    // Only server ids that resolve to a local card are considered; unknown
    // ids (content mismatch across app versions) are skipped silently.
    final localCards =
        await _db.cardsDao.cardsByExternalIds(byExternalId.keys.toList());

    var restored = 0;
    for (final card in localCards) {
      final server = byExternalId[card.externalId];
      if (server == null) continue;
      final local = await _db.reviewsDao.stateFor(card.id);
      final localLastReviewed = (local == null || local.isNew)
          ? null
          : (local.lastReviewedAt > 0 ? local.lastReviewedAt : null);
      final decision = decideCardMerge(
        localLastReviewedAt: localLastReviewed,
        serverLastReviewedAt:
            _unixFromIso(server['last_reviewed_at'] as String?),
      );
      switch (decision) {
        case CardMergeDecision.takeServer:
          await _overwriteLocalCardState(card.id, server, now);
          restored++;
        case CardMergeDecision.pushLocal:
          if (local != null) {
            await _sync.enqueueCardState(
              cardExternalId: card.externalId,
              state: local,
            );
          }
        case CardMergeDecision.skip:
          break;
      }
    }
    return restored;
  }

  Future<void> _overwriteLocalCardState(
    String cardId,
    Map<String, dynamic> server,
    DateTime now,
  ) async {
    final stability = (server['stability'] as num?)?.toDouble() ?? 1.0;
    final difficulty = (server['difficulty'] as num?)?.toDouble() ?? 5.0;
    final lastReviewedAt =
        _unixFromIso(server['last_reviewed_at'] as String?) ?? 0;
    // A missing due_at degrades to "due now-ish" rather than never-due.
    final nextReviewAt =
        _unixFromIso(server['due_at'] as String?) ?? lastReviewedAt;
    final elapsedDays =
        (now.millisecondsSinceEpoch / 1000 - lastReviewedAt) / 86400.0;
    final retrievability = _fsrs
        .retrievabilityCurve(elapsedDays < 0 ? 0 : elapsedDays, stability)
        .clamp(0.0, 1.0);
    final intervalSeconds = nextReviewAt - lastReviewedAt;
    final intervalDays =
        intervalSeconds <= 0 ? 1 : (intervalSeconds / 86400.0).round();

    await _db.reviewsDao.upsertState(
      CardMemoryStatesCompanion(
        cardId: Value(cardId),
        stability: Value(stability),
        difficulty: Value(difficulty),
        retrievability: Value(retrievability),
        lastReviewedAt: Value(lastReviewedAt),
        nextReviewAt: Value(nextReviewAt),
        intervalDays: Value(intervalDays < 1 ? 1 : intervalDays),
        lapses: Value((server['lapses'] as num?)?.toInt() ?? 0),
        reviewCount: Value((server['reps'] as num?)?.toInt() ?? 0),
        isNew: Value((server['is_new'] as bool?) ?? false),
      ),
    );
  }

  // ── App state (chapter, XP, streak, deck subscriptions) ─────────────────

  Future<bool> _mergeAppState(
    Map<String, dynamic>? serverApp,
    Map<String, dynamic>? serverStreak,
    DateTime now,
  ) async {
    final curriculum = await _loadCurriculum();
    var changed = false;
    var localAhead = false;

    // Chapter position: the further position wins. A missing server row
    // reads as the starting position (1, 1).
    final serverChapter = (serverApp?['chapter_number'] as num?)?.toInt() ?? 1;
    final serverDay = (serverApp?['day_in_chapter'] as num?)?.toInt() ?? 1;
    final (localChapter, localDay) =
        await readLocalChapterPosition(_db, curriculum);
    if (_isFurther(serverChapter, serverDay, localChapter, localDay)) {
      await _applyServerPosition(curriculum, serverChapter, serverDay, now);
      changed = true;
    } else if (_isFurther(localChapter, localDay, serverChapter, serverDay)) {
      localAhead = true;
    }

    // XP: max wins.
    final serverXp = (serverApp?['xp'] as num?)?.toInt() ?? 0;
    final localXp =
        int.tryParse(await _db.metaDao.get(ProfileService.kXp) ?? '') ?? 0;
    if (serverXp > localXp) {
      await _db.metaDao.set(ProfileService.kXp, serverXp.toString());
      changed = true;
    } else if (localXp > serverXp) {
      localAhead = true;
    }

    // Streak: adopt the server run when it is at least the local one. The
    // last-active date comes along (when newer) so the run survives the
    // next local play instead of resetting.
    if (serverStreak != null) {
      final serverCurrent = (serverStreak['current'] as num?)?.toInt() ?? 0;
      final localCurrent =
          int.tryParse(await _db.metaDao.get(ProfileService.kStreak) ?? '') ??
              0;
      if (serverCurrent >= localCurrent) {
        if (serverCurrent != localCurrent) {
          await _db.metaDao
              .set(ProfileService.kStreak, serverCurrent.toString());
          changed = true;
        }
        final serverDate = serverStreak['last_active_date'] as String?;
        final localDate = await _db.metaDao.get(ProfileService.kLastReview);
        if (serverDate != null &&
            (localDate == null || serverDate.compareTo(localDate) > 0)) {
          await _db.metaDao.set(ProfileService.kLastReview, serverDate);
          changed = true;
        }
      }
    }

    // Deck subscriptions: the server map applies to decks that exist
    // locally; decks the server has never heard of stay as they are and
    // trigger one catch-up push.
    final rawMap = serverApp?['deck_subscriptions'];
    final serverMap = rawMap is Map ? rawMap : const <String, dynamic>{};
    final localDecks = await _db.decksDao.allDecks();
    for (final deck in localDecks) {
      final serverValue = serverMap[deck.externalId];
      if (serverValue is bool) {
        if (serverValue != deck.isSubscribed) {
          await _db.decksDao
              .setSubscribed(deckId: deck.id, subscribed: serverValue);
          changed = true;
        }
      } else {
        localAhead = true;
      }
    }

    if (localAhead) {
      // One app_state push carries the whole merged snapshot up.
      await pushAppState(db: _db, sync: _sync, curriculum: curriculum);
    }
    return changed;
  }

  /// True when position (c1, d1) is strictly further than (c2, d2).
  bool _isFurther(int c1, int d1, int c2, int d2) =>
      c1 > c2 || (c1 == c2 && d1 > d2);

  /// Rewrites chapter_progress so the season position matches the server:
  /// chapters before the target are marked complete, the target chapter is
  /// in progress at the server day. Later chapters are left untouched.
  Future<void> _applyServerPosition(
    Curriculum curriculum,
    int serverChapter,
    int serverDay,
    DateTime now,
  ) async {
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
    final seasonId = curriculum.season.id;
    const userId = ChapterProgressService.defaultUserId;
    for (final chapter in curriculum.chapters) {
      if (chapter.order > serverChapter) break;
      final existing = await _db.chapterProgressDao.get(
        userId: userId,
        seasonId: seasonId,
        chapterId: chapter.id,
      );
      if (chapter.order < serverChapter) {
        if (existing?.completedAt != null) continue;
        await _db.chapterProgressDao.upsert(
          ChapterProgressCompanion(
            userId: const Value(userId),
            seasonId: Value(seasonId),
            chapterId: Value(chapter.id),
            dayInChapter: Value(chapter.days),
            roundsCompleted: Value(existing?.roundsCompleted ?? chapter.days),
            startedAt: Value(existing?.startedAt ?? nowUnix),
            completedAt: Value(nowUnix),
            updatedAt: Value(nowUnix),
          ),
        );
      } else {
        final day = serverDay.clamp(1, chapter.days);
        await _db.chapterProgressDao.upsert(
          ChapterProgressCompanion(
            userId: const Value(userId),
            seasonId: Value(seasonId),
            chapterId: Value(chapter.id),
            dayInChapter: Value(day),
            roundsCompleted: Value(
              (existing?.roundsCompleted ?? 0) > day - 1
                  ? existing!.roundsCompleted
                  : day - 1,
            ),
            startedAt: Value(existing?.startedAt ?? nowUnix),
            completedAt: const Value(null),
            updatedAt: Value(nowUnix),
          ),
        );
      }
    }
  }

  /// ISO-8601 -> unix seconds, null on absent or unparseable input.
  int? _unixFromIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return parsed.millisecondsSinceEpoch ~/ 1000;
  }
}
