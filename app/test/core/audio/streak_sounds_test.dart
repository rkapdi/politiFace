import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/audio/sound_service.dart';
import 'package:politiface/core/audio/streak_sounds.dart';

void main() {
  test('in-a-row milestones: 5, 10, 20, then every 10th', () {
    final hits = [
      for (var n = 1; n <= 50; n++)
        if (isInARowMilestone(n)) n,
    ];
    expect(hits, [5, 10, 20, 30, 40, 50]);
  });

  test('answer sound: wrong, plain right, or the streak', () {
    expect(answerSound(correct: false, inARowAfter: 0), SoundEffect.incorrect);
    expect(answerSound(correct: true, inARowAfter: 4), SoundEffect.correct);
    expect(answerSound(correct: true, inARowAfter: 5), SoundEffect.streak);
    expect(answerSound(correct: true, inARowAfter: 11), SoundEffect.correct);
  });

  test('day milestones', () {
    expect(streakDayMilestones, containsAll([3, 7, 14, 30, 50, 100, 365]));
    expect(streakDayMilestones.contains(8), isFalse);
  });
}
