import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

void main() {
  late AppDatabase db;
  late SettingsService settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
  });

  tearDown(() => db.close());

  test('crash reporting defaults to OFF — the opt-in privacy posture',
      () async {
    expect(await settings.crashReportsEnabled(), false);
  });

  test('crash reporting opt-in round-trips and can be revoked', () async {
    await settings.setCrashReportsEnabled(true);
    expect(await settings.crashReportsEnabled(), true);
    // The same key main.dart reads before deciding to init Sentry.
    expect(await db.metaDao.get(SettingsService.kCrashReports), '1');

    await settings.setCrashReportsEnabled(false);
    expect(await settings.crashReportsEnabled(), false);
  });

  test('resetProgress clears the crash-reporting opt-in too', () async {
    await settings.setCrashReportsEnabled(true);
    await settings.resetProgress();
    expect(await settings.crashReportsEnabled(), false);
  });

  test('sound effects default to ON when the preference is unset', () async {
    expect(await settings.soundEffectsEnabled(), true);
  });

  test('sound effects toggle round-trips', () async {
    await settings.setSoundEffectsEnabled(false);
    expect(await settings.soundEffectsEnabled(), false);

    await settings.setSoundEffectsEnabled(true);
    expect(await settings.soundEffectsEnabled(), true);
  });

  test('resetProgress reverts sound effects to the default ON', () async {
    await settings.setSoundEffectsEnabled(false);
    await settings.resetProgress();
    expect(await settings.soundEffectsEnabled(), true);
  });
}
