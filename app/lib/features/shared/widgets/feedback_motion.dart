// lib/features/shared/widgets/feedback_motion.dart
//
// Shared answer and reward motion, so every quiz screen reacts the same
// way:
//   - AnswerReaction: the chosen option pops on a right answer and gives a
//     short side-to-side shake on a wrong one.
//   - CountUpText: a score that counts up instead of appearing.
//   - CelebrationBurst: a one-shot confetti burst for big moments.
// Motion is decoration only: colour, icon, text, and semantics carry the
// meaning, and everything collapses to its final state under Reduce Motion
// (MediaQuery.disableAnimations), like the rest of the neo kit.

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

enum AnswerReactionKind { none, correct, wrong }

/// Wraps an answer option. Plays once each time [kind] changes from
/// [AnswerReactionKind.none] to correct or wrong.
class AnswerReaction extends StatefulWidget {
  const AnswerReaction({required this.kind, required this.child, super.key});

  final AnswerReactionKind kind;
  final Widget child;

  static const popDuration = Duration(milliseconds: 260);
  static const shakeDuration = Duration(milliseconds: 380);

  @override
  State<AnswerReaction> createState() => _AnswerReactionState();
}

class _AnswerReactionState extends State<AnswerReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didUpdateWidget(AnswerReaction old) {
    super.didUpdateWidget(old);
    if (old.kind == widget.kind || widget.kind == AnswerReactionKind.none) {
      return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _c
      ..duration = widget.kind == AnswerReactionKind.correct
          ? AnswerReaction.popDuration
          : AnswerReaction.shakeDuration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = _c.value;
          if (!_c.isAnimating || t == 0 || t == 1) return child!;
          if (widget.kind == AnswerReactionKind.correct) {
            return Transform.scale(
              scale: 1 + 0.05 * math.sin(math.pi * t),
              child: child,
            );
          }
          // Three damped swings, 8 logical pixels at most.
          final dx = 8 * math.sin(t * math.pi * 6) * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// A whole number that counts up from zero to [value] on first build (and
/// from the old value on change). Screen readers hear only the final text.
class CountUpText extends StatelessWidget {
  const CountUpText({
    required this.value,
    required this.format,
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.textAlign,
  });

  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final finalText = format(value);
    if (reduce) return Text(finalText, style: style, textAlign: textAlign);
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) =>
            Text(format(v.round()), style: style, textAlign: textAlign),
      ),
    );
  }
}

/// A one-shot confetti burst from the top centre of its parent [Stack].
/// Fires once when built with [fire] true (or when [fire] turns true).
/// Silent and invisible under Reduce Motion.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({required this.fire, super.key, this.big = false});

  final bool fire;

  /// More particles, for the biggest moments (passing a mock exam).
  final bool big;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst> {
  final _controller = ConfettiController(duration: const Duration(seconds: 2));
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _maybeFire();
  }

  @override
  void didUpdateWidget(CelebrationBurst old) {
    super.didUpdateWidget(old);
    _maybeFire();
  }

  void _maybeFire() {
    if (!widget.fire || _fired) return;
    _fired = true;
    // After the first frame so the screen is laid out before particles
    // emit (otherwise they can hang at the top).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _controller.play();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _controller,
                blastDirection: math.pi / 2,
                maxBlastForce: 18,
                minBlastForce: 6,
                emissionFrequency: 0.04,
                numberOfParticles: widget.big ? 30 : 15,
                gravity: 0.25,
                colors: const [
                  Color(0xFFC0392B),
                  Color(0xFF1A3A5C),
                  Color(0xFFF1C40F),
                  Color(0xFF27AE60),
                  Color(0xFFE67E22),
                ],
              ),
            ),
          ),
        ),
      );
}
