import 'dart:convert';

import '../../../core/database/drift/app_database.dart';

/// Snapshot of an in-progress session — enough to rebuild it when the app
/// relaunches after a background-kill / crash / force-quit.
///
/// `pendingCardIds` is the queue ordering at the moment of persist, after
/// any graded cards have already been removed. So restore = "treat these
/// card ids as the remaining session in this exact order".
class PendingSessionSnapshot {
  const PendingSessionSnapshot({
    required this.deckId,
    required this.pendingCardIds,
    required this.completed,
    required this.correct,
    required this.again,
    required this.totalPlanned,
    required this.gradeHistory,
    required this.reviewedCardIds,
    required this.savedAtUnix,
  });

  final String? deckId;             // null = global / FSRS-driven
  final List<String> pendingCardIds; // remaining cards, in order
  final int completed;
  final int correct;
  final int again;
  final int totalPlanned;
  final List<int> gradeHistory;     // FSRSGrade.value sequence
  final List<String> reviewedCardIds; // cards already graded, in order
  final int savedAtUnix;            // when this snapshot was written

  Map<String, dynamic> toJson() => {
        'deckId': deckId,
        'pendingCardIds': pendingCardIds,
        'completed': completed,
        'correct': correct,
        'again': again,
        'totalPlanned': totalPlanned,
        'gradeHistory': gradeHistory,
        'reviewedCardIds': reviewedCardIds,
        'savedAtUnix': savedAtUnix,
      };

  static PendingSessionSnapshot? fromJsonOrNull(Map<String, dynamic> j) {
    try {
      return PendingSessionSnapshot(
        // Note: snapshots written before v1.2 may carry a now-ignored
        // 'dailyChallengeDate' key from the removed daily-challenge flow.
        deckId: j['deckId'] as String?,
        pendingCardIds:
            (j['pendingCardIds'] as List).map((e) => e as String).toList(),
        completed: j['completed'] as int,
        correct: j['correct'] as int,
        again: j['again'] as int,
        totalPlanned: j['totalPlanned'] as int,
        gradeHistory:
            (j['gradeHistory'] as List).map((e) => e as int).toList(),
        // Older snapshots (pre-fly-to) don't have this field — treat as empty.
        reviewedCardIds: ((j['reviewedCardIds'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        savedAtUnix: j['savedAtUnix'] as int,
      );
    } catch (_) {
      // Corrupt/old snapshot — treat as no pending session.
      return null;
    }
  }
}

/// Persists [PendingSessionSnapshot] to `app_meta` so no schema migration is
/// needed. Snapshots older than 24h are treated as stale (auto-discarded).
class PendingSessionStore {
  PendingSessionStore(this._db);
  final AppDatabase _db;

  static const _key = 'pending_session.v1';
  static const _maxAge = Duration(hours: 24);

  /// Returns the snapshot if one exists and is recent enough; otherwise null.
  /// Stale snapshots are auto-cleared so callers don't keep tripping over them.
  Future<PendingSessionSnapshot?> load() async {
    final raw = await _db.metaDao.get(_key);
    if (raw == null || raw.isEmpty) return null;
    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await clear();
      return null;
    }
    final snap = PendingSessionSnapshot.fromJsonOrNull(map);
    if (snap == null) {
      await clear();
      return null;
    }
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ageSeconds = nowSeconds - snap.savedAtUnix;
    if (ageSeconds > _maxAge.inSeconds) {
      await clear();
      return null;
    }
    return snap;
  }

  Future<void> save(PendingSessionSnapshot snap) async {
    await _db.metaDao.set(_key, jsonEncode(snap.toJson()));
  }

  Future<void> clear() async {
    // Setting empty string is effectively a delete for our string-based store.
    await _db.metaDao.set(_key, '');
  }
}
