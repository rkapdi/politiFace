import '../../../core/database/drift/app_database.dart';

/// User-facing preferences. Stored in sync_meta so no schema migration is
/// needed, and they survive app restart.
class SettingsService {
  SettingsService(this._db);
  final AppDatabase _db;

  static const _kReminders = 'settings.daily_reminder';
  static const _kAnalytics = 'settings.analytics_opt_in';

  Future<bool> remindersEnabled() async =>
      (await _db.metaDao.get(_kReminders)) == '1';

  Future<void> setRemindersEnabled(bool value) =>
      _db.metaDao.set(_kReminders, value ? '1' : '0');

  Future<bool> analyticsEnabled() async =>
      (await _db.metaDao.get(_kAnalytics)) == '1';

  Future<void> setAnalyticsEnabled(bool value) =>
      _db.metaDao.set(_kAnalytics, value ? '1' : '0');

  /// Wipes every user-state row but leaves content (cards/decks/gov nodes) in
  /// place so the user can start fresh without re-downloading.
  Future<void> resetProgress() async {
    await _db.transaction(() async {
      await _db.delete(_db.cardMemoryStates).go();
      await _db.delete(_db.reviewLogs).go();
      await _db.delete(_db.userNodeProgress).go();
      await _db.delete(_db.dailyChallengeCaches).go();
      // Clear gamification + seed flags so seeds re-run + onboarding shows again.
      await _db.delete(_db.syncMeta).go();
    });
  }
}
