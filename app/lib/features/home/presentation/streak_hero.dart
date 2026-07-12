import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';
import '../../profile/data/profile_service.dart';

/// Masthead-style streak banner. Big display-serif day count, hairline
/// rules separating XP / Level columns. Reads like a newspaper top-of-page
/// nameplate rather than a gradient marketing card.
class StreakHero extends StatelessWidget {
  const StreakHero({required this.profile, super.key});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = profile.streakDays > 0;
    final dayCount = profile.streakDays;
    final dayLabel = dayCount == 1 ? 'DAY' : 'DAYS';
    final streakColor =
        active ? EditorialPalette.actionRed : theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Masthead label.
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                color: streakColor,
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'POLITIFACE · ACTIVE STREAK' : 'POLITIFACE · STREAK',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Big day count — display serif, color shifts to actionRed when active.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$dayCount',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: streakColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 80,
                  height: 0.9,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  dayLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _subtitleFor(profile.streakDays),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: theme.colorScheme.outline, thickness: 1.5, height: 1),
          const SizedBox(height: 14),
          // Two-column metric strip — tabular mono numbers.
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'XP',
                    value: profile.xpTotal,
                    progress: profile.xpForNextLevel == 0
                        ? null
                        : profile.xpInLevel / profile.xpForNextLevel,
                    accent: theme.colorScheme.brandNavy,
                  ),
                ),
                VerticalDivider(
                  color: theme.colorScheme.outline,
                  thickness: 1.5,
                  width: 32,
                ),
                Expanded(
                  child: _Metric(
                    label: 'LEVEL',
                    value: profile.level,
                    progress: null,
                    accent: theme.colorScheme.brandOchre,
                  ),
                ),
              ],
            ),
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
  });
  final String label;
  final int value;
  final double? progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween:
              Tween<double>(begin: value.toDouble(), end: value.toDouble()),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            v.round().toString(),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 34,
              height: 1,
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          // Hard-edge progress bar — no rounded corners.
          SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: theme.colorScheme.outline),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress!.clamp(0.0, 1.0),
                  child: Container(color: accent),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
