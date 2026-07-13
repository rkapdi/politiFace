import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/audio/sound_service.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService', () {
    test('play before init is a silent no-op and never throws', () {
      final service = SoundService();
      for (final effect in SoundEffect.values) {
        expect(() => service.play(effect), returnsNormally);
      }
    });

    test('init degrades to a no-op when the audio plugin is unavailable',
        () async {
      // In the test environment there is no platform audio plugin, so init
      // must swallow the failure and leave play as a silent no-op. This is
      // the same path widget tests of the touched screens rely on.
      final service = SoundService();
      await expectLater(service.init(), completes);
      expect(() => service.play(SoundEffect.correct), returnsNormally);
    });

    test('play respects the cached enabled flag', () {
      final service = SoundService()..enabled = false;
      expect(() => service.play(SoundEffect.flip), returnsNormally);
    });

    test('every effect maps to a bundled wav under assets/audio/', () {
      expect(SoundEffect.flip.assetPath, 'audio/flip.wav');
      expect(SoundEffect.correct.assetPath, 'audio/correct.wav');
      expect(SoundEffect.incorrect.assetPath, 'audio/incorrect.wav');
      expect(SoundEffect.complete.assetPath, 'audio/complete.wav');
      expect(SoundEffect.milestone.assetPath, 'audio/milestone.wav');
    });
  });

  group('SoundEnabledNotifier', () {
    late AppDatabase db;
    late SettingsService settings;
    late SoundService sound;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsService(db);
      sound = SoundService();
    });

    tearDown(() => db.close());

    test('defaults to ON and pushes the flag into the service', () async {
      final notifier = SoundEnabledNotifier(settings, sound);
      await Future<void>.delayed(Duration.zero); // let _load complete
      expect(notifier.state, true);
      expect(sound.enabled, true);
    });

    test('set(false) persists, updates state, and gates the service', () async {
      final notifier = SoundEnabledNotifier(settings, sound);
      await notifier.set(false);
      expect(notifier.state, false);
      expect(sound.enabled, false);
      expect(await settings.soundEffectsEnabled(), false);

      // A fresh notifier loads the persisted OFF state.
      final reloaded = SoundEnabledNotifier(settings, SoundService());
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state, false);
    });
  });
}
