import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../shared/widgets/card_avatar.dart';
import '../domain/round_state.dart';

/// Cards phase of the daily round. Renders the current ungraded card with
/// a flip-to-answer interaction, then grade buttons. Advances via
/// [DailyRoundController.gradeCard].
///
/// Visually mirrors the existing free-explore SessionScreen card view so
/// the gesture vocabulary (tap to reveal, grade button row) is consistent
/// across the two flows. Phase 3 keeps things text-only for the chapter
/// round; photo rendering comes back when the curriculum content layer
/// catches up.
class RoundCardsPhase extends ConsumerStatefulWidget {
  const RoundCardsPhase({required this.state, super.key});
  final DailyRoundState state;

  @override
  ConsumerState<RoundCardsPhase> createState() => _RoundCardsPhaseState();
}

class _RoundCardsPhaseState extends ConsumerState<RoundCardsPhase> {
  /// Which card the user has tapped to reveal. Stored by cardId (not a
  /// bool) so that when the parent rebuilds with the next card the
  /// computed `_revealed` flips back to false automatically — no manual
  /// reset, no race with the controller's setState.
  String? _revealedCardId;

  int get _index =>
      widget.state.nextUngradedCard ?? widget.state.cards.length - 1;
  RoundCard get _card => widget.state.cards[_index];
  bool get _revealed => _revealedCardId == _card.cardId;

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealedCardId = _card.cardId);
  }

  Future<void> _grade(int grade) async {
    HapticFeedback.lightImpact();
    final idx = _index;
    await ref
        .read(dailyRoundControllerProvider.notifier)
        .gradeCard(idx, grade);
  }

  Future<void> _gotIt() async {
    // Teach-first concept: a single acknowledge grades 'good' through the
    // normal pipeline (it's the card's first review, so FSRS schedules it).
    HapticFeedback.lightImpact();
    await ref
        .read(dailyRoundControllerProvider.notifier)
        .gradeCard(_index, 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.state.cards.length;
    final completed =
        widget.state.cards.where((c) => c.grade != null).length;
    final progress = total == 0 ? 0.0 : completed / total;

    if (_card.teachFirst && _card.grade == null) {
      return _TeachCard(
        key: ValueKey('teach-${_card.cardId}'),
        card: _card,
        progressLabel: 'CARD ${completed + 1} OF $total',
        progress: progress,
        onGotIt: _gotIt,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress strip — magazine-style hairline.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.brandOchre),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CARD ${completed + 1} OF $total',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: GestureDetector(
              onTap: _reveal,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: _FlipCard(
                  key: ValueKey(_card.cardId),
                  revealed: _revealed,
                  front: _CardFront(card: _card),
                  back: _CardBack(card: _card),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: _revealed
                ? Row(
                    children: [
                      Expanded(child: _gradeBtn('AGAIN', 0, EditorialPalette.actionRed)),
                      const SizedBox(width: 8),
                      Expanded(child: _gradeBtn('HARD', 1, EditorialPalette.ochre)),
                      const SizedBox(width: 8),
                      Expanded(child: _gradeBtn('GOOD', 2, EditorialPalette.civicGreen)),
                      const SizedBox(width: 8),
                      Expanded(child: _gradeBtn('EASY', 3, EditorialPalette.civicNavy)),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _reveal,
                      child: const Text('REVEAL'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _gradeBtn(String label, int grade, Color color) => FilledButton(
      onPressed: () => _grade(grade),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          fontSize: 12,
        ),
      ),
      child: Text(label),
    );
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});
  final RoundCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: EditorialPalette.ochre,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            'KNOW THIS?',
            style: theme.textTheme.labelSmall?.copyWith(
              color: EditorialPalette.ink,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          card.prompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Tap to reveal',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card});
  final RoundCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAvatar = card.politicianName != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAvatar) ...[
            ResponsiveCardAvatar(
              name: card.politicianName!,
              photoUrl: card.photoUrl,
              factor: 0.26,
              minRadius: 64,
              maxRadius: 96,
            ),
            const SizedBox(height: 14),
          ],
          Text(
            card.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1.5,
            width: 40,
            color: EditorialPalette.rule,
          ),
          const SizedBox(height: 16),
          Text(
            card.answer,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D Y-axis flip between [front] and [back]. Same shape as the existing
/// session screen's flip card — copied (not extracted) for now so we
/// don't have to widen the session module's public API for one consumer.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.revealed, required this.front, required this.back, super.key,
  });

  final bool revealed;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      // begin = end on remount — prevents the flash-of-back-side bug the
      // session screen also fixed by keying the flip card.
      tween: Tween<double>(begin: revealed ? 1.0 : 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final showingFront = value < 0.5;
        final angle = value * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
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

/// First encounter with a concept card: a lesson presentation, not a quiz.
/// One button — GOT IT — which grades 'good' and schedules the first
/// FSRS review. Recall encounters use the normal flip card instead.
class _TeachCard extends StatelessWidget {
  const _TeachCard({
    required this.card,
    required this.progressLabel,
    required this.progress,
    required this.onGotIt,
    super.key,
  });

  final RoundCard card;
  final String progressLabel;
  final double progress;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              valueColor:
                  AlwaysStoppedAnimation(theme.colorScheme.brandOchre),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4,),
                    decoration: BoxDecoration(
                      color: EditorialPalette.civicGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'NEW CONCEPT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    card.answer == card.body
                        ? card.prompt
                        : card.prompt,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    card.body ?? card.answer,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onGotIt,
            style: FilledButton.styleFrom(
              backgroundColor: EditorialPalette.civicGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'GOT IT',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
