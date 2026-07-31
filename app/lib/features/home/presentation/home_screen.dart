// lib/features/home/presentation/home_screen.dart
//
// Home v2 (Readiness Engine, Move 2 + Move 9, Signal Brutalism skin).
// The screen answers one question: "will I pass, and what should I do
// about it right now?" Composition, top to bottom:
//   masthead (brand + streak chip + avatar)
//   readiness hero (powerline stage + projected range + domain bars)
//   THE one button (ladder-picked; the screen's single yellow action)
//   class block (cohort members only; solo users see nothing here)
//   "More ways to play" verb row (Study / Drill / Play / Pulse)
//   the season spine (the long-arc narrative, below the fold)
// The old five equal tiles and the "Almost There" rail are retired: the
// ladder answers "what next" alone (defect DEF-07).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../fcle/domain/fcle_question.dart';
import '../../leaderboard/application/leaderboard_providers.dart';
import '../../profile/data/profile_service.dart';
import '../../shared/widgets/neo/neo_kit.dart';
import '../application/home_providers.dart';
import 'guided_tour.dart';
import 'season_spine.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile =
        ref.watch(profileProvider).valueOrNull ?? UserProfile.empty;

    // First-visit tour, plus the Settings "show me around" replay. The
    // request flag is CHECKED post-frame rather than listened to:
    // navigating to /settings unmounts Home (top-level route), so a
    // change listener would never see the flag flip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (ref.read(tourRequestProvider)) {
        ref.read(tourRequestProvider.notifier).state = false;
        GuidedTour.start(context, ref);
      } else {
        GuidedTour.maybeShow(context, ref);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'POLITIFACE',
          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2),
        ),
        actions: [
          _StreakChip(days: profile.streakDays),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Settings and account',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: GuidedTour.readinessKey,
                child: const ReadinessHero(),
              ),
              const SizedBox(height: 18),
              KeyedSubtree(
                key: GuidedTour.buttonKey,
                child: const _TheOneButton(),
              ),
              const SizedBox(height: 18),
              const _ClassBlock(),
              KeyedSubtree(
                key: GuidedTour.verbsKey,
                child: const _MoreWaysRow(),
              ),
              const SizedBox(height: 26),
              const _SectionDivider(label: 'THE SEASON'),
              const SizedBox(height: 12),
              const SeasonSpine(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: neoLineDim(context), width: 2),
      ),
      child: Row(
        children: [
          Text('\u{1F525}', style: theme.textTheme.labelMedium),
          const SizedBox(width: 5),
          Text(
            '$days',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.brandOchreText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The readiness hero: stage powerline, projected range, domain bars.
/// Before enough signal exists it becomes an honest invitation instead of
/// a fake number.
class ReadinessHero extends ConsumerWidget {
  const ReadinessHero({super.key});

  static ReadinessStage stageFor(ReadinessSummary s) {
    if (s.low >= 58) return ReadinessStage.lockedIn;
    if (s.low >= 48) return ReadinessStage.ready;
    if (s.high >= 48) return ReadinessStage.onTrack;
    return ReadinessStage.notYet;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(readinessSummaryProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neoCardBg(context),
        border: Border.all(color: neoLine(context), width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('YOUR READINESS', style: theme.textTheme.labelSmall),
              Text('PASS LINE 48', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (summary == null) ...[
            Text(
              'No signal yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Answer a few exam questions and this becomes your '
              'projected score. The Drill tab is the fastest way in.',
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            PowerlineBar(
              active: stageFor(summary),
              trailing: Text(
                'OF 80',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${summary.low}–${summary.high}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text('projected of 80', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            _DomainBars(perDomain: summary.perDomain),
          ],
        ],
      ),
    );
  }
}

class _DomainBars extends StatelessWidget {
  const _DomainBars({required this.perDomain});

  final Map<FcleDomain, double?> perDomain;

  static const _shortLabels = {
    FcleDomain.americanDemocracy: 'DEMOCRACY',
    FcleDomain.usConstitution: 'CONSTITUTION',
    FcleDomain.foundingDocuments: 'FOUNDING DOCS',
    FcleDomain.landmarkImpact: 'LANDMARK CASES',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final d in FcleDomain.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    _shortLabels[d] ?? d.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? EditorialPalette.inkInverted
                          : const Color(0xFFF0F0EB),
                      border: Border.all(color: neoLineDim(context)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (perDomain[d] ?? 0).clamp(0.0, 1.0),
                      child: ColoredBox(
                        // Below par reads not-yet orange, at pace reads
                        // neutral: colour marks the problem, not the
                        // wallpaper.
                        color: (perDomain[d] ?? 0) < 0.6
                            ? theme.colorScheme.notyetState
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    perDomain[d] == null
                        ? '–'
                        : '${(perDomain[d]! * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The screen's ONE yellow action, picked by the approved priority
/// ladder. Everything else on Home is quiet.
class _TheOneButton extends ConsumerWidget {
  const _TheOneButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = ref.watch(ladderPickProvider).valueOrNull;
    final played = ref.watch(homeRoundPlayedProvider).valueOrNull ?? false;

    final (label, subtitle, route) = switch (pick?.rung) {
      LadderRung.review => (
          "▶ Today's review",
          '${pick!.dueCount} cards · about '
              '${(pick.dueCount / 5).ceil()} min',
          '/session',
        ),
      LadderRung.drill => (
          '▶ Drill your weakest domain',
          '${pick!.weakest?.label ?? ''} · 10 questions',
          '/fcle/practice?domain=${pick.weakest?.code ?? ''}',
        ),
      LadderRung.round || null => played
          ? ("▶ Today's round", 'Played · replay or review', '/round')
          : ("▶ Play today's round", 'The daily ritual', '/round'),
    };

    return BrutalButton(
      label: label,
      subtitle: subtitle,
      onPressed: () => context.go(route),
    );
  }
}

/// The classroom, ambient on Home for cohort members only (Move 9).
/// Solo students never see class scaffolding (persona P2's
/// anti-requirement).
class _ClassBlock extends ConsumerWidget {
  const _ClassBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cohorts = ref.watch(myCohortsProvider).valueOrNull ?? const [];
    if (cohorts.isEmpty) return const SizedBox.shrink();
    final cohort = cohorts.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(
          color: neoCardBg(context),
          border: Border.all(color: neoLine(context), width: 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MY CLASS · ${cohort.name.toUpperCase()}',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            _ClassRow(
              label: 'Class messages',
              onTap: () => context.push('/class'),
            ),
            _ClassRow(
              label: 'Leaderboard and live games',
              onTap: () => context.push('/leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: neoLineDim(context)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '→',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three verbs plus the reference feed (approved D1). Quiet tiles:
/// hollow, mono, no colour; the ladder button above them is the loud one.
class _MoreWaysRow extends StatelessWidget {
  const _MoreWaysRow();

  @override
  Widget build(BuildContext context) => Row(
      children: [
        for (final (label, sub, glyph, route, push) in const [
          // Icons chosen to say the job: flashcards, a target, a game
          // controller. Pulse owns a bottom tab now.
          ('STUDY', 'keep it fresh', Icons.style_outlined, '/session', false),
          ('DRILL', 'move your score', Icons.track_changes, '/fcle', true),
          (
            'PLAY',
            'just for fun',
            Icons.sports_esports_outlined,
            '/trivia',
            false
          ),
        ]) ...[
          if (label != 'STUDY') const SizedBox(width: 8),
          Expanded(
            child: _VerbTile(
              label: label,
              sublabel: sub,
              glyph: glyph,
              onTap: () {
                HapticFeedback.lightImpact();
                push ? context.push(route) : context.go(route);
              },
            ),
          ),
        ],
      ],
    );
}

class _VerbTile extends StatelessWidget {
  const _VerbTile({
    required this.label,
    required this.sublabel,
    required this.glyph,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: neoLineDim(context), width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              glyph,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 8.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: neoLineDim(context))),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: neoLineDim(context))),
      ],
    );
  }
}
