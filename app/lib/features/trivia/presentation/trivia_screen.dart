import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../application/trivia_controller.dart';
import '../domain/trivia_question.dart';

/// Daily Confidence Trivia. Two taps per question: tap an answer, then tap
/// your confidence (Guess / Pretty Sure / 100%). Confidence is locked in
/// before the correct answer reveals — that's the gambling joke.
class TriviaScreen extends ConsumerWidget {
  const TriviaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(triviaControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Trivia'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load trivia',
          message: '$e',
          onRetry: () => ref.invalidate(triviaControllerProvider),
        ),
        data: (state) {
          if (!state.isLoaded) {
            return const AppEmptyView(
              icon: Icons.school_outlined,
              title: 'Not enough cards yet',
              body: 'Trivia needs at least 4 cards in the pool.',
            );
          }
          if (state.isComplete) {
            // Defer navigation to next microtask — can't call go() during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/trivia/result');
            });
            return const AppLoadingView(label: 'Tallying score…');
          }
          return _QuestionView(state: state);
        },
      ),
    );
  }
}

class _QuestionView extends ConsumerStatefulWidget {
  const _QuestionView({required this.state});
  final TriviaState state;

  @override
  ConsumerState<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends ConsumerState<_QuestionView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final q = state.currentQuestion!;
    final pending = state.pendingAnswerIndex;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress dots — at-a-glance "where am I in the run."
            _ProgressDots(
              total: state.questions.length,
              current: state.currentQuestionIndex,
            ),
            const SizedBox(height: 16),
            // Prompt + (maybe) photo.
            if (q.photoUrl != null) ...[
              Center(
                child: CardAvatar(
                  name: q.options[q.correctIndex],
                  radius: 64,
                  photoUrl: q.photoUrl,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              q.prompt,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            // Answer options.
            Expanded(
              child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                itemCount: q.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  return _OptionTile(
                    label: q.options[i],
                    selected: pending == i,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(triviaControllerProvider.notifier)
                          .selectAnswer(i);
                    },
                  );
                },
              ),
            ),
            // Confidence picker — appears once an answer is selected. This
            // is the "lock in your bet" moment.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: pending == null
                  ? const SizedBox(height: 0)
                  : _ConfidenceBar(
                      onPick: (c) {
                        if (c == TriviaConfidence.certain) {
                          HapticFeedback.mediumImpact();
                        } else {
                          HapticFeedback.lightImpact();
                        }
                        ref
                            .read(triviaControllerProvider.notifier)
                            .confirmConfidence(c);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.total, required this.current});
  final int total;
  final int current;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < current
                  ? theme.colorScheme.primary
                  : (i == current
                      ? theme.colorScheme.primary.withOpacity(0.55)
                      : theme.colorScheme.surfaceContainerHighest),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withOpacity(0.16)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.onPick});
  final void Function(TriviaConfidence) onPick;

  static const _palette = {
    TriviaConfidence.guess: Color(0xFFF59E0B),
    TriviaConfidence.prettySure: Color(0xFF60A5FA),
    TriviaConfidence.certain: Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How sure are you?',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in TriviaConfidence.values) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: () => onPick(c),
                    style: FilledButton.styleFrom(
                      backgroundColor: _palette[c],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (c != TriviaConfidence.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
