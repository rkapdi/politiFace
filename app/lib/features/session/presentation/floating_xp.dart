import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A short-lived "+N XP" label that floats up + fades out. Mount as a Stack
/// child positioned above the grade buttons.
class FloatingXp extends StatefulWidget {
  const FloatingXp({
    super.key,
    required this.amount,
    required this.color,
  });

  final int amount;
  final Color color;

  @override
  State<FloatingXp> createState() => _FloatingXpState();
}

class _FloatingXpState extends State<FloatingXp> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Text(
        '+${widget.amount} XP',
        style: theme.textTheme.titleLarge?.copyWith(
          color: widget.color,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      )
          .animate()
          .fade(duration: 80.ms)
          .moveY(begin: 0, end: -80, duration: 700.ms, curve: Curves.easeOut)
          .then(delay: 0.ms)
          .fade(begin: 1, end: 0, duration: 300.ms),
    );
  }
}
