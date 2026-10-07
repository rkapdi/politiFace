// Mock FCLE results: a pass gets the big celebration burst, a fail stays
// quiet but still plays a neutral "complete" chime (never the milestone
// chime, which is reserved for a pass).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/audio/sound_service.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/mock_engine.dart';
import 'package:politiface/features/fcle/presentation/mock_result_screen.dart';
import 'package:politiface/features/shared/widgets/feedback_motion.dart';

import '../../../helpers/fake_sound_service.dart';

MockResult _result({required bool passed}) => MockResult(
      score: passed ? 60 : 30,
      total: 80,
      passed: passed,
      perDomain: {
        for (final d in FcleDomain.values)
          d: DomainScore(correct: passed ? 16 : 6, total: 20),
      },
    );

Widget _host(MockResult result, FakeSoundService sound) => ProviderScope(
      overrides: [soundServiceProvider.overrideWithValue(sound)],
      child: MaterialApp(home: MockResultScreen(result: result)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a pass shows the big celebration burst and the milestone '
      'chime', (tester) async {
    final sound = FakeSoundService();
    await tester.pumpWidget(_host(_result(passed: true), sound));
    // Past the burst's 250ms post-frame delay and its confetti duration,
    // so no timer is left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));

    final burst = tester.widget<CelebrationBurst>(
      find.byType(CelebrationBurst),
    );
    expect(burst.fire, true);
    expect(burst.big, true);
    expect(sound.played, [SoundEffect.milestone]);
  });

  testWidgets('a fail stays silent on confetti but plays the neutral '
      'complete chime', (tester) async {
    final sound = FakeSoundService();
    await tester.pumpWidget(_host(_result(passed: false), sound));
    for (var f = 0; f < 3; f++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final burst = tester.widget<CelebrationBurst>(
      find.byType(CelebrationBurst),
    );
    expect(burst.fire, false);
    expect(sound.played, [SoundEffect.complete]);
  });
}
