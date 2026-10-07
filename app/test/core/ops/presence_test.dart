import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/ops/presence.dart';

void main() {
  testWidgets('beats on start, every interval, and stops in the background',
      (tester) async {
    var beats = 0;
    final presence = PresenceService(
      beat: () async => beats++,
    )..start();

    expect(beats, 1);
    await tester.pump(const Duration(seconds: 61));
    expect(beats, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 180));
    expect(beats, 2, reason: 'no beats while backgrounded');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(beats, 3, reason: 'beats right away on return');
    await tester.pump(const Duration(seconds: 61));
    expect(beats, 4);
    presence.stop();
  });

  testWidgets('a failing beat never throws', (tester) async {
    final presence = PresenceService(beat: () async => throw Exception('x'))
      ..start();
    await tester.pump();
    presence.stop();
  });
}
