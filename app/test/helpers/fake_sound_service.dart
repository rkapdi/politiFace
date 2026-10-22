import 'package:politiface/core/audio/sound_service.dart';

/// Records every [play] call instead of touching the (absent, in tests)
/// audio plugin. Override [soundServiceProvider] with an instance of this
/// to assert which sound effects a screen fired, and in what order.
class FakeSoundService extends SoundService {
  final List<SoundEffect> played = [];

  @override
  void play(SoundEffect effect) => played.add(effect);
}
