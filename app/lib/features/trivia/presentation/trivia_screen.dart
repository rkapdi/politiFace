import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/photo_zoom_modal.dart';
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
  /// Reveal hold after confidence is confirmed. Locks taps, shows green on
  /// the correct option and red on the user's pick (if wrong) before the
  /// answer commits and the next question loads.
  static const _revealDuration = Duration(milliseconds: 750);

  Timer? _revealTimer;
  bool _revealing = false;
  int? _revealCorrectIndex;
  int? _revealPickedIndex;
  String? _revealCardId;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _startReveal(TriviaConfidence confidence) {
    final q = widget.state.currentQuestion;
    final pending = widget.state.pendingAnswerIndex;
    if (q == null || pending == null) return;

    if (confidence == TriviaConfidence.certain) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    HapticFeedback.lightImpact();

    setState(() {
      _revealing = true;
      _revealCorrectIndex = q.correctIndex;
      _revealPickedIndex = pending;
      _revealCardId = q.cardId;
    });

    _revealTimer?.cancel();
    _revealTimer = Timer(_revealDuration, () {
      if (!mounted) return;
      ref.read(triviaControllerProvider.notifier).confirmConfidence(confidence);
      setState(() {
        _revealing = false;
        _revealCorrectIndex = null;
        _revealPickedIndex = null;
        _revealCardId = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final q = state.currentQuestion!;
    final pending = state.pendingAnswerIndex;

    // Only honor reveal state when it matches the current question — guards
    // against stale state if the controller jumped ahead unexpectedly.
    final revealActive = _revealing && _revealCardId == q.cardId;

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
                child: _ZoomablePromptAvatar(
                  heroTag: 'trivia-${q.cardId}',
                  name: q.options[q.correctIndex],
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
                itemBuilder: (context, i) => _OptionTile(
                    label: q.options[i],
                    selected: pending == i,
                    revealMode: revealActive
                        ? _revealModeFor(
                            i,
                            correctIndex: _revealCorrectIndex!,
                            pickedIndex: _revealPickedIndex,
                          )
                        : _RevealMode.idle,
                    onTap: revealActive
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(triviaControllerProvider.notifier)
                                .selectAnswer(i);
                          },
                  ),
              ),
            ),
            // Confidence picker — appears once an answer is selected. This
            // is the "lock in your bet" moment. Hidden during reveal.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: (pending == null || revealActive)
                  ? const SizedBox(height: 0)
                  : _ConfidenceBar(onPick: _startReveal),
            ),
          ],
        ),
      ),
    );
  }
}

_RevealMode _revealModeFor(
  int index, {
  required int correctIndex,
  required int? pickedIndex,
}) {
  if (index == correctIndex) return _RevealMode.correctReveal;
  if (index == pickedIndex) return _RevealMode.wrongReveal;
  return _RevealMode.neutralReveal;
}

enum _RevealMode { idle, correctReveal, wrongReveal, neutralReveal }

/// Prompt-sized avatar that scales with screen size and opens a full-screen
/// Hero-animated zoom when tapped.
class _ZoomablePromptAvatar extends StatelessWidget {
  const _ZoomablePromptAvatar({
    required this.heroTag,
    required this.name,
    required this.photoUrl,
  });

  final String heroTag;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        PhotoZoomModal.show(
          context,
          heroTag: heroTag,
          name: name,
          photoUrl: photoUrl,
        );
      },
      child: Hero(
        tag: heroTag,
        child: ResponsiveCardAvatar(
          name: name,
          photoUrl: photoUrl,
          factor: 0.24,
          minRadius: 64,
          maxRadius: 110,
        ),
      ),
    );
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
    this.revealMode = _RevealMode.idle,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final _RevealMode revealMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrectReveal = revealMode == _RevealMode.correctReveal;
    final isWrongReveal = revealMode == _RevealMode.wrongReveal;
    final isRevealing = revealMode != _RevealMode.idle;

    final Color bg;
    final Color borderColor;
    if (isCorrectReveal) {
      bg = Colors.green.shade400.withOpacity(0.22);
      borderColor = Colors.green.shade400;
    } else if (isWrongReveal) {
      bg = Colors.red.shade400.withOpacity(0.22);
      borderColor = Colors.red.shade400;
    } else if (isRevealing) {
      bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
      borderColor = Colors.transparent;
    } else if (selected) {
      bg = theme.colorScheme.primary.withOpacity(0.16);
      borderColor = theme.colorScheme.primary;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      borderColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          (selected || isCorrectReveal || isWrongReveal)
                              ? FontWeight.w800
                              : FontWeight.w600,
                      color: isRevealing && revealMode == _RevealMode.neutralReveal
                          ? theme.colorScheme.onSurface.withOpacity(0.55)
                          : null,
                    ),
                  ),
                ),
                if (isCorrectReveal)
                  Icon(Icons.check_circle,
                      color: Colors.green.shade400, size: 22,)
                else if (isWrongReveal)
                  Icon(Icons.cancel, color: Colors.red.shade400, size: 22)
                else if (selected)
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
              ],
            ),
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
