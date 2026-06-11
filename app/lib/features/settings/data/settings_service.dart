import 'package:flutter/material.dart';

import '../../../core/database/drift/app_database.dart';

/// User-facing preferences. Stored in app_meta so no schema migration is
/// needed, and they survive app restart.
class SettingsService {
  SettingsService(this._db);
  final AppDatabase _db;

  static const _kReminders = 'settings.daily_reminder';
  static const _kAnalytics = 'settings.analytics_opt_in';
  static const _kThemeMode = 'settings.theme_mode';

  Future<bool> remindersEnabled() async =>
      (await _db.metaDao.get(_kReminders)) == '1';

  Future<void> setRemindersEnabled(bool value) =>
      _db.metaDao.set(_kReminders, value ? '1' : '0');

  Future<bool> analyticsEnabled() async =>
      (await _db.metaDao.get(_kAnalytics)) == '1';

  Future<void> setAnalyticsEnabled(bool value) =>
      _db.metaDao.set(_kAnalytics, value ? '1' : '0');

  /// Persisted ThemeMode. Defaults to system when unset so first-launch
  /// users get whatever their phone is on.
  Future<ThemeMode> themeMode() async {
    final raw = await _db.metaDao.get(_kThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _db.metaDao.set(_kThemeMode, _wireName(mode));
  }

  String _wireName(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Wipes every user-state row but leaves content (cards/decks/gov nodes) in
  /// place so the user can start fresh without re-downloading.
  Future<void> resetProgress() async {
    await _db.transaction(() async {
      await _db.delete(_db.cardMemoryStates).go();
      await _db.delete(_db.reviewLogs).go();
      await _db.delete(_db.userNodeProgress).go();
      // Clear gamification + seed flags so seeds re-run + onboarding shows again.
      await _db.delete(_db.appMeta).go();
    });
  }
}
