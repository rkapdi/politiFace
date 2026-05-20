import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../daily_challenge/data/daily_challenge_service.dart';
import '../../profile/data/profile_service.dart';
import '../../session/application/session_controller.dart';

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

  static const _bg1 = Color(0xFFB18820); // gold
  static const _bg2 = Color(0xFFE2A23A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_bg1, _bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _bg2.withOpacity(0.35),
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
              _Label('TODAY\'S CHALLENGE'),
              const Spacer(),
              Text(
                _formatDate(challenge.date),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.06, 1.06),
                    duration: 1400.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${challenge.cardIds.length} cards',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '~60 seconds',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(activeSessionDeckIdProvider.notifier).state = null;
                ref.read(activeDailyChallengeDateProvider.notifier).state =
                    challenge.date;
                ref.invalidate(sessionControllerProvider);
                context.go('/session');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _bg1,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Play',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Played: the trophy ─────────────────────────────────────────────────────

class _Played extends StatelessWidget {
  const _Played({required this.challenge, required this.profile});
  final DailyChallenge challenge;
  final UserProfile profile;

  static const _bg1 = Color(0xFF1E5A4A);
  static const _bg2 = Color(0xFF2E8B6F);

  @override
  Widget build(BuildContext context) {
    final grades = challenge.grades ?? const <int>[];
    final correct = grades.where((g) => g >= 1).length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_bg1, _bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _bg2.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              _Label('TODAY\'S CHALLENGE'),
              const Spacer(),
              Text(
                _formatDate(challenge.date),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Big emoji grid centered.
          Center(
            child: Text(
              grades.map(_emojiForGrade).join(' '),
              style: const TextStyle(
                fontSize: 36,
                height: 1.4,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Chip(text: '$correct / ${grades.length} correct'),
              if (profile.streakDays > 0) ...[
                const SizedBox(width: 8),
                _Chip(text: '🔥 ${profile.streakDays}'),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Share.share(_buildShareText(challenge, profile));
                  },
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _bg1,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _untilTomorrowString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

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
