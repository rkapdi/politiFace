import '../../../core/database/drift/app_database.dart';
import '../../session/domain/fsrs_algorithm.dart';

class UserProfile {
  const UserProfile({
    required this.streakDays,
    required this.lastReviewDate,
    required this.xpTotal,
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
  });

  final int streakDays;
  final String? lastReviewDate; // YYYY-MM-DD
  final int xpTotal;
  final int level;
  final int xpInLevel; // 0..xpForNextLevel
  final int xpForNextLevel; // amount needed to hit next level

  static const empty = UserProfile(
    streakDays: 0,
    lastReviewDate: null,
    xpTotal: 0,
    level: 1,
    xpInLevel: 0,
    xpForNextLevel: 100,
  );
}

/// Reads / writes user-level gamification state. Stored as `sync_meta` rows
/// so we avoid a schema migration. Each call is independent of FSRS state.
class ProfileService {
  ProfileService(this._db);
  final AppDatabase _db;

  // Public: RestoreService and the app-state sync payload read/write the
  // same rows when merging cross-device progress.
  static const kStreak = 'profile.streak_count';
  static const kLastReview = 'profile.streak_last_review_date';
  static const kXp = 'profile.xp_total';

  // XP per grade. Tuned to make a 5-card daily session worth ~50xp on Goods.
  static const xpForAgain = 2;
  static const xpForHard = 6;
  static const xpForGood = 10;
  static const xpForEasy = 14;

  Future<UserProfile> load() async {
    final streak = int.tryParse(await _db.metaDao.get(kStreak) ?? '') ?? 0;
    final lastDate = await _db.metaDao.get(kLastReview);
    final xp = int.tryParse(await _db.metaDao.get(kXp) ?? '') ?? 0;
    return _profileFromRaw(streak: streak, lastDate: lastDate, xp: xp);
  }

  /// Award XP and bump the streak appropriately. Returns the new profile.
  Future<UserProfile> recordReview({
    required FSRSGrade grade,
    DateTime? now,
  }) async {
    final reviewedAt = now ?? DateTime.now();
    final today = _dateKey(reviewedAt);

    var streak = int.tryParse(await _db.metaDao.get(kStreak) ?? '') ?? 0;
    final lastDate = await _db.metaDao.get(kLastReview);
    var xp = int.tryParse(await _db.metaDao.get(kXp) ?? '') ?? 0;

    if (lastDate != today) {
      // First review of a new calendar day.
      streak = _nextStreak(
          previousDate: lastDate, today: today, currentStreak: streak);
    }

    xp += xpForGrade(grade);

    await _db.metaDao.set(kStreak, streak.toString());
    await _db.metaDao.set(kLastReview, today);
    await _db.metaDao.set(kXp, xp.toString());

    return _profileFromRaw(streak: streak, lastDate: today, xp: xp);
  }

  static int xpForGrade(FSRSGrade g) {
    switch (g) {
      case FSRSGrade.again:
        return xpForAgain;
      case FSRSGrade.hard:
        return xpForHard;
      case FSRSGrade.good:
        return xpForGood;
      case FSRSGrade.easy:
        return xpForEasy;
    }
  }

  /// Pure: derive level/breakdown from raw xp + streak. Public for testability.
  static UserProfile _profileFromRaw({
    required int streak,
    required String? lastDate,
    required int xp,
  }) {
    final (level, xpInLevel, xpForNextLevel) = _levelBreakdown(xp);
    return UserProfile(
      streakDays: streak,
      lastReviewDate: lastDate,
      xpTotal: xp,
      level: level,
      xpInLevel: xpInLevel,
      xpForNextLevel: xpForNextLevel,
    );
  }

  /// Triangular leveling — Level N requires N * 100 XP within that level.
  /// Level 1 → 0..100, Level 2 → 100..300, Level 3 → 300..600, etc.
  static (int level, int xpInLevel, int xpForNextLevel) _levelBreakdown(
      int xp) {
    var remaining = xp;
    var level = 1;
    while (true) {
      final cost = level * 100;
      if (remaining < cost) {
        return (level, remaining, cost);
      }
      remaining -= cost;
      level++;
      // Safety: huge XP values shouldn't loop forever
      if (level > 1000) return (level, remaining, level * 100);
    }
  }

  /// Streak rule:
  /// - first ever review        → 1
  /// - previous review yesterday → +1
  /// - previous review today    → unchanged (caller checks this branch)
  /// - older / null             → reset to 1
  static int _nextStreak({
    required String? previousDate,
    required String today,
    required int currentStreak,
  }) {
    if (previousDate == null) return 1;
    if (previousDate == _yesterdayOf(today)) return currentStreak + 1;
    return 1;
  }

  static String _dateKey(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _yesterdayOf(String today) {
    final parts = today.split('-');
    final dt =
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final y = dt.subtract(const Duration(days: 1));
    return _dateKey(y);
  }
}
