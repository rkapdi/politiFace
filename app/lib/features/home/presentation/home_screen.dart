import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../daily_challenge/data/daily_challenge_service.dart';
import '../../profile/data/profile_service.dart';
import '../../session/application/session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        label: 'Streak',
                        value: profile.streakDays,
                        showFlame: true,
                      ),
                      _Stat(label: 'XP', value: profile.xpTotal),
                      _Stat(label: 'Level', value: profile.level),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              challengeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (challenge) => challenge == null
                    ? const SizedBox.shrink()
                    : _DailyChallengeCard(challenge: challenge),
              ),
              const SizedBox(height: 24),
              Text(
                'Learn US government',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Face-name-role memorization with spaced repetition.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ref.read(activeSessionDeckIdProvider.notifier).state = null;
                  ref.read(activeDailyChallengeDateProvider.notifier).state =
                      null;
                  ref.invalidate(sessionControllerProvider);
                  context.go('/session');
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start daily session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard({required this.challenge});
  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text("Today's Challenge", style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge.isPlayed
                  ? 'Done — share your result.'
                  : '${challenge.cardIds.length} cards. One per day.',
              style: theme.textTheme.bodyMedium,
            ),
            if (challenge.isPlayed) ...[
              const SizedBox(height: 12),
              Text(
                challenge.shareText ?? '',
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  Share.share(challenge.shareText ?? '');
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref.read(activeSessionDeckIdProvider.notifier).state = null;
                  ref.read(activeDailyChallengeDateProvider.notifier).state =
                      challenge.date;
                  ref.invalidate(sessionControllerProvider);
                  context.go('/session');
                },
                child: const Text('Play'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.showFlame = false,
  });
  final String label;
  final int value;
  final bool showFlame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFlame && value > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '🔥',
                  style: TextStyle(fontSize: theme.textTheme.headlineMedium?.fontSize),
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                v.round().toString(),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
