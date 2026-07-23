// lib/features/live/presentation/live_session_screen.dart
//
// The student side of a live class session. Four faces, one screen:
// lobby (waiting for the professor), question (countdown + lock a choice,
// zero correctness shown), reveal (my verdict, the correct answer, the
// explanation, per-option counts, standings), and ended (podium + my
// rank). Leaving mid-session asks first; sounds respect the ringer and
// skip appear-timed effects under VoiceOver.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../core/audio/sound_service.dart';
import '../application/live_session_controller.dart';
import '../data/live_session_api.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({required this.args, super.key});

  final LiveSessionArgs args;

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  /// The question id whose reveal already played its sound, so a rebuild
  /// or late standings refresh never replays it.
  String? _revealSoundedFor;

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the live session?'),
        content: const Text(
          'You can rejoin while it is running, but questions do not wait.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('STAY'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/leaderboard');
    }
  }

  void _onRevealData(LiveSessionState state) {
    final reveal = state.reveal;
    if (reveal == null || _revealSoundedFor == reveal.questionId) return;
    _revealSoundedFor = reveal.questionId;
    final outcome = state.outcome;
    // Appear-timed sound: skipped under VoiceOver so it never lands on top
    // of the screen announcement (same guard as the mock result chime).
    final a11y = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (!a11y && outcome != null) {
      ref.read(soundServiceProvider).play(
            outcome == LiveOutcome.correct
                ? SoundEffect.correct
                : SoundEffect.incorrect,
          );
    }
    final answer = reveal.correctKey.toUpperCase();
    unawaited(
      SemanticsService.announce(
        switch (outcome) {
          LiveOutcome.correct => 'Correct. The answer is $answer.',
          LiveOutcome.incorrect => 'Incorrect. The answer is $answer.',
          _ => 'Time ran out. The answer is $answer.',
        },
        TextDirection.ltr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(liveSessionApiProvider);
    if (api == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live session')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Live sessions are not available in this build.'),
          ),
        ),
      );
    }

    final state = ref.watch(liveSessionControllerProvider(widget.args));
    ref.listen(liveSessionControllerProvider(widget.args), (previous, next) {
      if (next.reveal != null &&
          previous?.reveal?.questionId != next.reveal!.questionId) {
        _onRevealData(next);
      }
    });

    final ended = state.phase == LivePhase.ended;
    return PopScope(
      canPop: ended,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (await _confirmLeave() && mounted) router.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.title),
          leading: IconButton(
            tooltip: ended ? 'Exit' : 'Leave session',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (ended) {
                _exit();
                return;
              }
              final router = GoRouter.of(context);
              if (await _confirmLeave() && mounted) router.pop();
            },
          ),
        ),
        body: switch (state.phase) {
          LivePhase.connecting =>
            const Center(child: CircularProgressIndicator()),
          LivePhase.lobby => const _LobbyView(),
          LivePhase.question => _QuestionView(
              state: state,
              onChoose: (key) {
                HapticFeedback.lightImpact();
                ref.read(soundServiceProvider).play(SoundEffect.flip);
                unawaited(
                  ref
                      .read(liveSessionControllerProvider(widget.args).notifier)
                      .selectAnswer(key),
                );
              },
            ),
          LivePhase.reveal => _RevealView(state: state),
          LivePhase.ended => _EndedView(state: state, onExit: _exit),
        },
      ),
    );
  }
}

// ── lobby ───────────────────────────────────────────────────────────────────

class _LobbyView extends StatelessWidget {
  const _LobbyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors,
              size: 40,
              color: theme.colorScheme.brandOchreText,
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for your professor to start',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const _AnimatedDots(),
          ],
        ),
      ),
    );
  }
}

/// Three dots breathing in sequence. Subtle by design; stands still when
/// the platform asks for reduced animations.
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.stop();
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: 0.25 +
                      0.75 *
                          (1 - ((_controller.value * 3 - i) % 3).clamp(0, 1)),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── question ────────────────────────────────────────────────────────────────

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.state, required this.onChoose});

  final LiveSessionState state;
  final void Function(String key) onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = state.question;
    final locked = state.lockedKey != null;
    final fraction = state.questionSeconds == 0
        ? 0.0
        : (state.remainingSeconds / state.questionSeconds).clamp(0.0, 1.0);

    return Column(
      children: [
        Semantics(
          label: '${state.remainingSeconds.ceil()} seconds left',
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            color: fraction <= 0.25
                ? theme.colorScheme.brandRed
                : theme.colorScheme.brandNavy,
            backgroundColor: theme.colorScheme.outlineVariant,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'QUESTION ${state.index + 1} OF ${state.total}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (question != null) ...[
                Text(
                  question.stem,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 20),
                for (final option in question.options)
                  _LiveOptionTile(
                    option: option,
                    locked: locked,
                    isChosen: option.key == state.lockedKey,
                    onTap: () => onChoose(option.key),
                  ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (locked) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: theme.colorScheme.brandNavy,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LOCKED IN',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: theme.colorScheme.brandNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'The answer arrives with the reveal.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (state.notice != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.notice!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveOptionTile extends StatelessWidget {
  const _LiveOptionTile({
    required this.option,
    required this.locked,
    required this.isChosen,
    required this.onTap,
  });

  final LiveOption option;
  final bool locked;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navy = theme.colorScheme.brandNavy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: isChosen,
          label: isChosen ? 'Your locked choice.' : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: locked ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isChosen ? navy : theme.colorScheme.outlineVariant,
                  width: isChosen ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
                color: isChosen ? navy.withOpacity(0.10) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.key.toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                  ),
                  if (isChosen) Icon(Icons.lock, color: navy, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── reveal ──────────────────────────────────────────────────────────────────

class _RevealView extends StatelessWidget {
  const _RevealView({required this.state});

  final LiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = state.question;
    final reveal = state.reveal;
    if (question == null || reveal == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final outcome = state.outcome;
    final totalAnswers = reveal.counts.values.fold<int>(0, (sum, n) => sum + n);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'QUESTION ${state.index + 1} OF ${state.total}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _OutcomeBanner(outcome: outcome),
        const SizedBox(height: 12),
        Text(
          question.stem,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
        ),
        const SizedBox(height: 16),
        for (final option in question.options)
          _RevealOptionTile(
            option: option,
            isAnswer: option.key == reveal.correctKey,
            isChosen: option.key == state.lockedKey && state.answerAccepted,
            count: reveal.counts[option.key] ?? 0,
            totalAnswers: totalAnswers,
          ),
        if (reveal.explanation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              reveal.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
        if (state.standings.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'STANDINGS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _StandingsList(standings: state.standings, topCount: 5),
        ],
        const SizedBox(height: 16),
        Text(
          'Next question when your professor moves on.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});

  final LiveOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (outcome) {
      LiveOutcome.correct => (
          'CORRECT',
          theme.colorScheme.brandGreen,
          Icons.check_circle,
        ),
      LiveOutcome.incorrect => (
          'INCORRECT',
          theme.colorScheme.brandRed,
          Icons.cancel,
        ),
      _ => (
          'TOO LATE FOR THIS ONE',
          theme.colorScheme.onSurfaceVariant,
          Icons.hourglass_bottom,
        ),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RevealOptionTile extends StatelessWidget {
  const _RevealOptionTile({
    required this.option,
    required this.isAnswer,
    required this.isChosen,
    required this.count,
    required this.totalAnswers,
  });

  final LiveOption option;
  final bool isAnswer;
  final bool isChosen;
  final int count;
  final int totalAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    final red = theme.colorScheme.brandRed;

    var border = theme.colorScheme.outlineVariant;
    Color? fill;
    if (isAnswer) {
      border = green;
      fill = green.withOpacity(0.10);
    } else if (isChosen) {
      border = red;
      fill = red.withOpacity(0.10);
    }
    final fraction = totalAnswers == 0 ? 0.0 : count / totalAnswers;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: Semantics(
          label: isAnswer
              ? 'Correct answer. $count answered this.'
              : isChosen
                  ? 'Your choice, incorrect. $count answered this.'
                  : '$count answered this.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: border,
                width: (isAnswer || isChosen) ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
              color: fill,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.key.toUpperCase(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.text,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                      ),
                    ),
                    if (isAnswer)
                      Icon(Icons.check_circle, color: green, size: 20)
                    else if (isChosen)
                      Icon(Icons.cancel, color: red, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                // The class's answer spread: a small bar per option.
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            color: isAnswer
                                ? green
                                : theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.45),
                            backgroundColor: theme.colorScheme.outlineVariant
                                .withOpacity(0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$count',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ── standings (shared by reveal and ended) ─────────────────────────────────

class _StandingsList extends StatelessWidget {
  const _StandingsList({required this.standings, required this.topCount});

  final List<LiveStanding> standings;
  final int topCount;

  @override
  Widget build(BuildContext context) {
    final top = standings.take(topCount).toList();
    final me = standings.where((s) => s.isMe).toList();
    final meOutsideTop = me.isNotEmpty && !top.any((s) => s.isMe);
    return Column(
      children: [
        for (final s in top) _StandingRow(standing: s),
        if (meOutsideTop) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '···',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _StandingRow(standing: me.first),
        ],
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing});

  final LiveStanding standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    final isMe = standing.isMe;
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? green.withOpacity(0.10) : null,
          border: Border.all(
            color: isMe
                ? green.withOpacity(0.55)
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${standing.rank}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: standing.rank <= 3
                      ? theme.colorScheme.brandOchreText
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                isMe ? '${standing.handle} (you)' : standing.handle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${standing.score}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ended ───────────────────────────────────────────────────────────────────

class _EndedView extends StatelessWidget {
  const _EndedView({required this.state, required this.onExit});

  final LiveSessionState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = state.myStanding;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Text(
          'SESSION COMPLETE',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (me != null) ...[
          const SizedBox(height: 16),
          Text(
            '#${me.rank}',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${me.correctCount} correct · ${me.score} points',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (state.standings.isNotEmpty) ...[
          Text(
            'PODIUM',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _StandingsList(standings: state.standings, topCount: 3),
        ] else
          const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(
          'Nice work. Scores also count toward your class board.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onExit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          child: const Text(
            'EXIT',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }
}
