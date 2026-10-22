// Plays the streak sound the first time Home shows a day-streak milestone
// (3, 7, 14, 30, ... days). Once per milestone value, remembered in
// AppMeta, so revisiting Home that day stays quiet. Renders nothing.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/audio/streak_sounds.dart';

class StreakMilestoneChime extends ConsumerStatefulWidget {
  const StreakMilestoneChime({super.key});

  @override
  ConsumerState<StreakMilestoneChime> createState() =>
      _StreakMilestoneChimeState();
}

class _StreakMilestoneChimeState extends ConsumerState<StreakMilestoneChime> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      profileProvider,
      (_, next) {
        final days = next.valueOrNull?.streakDays;
        if (days != null) unawaited(_maybeCelebrate(days));
      },
      fireImmediately: true,
    );
  }

  Future<void> _maybeCelebrate(int days) async {
    final meta = ref.read(databaseProvider).metaDao;
    final claimed = await claimStreakMilestone(meta, days);
    if (!claimed || !mounted) return;
    // Screen-level chime: skipped under VoiceOver, like the summary chime.
    final a11y = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (!a11y) ref.read(soundServiceProvider).play(SoundEffect.streak);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
