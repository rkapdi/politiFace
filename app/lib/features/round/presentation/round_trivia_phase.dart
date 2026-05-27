import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
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
  const RoundTriviaPhase({super.key, required this.state});
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

  Future<void> _confirm(TriviaConfidence confidence) async {
    if (!_pendingMatchesCurrent || _pending == null) return;
    if (confidence == TriviaConfidence.certain) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    final idx = _index;
    final option = _pending!;
    setState(() {
      _pending = null;
      _pendingQuestionCardId = null;
    });
    await ref
        .read(dailyRoundControllerProvider.notifier)
        .answerTrivia(idx, option, confidence);
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressDots(total: total, current: answered),
          const SizedBox(height: 16),
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
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: q.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                return _OptionTile(
                  label: q.options[i],
                  selected: pendingOption == i,
                  onTap: () => _select(i),
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: pendingOption == null
                ? const SizedBox(height: 0)
                : _ConfidenceBar(onPick: _confirm),
          ),
        ],
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
