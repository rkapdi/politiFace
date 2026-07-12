import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../profile/data/profile_service.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/mastery_stars.dart';
import '../../shared/widgets/state_views.dart';
import '../application/session_controller.dart';
import '../domain/fsrs_algorithm.dart';
import '../domain/mastery.dart';
import '../domain/session_queue.dart';
import 'floating_xp.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<SessionState>>(sessionControllerProvider,
        (prev, next) {
      final wasComplete = prev?.value?.isComplete ?? false;
      final isComplete = next.value?.isComplete ?? false;
      if (!wasComplete && isComplete) {
        HapticFeedback.heavyImpact();
        context.go('/summary');
      }
    });

    final async = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        leading: IconButton(
          tooltip: 'Close session',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: async.when(
        loading: () => const AppLoadingView(label: 'Loading session…'),
        error: (e, _) => AppErrorView(
          title: 'Failed to load session',
          message: '$e',
          onRetry: () => ref.invalidate(sessionControllerProvider),
        ),
        data: (s) {
          if (s.currentCard == null && s.completed == 0) {
            return AppEmptyView(
              icon: Icons.check_circle_outline,
              title: 'No cards due',
              body: 'Come back tomorrow — your streak resets at midnight.',
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Home'),
              ),
            );
          }
          if (s.currentCard == null) {
            return const AppLoadingView();
          }
          return _CardView(
            state: s,
            onGrade: (g) => ref
                .read(sessionControllerProvider.notifier)
                .handleGrade(g),
          );
        },
      ),
    );
  }
}

class _CardView extends ConsumerStatefulWidget {
  const _CardView({required this.state, required this.onGrade});
  final SessionState state;
  final void Function(FSRSGrade) onGrade;

  @override
  ConsumerState<_CardView> createState() => _CardViewState();
}

class _CardViewState extends ConsumerState<_CardView> {
  int _floaterSeq = 0;
  int _floaterAmount = 0;
  Color _floaterColor = Colors.green;

  void _triggerGrade(FSRSGrade grade, Color color) {
    setState(() {
      _floaterSeq++;
      _floaterAmount = ProfileService.xpForGrade(grade);
      _floaterColor = color;
    });
    if (grade == FSRSGrade.again) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    widget.onGrade(grade);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.state.currentCard!;
    final theme = Theme.of(context);
    final progress = widget.state.totalPlanned == 0
        ? 0.0
        : widget.state.completed / widget.state.totalPlanned;
    final revealed = ref.watch(cardRevealedProvider);

    if (card.teachFirst) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              const SizedBox(height: 8),
              Text(
                '${widget.state.completed} / ${widget.state.totalPlanned}'
                '  •  NEW CONCEPT',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.politicianName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.body ?? card.title,
                        style:
                            theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    _triggerGrade(FSRSGrade.good, Colors.green.shade300),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('GOT IT'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 8),
            Text(
              '${widget.state.completed} / ${widget.state.totalPlanned}'
              '${card.phase == CardPhase.newCard ? "  •  NEW" : ""}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!revealed) {
                    HapticFeedback.lightImpact();
                    ref.read(cardRevealedProvider.notifier).state = true;
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Center(
                  // Key by card id so the TweenAnimationBuilder inside resets
                  // when the card changes — otherwise it animates back from
                  // 1.0 → 0.0 and briefly flashes the next card's answer.
                  child: _FlipCard(
                    key: ValueKey(card.cardId),
                    revealed: revealed,
                    front: _Question(card: card),
                    back: _Answer(card: card),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (revealed)
                    Row(
                      children: [
                        Expanded(
                          child: _GradeButton(
                            label: 'Again',
                            color: Colors.red.shade400,
                            onPressed: () => _triggerGrade(
                              FSRSGrade.again,
                              Colors.red.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GradeButton(
                            label: 'Hard',
                            color: Colors.orange.shade400,
                            onPressed: () => _triggerGrade(
                              FSRSGrade.hard,
                              Colors.orange.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GradeButton(
                            label: 'Good',
                            color: Colors.green.shade400,
                            onPressed: () => _triggerGrade(
                              FSRSGrade.good,
                              Colors.green.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GradeButton(
                            label: 'Easy',
                            color: Colors.blue.shade400,
                            onPressed: () => _triggerGrade(
                              FSRSGrade.easy,
                              Colors.blue.shade300,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(cardRevealedProvider.notifier).state = true;
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Reveal'),
                      ),
                    ),
                  if (_floaterSeq > 0)
                    Positioned(
                      top: -8,
                      child: FloatingXp(
                        key: ValueKey('xp-floater-$_floaterSeq'),
                        amount: _floaterAmount,
                        color: _floaterColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 3D Y-axis flip between [front] and [back]. Driven by [revealed]; uses
/// TweenAnimationBuilder so we don't need an AnimationController.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.revealed, required this.front, required this.back, super.key,
  });

  final bool revealed;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final showingFront = value < 0.5;
        final angle = value * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // perspective
            ..rotateY(angle),
          child: showingFront
              ? front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back,
                ),
        );
      },
    );
}

class _Question extends StatelessWidget {
  const _Question({required this.card});
  final SessionCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (card.isConcept) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.recallPrompt ?? card.politicianName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to reveal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(card: card, radius: 72),
        const SizedBox(height: 24),
        Text(
          'Who is this?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to reveal',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.card});
  final SessionCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Continuous fill — moves on any review, not just bucket-tier crossings.
    // Stays in sync with the node bar's curve.
    final fill = cardStarFill(
      isNewCard: card.phase == CardPhase.newCard,
      stability: card.stability,
      reviewCount: card.reviewCount,
    );
    if (card.isConcept) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.politicianName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              card.body ?? card.title,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            MasteryStars(fillFraction: fill, size: 22, showLabel: true),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(card: card, radius: 56),
        const SizedBox(height: 16),
        Text(
          card.politicianName,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          card.title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (card.oneLiner != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              card.oneLiner!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 20),
        MasteryStars(fillFraction: fill, size: 22, showLabel: true),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.card, required this.radius});
  final SessionCard card;
  final double radius;

  @override
  Widget build(BuildContext context) => CardAvatar(
      name: card.politicianName,
      radius: radius,
      photoUrl: card.photoUrl,
      lqipBase64: card.lqipBase64,
    );
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label),
    );
}
