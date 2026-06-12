import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/photo_zoom_modal.dart';
import '../../trivia/domain/trivia_question.dart';
import '../domain/round_state.dart';

/// Trivia phase of the daily round. Same two-tap UX as the standalone
/// TriviaScreen — pick an answer, then pick confidence — but consumes
/// [DailyRoundController] state.
///
/// Visually mirrors `trivia_screen.dart`'s `_QuestionView`. Copied (not
/// shared) so the standalone trivia flow stays untouched until the
/// Phase 5 cutover.
class RoundTriviaPhase extends ConsumerStatefulWidget {
  const RoundTriviaPhase({required this.state, super.key});
  final DailyRoundState state;

  @override
  ConsumerState<RoundTriviaPhase> createState() => _RoundTriviaPhaseState();
}

class _RoundTriviaPhaseState extends ConsumerState<RoundTriviaPhase> {
  /// Pending option index for the current question — local to this widget
  /// because it's UI-only state (we don't persist "I tapped but didn't
  /// confirm" across app restarts).
  int? _pending;
  String? _pendingQuestionCardId;

  /// Reveal-state for the 750ms hold after confidence is confirmed and
  /// before the answer is committed. Mirrors the standalone trivia
  /// screen's reveal logic so the two feel identical.
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

  int get _index =>
      widget.state.nextUnansweredTrivia ??
      widget.state.trivia.length - 1;
  RoundTrivia get _currentTrivia => widget.state.trivia[_index];
  TriviaQuestion get _question => _currentTrivia.question;

  bool get _pendingMatchesCurrent =>
      _pendingQuestionCardId == _question.cardId;

  void _select(int optionIdx) {
    HapticFeedback.selectionClick();
    setState(() {
      _pending = optionIdx;
      _pendingQuestionCardId = _question.cardId;
    });
  }

  void _confirm(TriviaConfidence confidence) {
    if (!_pendingMatchesCurrent || _pending == null) return;
    if (confidence == TriviaConfidence.certain) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    HapticFeedback.lightImpact();

    final idx = _index;
    final option = _pending!;
    final q = _question;

    setState(() {
      _revealing = true;
      _revealCorrectIndex = q.correctIndex;
      _revealPickedIndex = option;
      _revealCardId = q.cardId;
    });

    _revealTimer?.cancel();
    _revealTimer = Timer(_revealDuration, () async {
      if (!mounted) return;
      // Commit answer first, then clear UI state. The parent will rebuild
      // with the next question after the controller updates.
      await ref
          .read(dailyRoundControllerProvider.notifier)
          .answerTrivia(idx, option, confidence);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _pendingQuestionCardId = null;
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
    final q = _question;
    final total = widget.state.trivia.length;
    final answered = widget.state.trivia.where((t) => t.isAnswered).length;
    // _pending only applies while we're still on the same question — if
    // the parent rebuilt with a new question (after we just confirmed),
    // clear visual state.
    final pendingOption = _pendingMatchesCurrent ? _pending : null;
    final revealActive = _revealing && _revealCardId == q.cardId;

    final streak = widget.state.currentCorrectStreak;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _ProgressDots(total: total, current: answered)),
              if (streak >= 2) ...[
                const SizedBox(width: 10),
                _StreakChip(streak: streak),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (q.photoUrl != null) ...[
            Center(
              child: _ZoomablePromptAvatar(
                heroTag: 'round-trivia-${q.cardId}',
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
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: q.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _OptionTile(
                  label: q.options[i],
                  selected: pendingOption == i,
                  revealMode: revealActive
                      ? _revealModeFor(
                          i,
                          correctIndex: _revealCorrectIndex!,
                          pickedIndex: _revealPickedIndex,
                        )
                      : _RevealMode.idle,
                  onTap: revealActive ? null : () => _select(i),
                ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: (pendingOption == null || revealActive)
                ? const SizedBox(height: 0)
                : _ConfidenceBar(onPick: _confirm),
          ),
        ],
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
    TriviaConfidence.guess: EditorialPalette.ochre,
    TriviaConfidence.prettySure: EditorialPalette.civicNavy,
    TriviaConfidence.certain: EditorialPalette.actionRed,
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
            'HOW SURE ARE YOU?',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
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
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
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

/// Small streak indicator shown beside the progress dots while the user has
/// 2+ correct answers in a row. Visual vocabulary borrowed from Endless's
/// score bar so the streak idea reads consistently across game modes.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE67E22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        border: Border.all(color: accent.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, color: accent, size: 14),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
