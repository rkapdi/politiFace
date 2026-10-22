// lib/core/audio/streak_sounds.dart
//
// When the streak sound plays instead of the usual one:
//   - right answers in a row: the 5th, 10th, 20th, then every 10th;
//   - day streaks: the first time Home shows a milestone day count.

import '../database/daos/meta_dao.dart';
import 'sound_service.dart';

/// Day-streak milestones that earn the streak sound.
const streakDayMilestones = {3, 7, 14, 30, 50, 100, 365};

/// AppMeta key holding the last day-streak value already celebrated, so a
/// milestone plays once, not on every visit to Home that day.
const streakCelebratedKey = 'sound.streak_celebrated';

bool isInARowMilestone(int inARow) =>
    inARow == 5 || inARow == 10 || (inARow >= 20 && inARow % 10 == 0);

/// The sound for an answer, given the in-a-row count after it.
SoundEffect answerSound({required bool correct, required int inARowAfter}) {
  if (!correct) return SoundEffect.incorrect;
  return isInARowMilestone(inARowAfter)
      ? SoundEffect.streak
      : SoundEffect.correct;
}

/// True the first time a milestone [days] value is seen; records it so the
/// same milestone never plays twice.
Future<bool> claimStreakMilestone(MetaDao meta, int days) async {
  if (!streakDayMilestones.contains(days)) return false;
  if (await meta.get(streakCelebratedKey) == '$days') return false;
  await meta.set(streakCelebratedKey, '$days');
  return true;
}
