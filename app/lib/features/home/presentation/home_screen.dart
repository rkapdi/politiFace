import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../profile/data/profile_service.dart';
import 'chapter_round_card.dart';
import 'first_run_tour.dart';
import 'next_up_section.dart';
import 'season_spine.dart';
import 'streak_hero.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull ?? UserProfile.empty;

    // First-run orientation — one-time, checked once per launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) FirstRunTour.maybeShow(context, ref);
    });

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
              // Primary CTA — chapter-aware daily round. Replaces the old
              // Daily Challenge + Trivia tiles as the single ritual.
              const ChapterRoundCard(),
              const SizedBox(height: 24),
              const _SectionDivider(label: 'SECONDARY'),
              const SizedBox(height: 12),
              const _TriviaTile(),
              const SizedBox(height: 12),
              const _EndlessTile(),
              const SizedBox(height: 12),
              const _FcleTile(),
              const SizedBox(height: 24),
              const _SectionDivider(label: 'THE SEASON'),
              const SizedBox(height: 12),
              const SeasonSpine(),
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

/// Magazine-style section divider — hairline with a centered label chip.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: theme.colorScheme.outlineVariant),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: theme.colorScheme.outlineVariant),
        ),
      ],
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
                              height: 1,
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
  Widget build(BuildContext context) => _ActionTile(
      section: 'TRIVIA · DAILY',
      headline: 'Are you a Civic Bluffer?',
      body: '10 questions. Bet your confidence. Get an archetype.',
      accent: EditorialPalette.actionRed,
      mark: '✦',
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/trivia');
      },
    );
}

class _FcleTile extends StatelessWidget {
  const _FcleTile();

  @override
  Widget build(BuildContext context) => _ActionTile(
      section: 'FCLE PREP',
      headline: 'Could you pass?',
      body: 'Practice for the Florida Civic Literacy Exam. '
          'Four domains, mock exams, readiness tracking.',
      accent: Theme.of(context).colorScheme.brandGreen,
      mark: '§',
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/fcle');
      },
    );
}

class _EndlessTile extends StatelessWidget {
  const _EndlessTile();

  @override
  Widget build(BuildContext context) => _ActionTile(
      section: 'ENDLESS',
      headline: 'Play forever.',
      body: 'Quick MCQ. No streak burn. Beat your best run.',
      accent: Theme.of(context).colorScheme.brandNavy,
      mark: '∞',
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/endless');
      },
    );
}
