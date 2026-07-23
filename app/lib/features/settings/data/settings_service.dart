import 'package:flutter/material.dart';

import '../../../core/database/drift/app_database.dart';

/// User-facing preferences. Stored in app_meta so no schema migration is
/// needed, and they survive app restart.
class SettingsService {
  SettingsService(this._db);
  final AppDatabase _db;

  static const _kReminders = 'settings.daily_reminder';
  static const _kThemeMode = 'settings.theme_mode';
  static const _kSoundEffects = 'settings.sound_effects';

  /// Key is read directly in main.dart before Sentry init — keep in sync.
  static const kCrashReports = 'settings.crash_reports';

  static const _kNotifChapter = 'notif.chapter';
  static const _kNotifWashington = 'notif.washington';
  static const _kNotifWashLaws = 'notif.wash_laws';
  static const _kNotifWashBills = 'notif.wash_bills';
  static const _kNotifWashEos = 'notif.wash_eos';

  Future<bool> remindersEnabled() async =>
      (await _db.metaDao.get(_kReminders)) == '1';

  Future<void> setRemindersEnabled(bool value) =>
      _db.metaDao.set(_kReminders, value ? '1' : '0');

  /// "New chapter ready" morning nudge. Default ON.
  Future<bool> chapterNotifEnabled() async =>
      (await _db.metaDao.get(_kNotifChapter)) != '0';

  Future<void> setChapterNotifEnabled(bool value) =>
      _db.metaDao.set(_kNotifChapter, value ? '1' : '0');

  /// "What Washington did" master switch. Default ON; turning this off
  /// silences all three sub-categories regardless of their own value.
  Future<bool> washingtonNotifEnabled() async =>
      (await _db.metaDao.get(_kNotifWashington)) != '0';

  Future<void> setWashingtonNotifEnabled(bool value) =>
      _db.metaDao.set(_kNotifWashington, value ? '1' : '0');

  /// Sub-category: new laws. Default ON.
  Future<bool> washLawsEnabled() async =>
      (await _db.metaDao.get(_kNotifWashLaws)) != '0';

  Future<void> setWashLawsEnabled(bool value) =>
      _db.metaDao.set(_kNotifWashLaws, value ? '1' : '0');

  /// Sub-category: bills advancing. Default ON.
  Future<bool> washBillsEnabled() async =>
      (await _db.metaDao.get(_kNotifWashBills)) != '0';

  Future<void> setWashBillsEnabled(bool value) =>
      _db.metaDao.set(_kNotifWashBills, value ? '1' : '0');

  /// Sub-category: executive orders. Default ON.
  Future<bool> washEosEnabled() async =>
      (await _db.metaDao.get(_kNotifWashEos)) != '0';

  Future<void> setWashEosEnabled(bool value) =>
      _db.metaDao.set(_kNotifWashEos, value ? '1' : '0');

  /// Opt-in crash reporting (Sentry). Off by default — the toggle is the
  /// only thing that enables the app's only telemetry. Takes effect on the
  /// next launch because Sentry must wrap the app from startup.
  /// Default ON: anonymous crash diagnostics are collected unless the
  /// user explicitly turns them off ('0'). Reports carry no personal
  /// information (sendDefaultPii is false and no user ids are attached).
  Future<bool> crashReportsEnabled() async =>
      (await _db.metaDao.get(kCrashReports)) != '0';

  Future<void> setCrashReportsEnabled(bool value) =>
      _db.metaDao.set(kCrashReports, value ? '1' : '0');

  /// Default ON: any value other than the explicit '0' means enabled.
  Future<bool> soundEffectsEnabled() async =>
      (await _db.metaDao.get(_kSoundEffects)) != '0';

  Future<void> setSoundEffectsEnabled(bool value) =>
      _db.metaDao.set(_kSoundEffects, value ? '1' : '0');

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

  Future<void> setThemeMode(ThemeMode mode) =>
      _db.metaDao.set(_kThemeMode, _wireName(mode));

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
      await _db.delete(_db.fcleAnswers).go();
      await _db.delete(_db.completedRuns).go();
      await _db.delete(_db.chapterProgress).go();
      await _db.delete(_db.dailyRounds).go();
      await _db.delete(_db.outboxEvents).go();
      // Clear gamification + seed flags so seeds re-run + onboarding shows again.
      await _db.delete(_db.appMeta).go();
    });
  }
}
