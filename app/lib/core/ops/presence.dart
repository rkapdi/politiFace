// Presence (admin console): tells the founders' console this person has
// the app open. Beats once when the app comes to the foreground, then every
// 60 seconds while it stays there; stops when the app is backgrounded.
// Fire-and-forget: a failed beat is swallowed and never touches the UI.

import 'dart:async';

import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService({
    required Future<void> Function() beat,
    this.interval = const Duration(seconds: 60),
  }) : _beat = beat;

  final Future<void> Function() _beat;
  final Duration interval;
  Timer? _timer;

  /// Starts beating now (the app is in the foreground at launch) and
  /// follows the app lifecycle from here on.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  /// An extra beat outside the schedule, e.g. right after sign-in.
  void beatNow() {
    unawaited(_beat().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        // Brief interruptions (Control Center, an incoming call banner)
        // keep the schedule running.
        break;
    }
  }

  void _resume() {
    beatNow();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => beatNow());
  }
}
