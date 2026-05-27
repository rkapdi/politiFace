import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../shared/widgets/state_views.dart';
import '../application/daily_round_controller.dart';
import '../domain/round_state.dart';
import 'round_cards_phase.dart';
import 'round_reveal_phase.dart';
import 'round_trivia_phase.dart';

/// Top-level screen for the chapter-aware daily round. Switches between
/// phase widgets based on [DailyRoundState.phase].
///
/// Phase 3 scope: wired but home doesn't drive it yet. Route is `/round`;
/// reachable via the temporary home tile added in this phase + via the
/// final Phase 4 home redesign that replaces the Daily Challenge card.
class DailyRoundScreen extends ConsumerStatefulWidget {
  const DailyRoundScreen({super.key});

  @override
  ConsumerState<DailyRoundScreen> createState() => _DailyRoundScreenState();
}

class _DailyRoundScreenState extends ConsumerState<DailyRoundScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyRoundControllerProvider);

    // Auto-navigate home once the round finishes its done-phase transition.
    ref.listen<AsyncValue<DailyRoundState>>(
      dailyRoundControllerProvider,
      (prev, next) {
        final wasDone = prev?.value?.phase == RoundPhase.done;
        final isDone = next.value?.phase == RoundPhase.done;
        if (!wasDone && isDone) {
          HapticFeedback.heavyImpact();
          // Defer one frame so the listener doesn't fire during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/');
          });
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Round"),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: async.when(
        loading: () => const AppLoadingView(label: 'Building your round…'),
        error: (e, _) => _RoundErrorView(error: e, ref: ref),
        data: (state) => _RoundBody(state: state),
      ),
    );
  }
}

class _RoundBody extends ConsumerWidget {
  const _RoundBody({required this.state});
  final DailyRoundState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChapterHeader(state: state),
        const SizedBox(height: 12),
        Expanded(child: _phaseBody(context, ref)),
      ],
    );
  }

  Widget _phaseBody(BuildContext context, WidgetRef ref) {
    switch (state.phase) {
      case RoundPhase.cards:
        if (state.cards.isEmpty) {
          // Sparse chapter content + no fallback — should not happen with
          // current sampler, but defensive.
          return _SkipToTriviaView();
        }
        return RoundCardsPhase(state: state);
      case RoundPhase.trivia:
        if (state.trivia.isEmpty) {
          return _NoTriviaView(state: state);
        }
        return RoundTriviaPhase(state: state);
      case RoundPhase.reveal:
        return RoundRevealPhase(
          state: state,
          onDone: () async {
            await ref
                .read(dailyRoundControllerProvider.notifier)
                .completeRound();
          },
        );
      case RoundPhase.done:
        // We auto-navigate in the parent's listener; show a brief loader
        // for the one frame this state is visible.
        return const AppLoadingView(label: 'Saving…');
    }
  }
}

/// Magazine-style header that tells the player exactly where they are
/// inside the chapter and the round. Always visible across all phases.
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.state});
  final DailyRoundState state;

  String get _phaseLabel {
    switch (state.phase) {
      case RoundPhase.cards:
        return 'CARDS · 1 OF 2';
      case RoundPhase.trivia:
        return 'TRIVIA · 2 OF 2';
      case RoundPhase.reveal:
        return 'REVEAL';
      case RoundPhase.done:
        return 'DONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: EditorialPalette.ochre),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.chapterTitle.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DAY ${state.dayInChapter} OF ${state.daysInChapter}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _phaseLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundErrorView extends StatelessWidget {
  const _RoundErrorView({required this.error, required this.ref});
  final Object error;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (isSeasonCompleteError(error)) {
      return AppEmptyView(
        icon: Icons.flag_outlined,
        title: 'Season complete',
        body:
            "You've walked through every chapter we have. New content's "
            'on the way — your streak is safe until then.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Home'),
        ),
      );
    }
    if (isNoContentError(error)) {
      return AppEmptyView(
        icon: Icons.menu_book_outlined,
        title: "Today's chapter is loading",
        body:
            "Today's chapter doesn't have playable cards yet — the content's "
            'being authored. Check back tomorrow.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Home'),
        ),
      );
    }
    return AppErrorView(
      title: 'Failed to load round',
      message: '$error',
      onRetry: () => ref.invalidate(dailyRoundControllerProvider),
    );
  }
}

class _NoTriviaView extends StatelessWidget {
  const _NoTriviaView({required this.state});
  final DailyRoundState state;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      icon: Icons.quiz_outlined,
      title: 'No trivia today',
      body:
          'Cards done. Trivia for Chapter ${state.chapterTitle} '
          'is still being authored — your day still counts.',
      action: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Home'),
      ),
    );
  }
}

class _SkipToTriviaView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppEmptyView(
      icon: Icons.arrow_forward_rounded,
      title: 'Skipping to trivia…',
    );
  }
}
