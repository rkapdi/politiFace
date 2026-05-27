import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../daily_challenge/data/daily_challenge_service.dart';
import '../../profile/data/profile_service.dart';
import '../../session/application/session_controller.dart';

/// Editorial daily-challenge card. Replaces the gold gradient with a flat
/// surface, hairline rule, section label, big display-serif headline, and
/// a stamped-seal action button. Played state shows the emoji grid as the
/// hero with copy/share underneath.
class DailyChallengeCard extends ConsumerWidget {
  const DailyChallengeCard({
    super.key,
    required this.challenge,
    required this.profile,
  });

  final DailyChallenge challenge;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (challenge.isPlayed) {
      return _Played(challenge: challenge, profile: profile);
    }
    return _Unplayed(challenge: challenge);
  }
}

// ─── Unplayed: the action ───────────────────────────────────────────────────

class _Unplayed extends ConsumerWidget {
  const _Unplayed({required this.challenge});
  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = challenge.cardIds.length;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top strip — ochre marks the day's ritual section.
          Container(height: 4, color: EditorialPalette.ochre),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(date: challenge.date),
                const SizedBox(height: 10),
                // Big number — "5" massive, "CARDS" set in mono caps
                // beside it on the baseline.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 0.9,
                        fontSize: 88,
                        letterSpacing: -3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        count == 1 ? 'CARD' : 'CARDS',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 2.0,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '≈ 60 SECONDS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(activeSessionDeckIdProvider.notifier)
                          .state = null;
                      ref
                          .read(activeDailyChallengeDateProvider.notifier)
                          .state = challenge.date;
                      ref.invalidate(sessionControllerProvider);
                      context.go('/session');
                    },
                    child: const Text('PLAY'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Played: the result ────────────────────────────────────────────────────

class _Played extends StatelessWidget {
  const _Played({required this.challenge, required this.profile});
  final DailyChallenge challenge;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grades = challenge.grades ?? const <int>[];
    final correct = grades.where((g) => g >= 1).length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: EditorialPalette.civicGreen),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  date: challenge.date,
                  rightLabel: 'COMPLETED',
                  rightColor: EditorialPalette.civicGreen,
                ),
                const SizedBox(height: 18),
                // Emoji grid — hero.
                Center(
                  child: Text(
                    grades.map(_emojiForGrade).join(' '),
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.4,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Big score, display serif.
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$correct',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontSize: 56,
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                      Text(
                        ' / ${grades.length}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CORRECT',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile.streakDays > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '🔥 ${profile.streakDays} day${profile.streakDays == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(
                            text: _buildShareText(challenge, profile),
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('COPY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Share.share(_buildShareText(challenge, profile));
                        },
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('SHARE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _untilTomorrowString().toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header shared by both states ──────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.date,
    this.rightLabel,
    this.rightColor,
  });

  final String date;
  final String? rightLabel;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          "TODAY'S CHALLENGE",
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 4,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          _formatDate(date).toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (rightLabel != null)
          Text(
            rightLabel!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: rightColor ?? theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _formatDate(String yyyymmdd) {
  final parts = yyyymmdd.split('-');
  if (parts.length != 3) return yyyymmdd;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final monthIdx = int.tryParse(parts[1]);
  if (monthIdx == null || monthIdx < 1 || monthIdx > 12) return yyyymmdd;
  final day = int.tryParse(parts[2]) ?? 0;
  return '${months[monthIdx - 1]} $day';
}

String _emojiForGrade(int g) {
  switch (g) {
    case 0:
      return '🟥';
    case 1:
      return '🟧';
    case 2:
      return '🟩';
    case 3:
      return '🟦';
    default:
      return '⬛';
  }
}

String _buildShareText(DailyChallenge c, UserProfile p) {
  final grades = c.grades ?? const <int>[];
  final correct = grades.where((g) => g >= 1).length;
  final grid = grades.map(_emojiForGrade).join(' ');
  final lines = <String>[
    'Politiface Daily — ${_formatDate(c.date)}',
    grid,
    '$correct/${grades.length} correct'
        '${p.streakDays > 0 ? "  ·  🔥 ${p.streakDays} day${p.streakDays == 1 ? "" : "s"}" : ""}',
  ];
  return lines.join('\n');
}

String _untilTomorrowString() {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final diff = tomorrow.difference(now);
  final h = diff.inHours;
  final m = (diff.inMinutes % 60);
  if (h > 0) return 'Next challenge in ${h}h ${m}m';
  return 'Next challenge in ${m}m';
}
