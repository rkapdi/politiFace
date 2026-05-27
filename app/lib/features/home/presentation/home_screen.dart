import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../profile/data/profile_service.dart';
import 'daily_challenge_card.dart';
import 'next_up_section.dart';
import 'streak_hero.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull ?? UserProfile.empty;
    final challengeAsync = ref.watch(dailyChallengeTodayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politiface'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreakHero(profile: profile),
              const SizedBox(height: 24),
              challengeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (challenge) => challenge == null
                    ? const SizedBox.shrink()
                    : DailyChallengeCard(
                        challenge: challenge,
                        profile: profile,
                      ),
              ),
              const SizedBox(height: 24),
              _TriviaTile(),
              const SizedBox(height: 12),
              _EndlessTile(),
              const SizedBox(height: 24),
              const NextUpSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editorial-style action tile. Section label, display-serif headline,
/// mono body, sharp corners, optional colored top strip like a magazine
/// section header.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.section,
    required this.headline,
    required this.body,
    required this.accent,
    required this.onTap,
    this.mark,
  });
  final String section;
  final String headline;
  final String body;
  final Color accent;
  final VoidCallback onTap;

  /// Optional marker glyph rendered as a typographic dingbat (small,
  /// inline, NOT a hero emoji). Pass null to omit.
  final String? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: theme.colorScheme.outline, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored top strip — a hairline of identity, magazine-style.
              Container(height: 4, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          section,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mark != null) ...[
                          Text(
                            mark!,
                            style: TextStyle(
                              fontSize: 28,
                              color: accent,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            headline,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriviaTile extends StatelessWidget {
  const _TriviaTile();

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      section: 'TRIVIA · DAILY',
      headline: 'Are you a Civic Bullshitter?',
      body: '10 questions. Bet your confidence. Get an archetype.',
      accent: EditorialPalette.actionRed,
      mark: '✦',
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/trivia');
      },
    );
  }
}

class _EndlessTile extends StatelessWidget {
  const _EndlessTile();

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      section: 'ENDLESS',
      headline: 'Play forever.',
      body: 'Quick MCQ. No streak burn. Beat your best run.',
      accent: EditorialPalette.civicNavy,
      mark: '∞',
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/endless');
      },
    );
  }
}
