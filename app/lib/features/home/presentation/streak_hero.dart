import 'package:flutter/material.dart';

import '../../profile/data/profile_service.dart';

/// Full-width hero banner that frames the streak as the user's primary
/// motivation. XP and level become small footer pills so they're still
/// visible but don't compete for attention.
class StreakHero extends StatelessWidget {
  const StreakHero({super.key, required this.profile});
  final UserProfile profile;

  static const _hot = Color(0xFFE74C3C);   // red
  static const _warm = Color(0xFFE67E22);  // orange
  static const _cool = Color(0xFF34495E);  // slate (when streak is 0)
  static const _cool2 = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = profile.streakDays > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active ? const [_hot, _warm] : const [_cool, _cool2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (active ? _hot : _cool).withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Flame(active: active),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      // begin = end so re-mounting the home screen (e.g. after
                      // navigating to /session and back) doesn't replay the
                      // 0 → N count-up — that read as "I just earned XP".
                      // Genuine value changes still animate because
                      // TweenAnimationBuilder tweens from current → new end.
                      tween: Tween<double>(
                          begin: profile.streakDays.toDouble(),
                          end: profile.streakDays.toDouble()),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) {
                        final n = v.round();
                        return Text(
                          '$n day${n == 1 ? '' : 's'}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleFor(profile.streakDays),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Pill(
                label: 'XP',
                value: profile.xpTotal,
                progress: profile.xpForNextLevel == 0
                    ? 0
                    : profile.xpInLevel / profile.xpForNextLevel,
              ),
              const SizedBox(width: 10),
              _Pill(label: 'Level', value: profile.level),
            ],
          ),
        ],
      ),
    );
  }

  static String _subtitleFor(int streak) {
    if (streak == 0) return 'Start your streak today.';
    if (streak == 1) return "Don't break the chain.";
    if (streak < 7) return 'Going strong — keep showing up.';
    if (streak < 30) return 'On fire.';
    return 'Legend.';
  }
}

class _Flame extends StatelessWidget {
  const _Flame({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
      ),
      child: Text(
        active ? '🔥' : '🕯️',
        style: const TextStyle(fontSize: 34),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    this.progress,
  });
  final String label;
  final int value;
  final double? progress; // 0..1, optional progress bar fill

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  // See StreakHero — begin = end avoids replaying the 0 → N
                  // count-up on every home re-mount, which read as XP gained.
                  tween: Tween<double>(
                      begin: value.toDouble(), end: value.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    v.round().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.20),
                  valueColor:
                      const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
