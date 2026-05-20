import 'package:flutter/material.dart';

import '../../session/domain/mastery.dart';

/// Five-star mastery bar. [level] should come from
/// [masteryLevelFromStability]. Pass [showLabel: true] to include the textual
/// tier name ("Learning", "Strong", "Mastered", etc.) under the stars.
class MasteryStars extends StatelessWidget {
  const MasteryStars({
    super.key,
    required this.level,
    this.size = 18,
    this.showLabel = false,
    this.compact = false,
  });

  final int level;          // 0..5
  final double size;
  final bool showLabel;
  final bool compact;

  static const _filledColor = Color(0xFFFFC107); // amber
  static const _emptyColor = Color(0x33000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emptyColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.20)
        : _emptyColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final filled = i < level;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0.5 : 1.5),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: filled ? _filledColor : emptyColor,
              ),
            );
          }),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            masteryLabelFor(level),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
