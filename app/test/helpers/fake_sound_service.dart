import 'package:politiface/core/audio/sound_service.dart';

/// Records every [play] call instead of touching the (absent, in tests)
/// audio plugin. Override [soundServiceProvider] with an instance of this
/// to assert which sound effects a screen fired, and in what order.
class FakeSoundService extends SoundService {
  final List<SoundEffect> played = [];

  /// The real init subscribes to the plugin's global event channel, which
  /// has no implementation under flutter test.
  @override
  Future<void> init() async {}

  @override
  void play(SoundEffect effect) => played.add(effect);
}
