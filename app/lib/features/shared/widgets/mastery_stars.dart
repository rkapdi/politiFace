import 'package:flutter/material.dart';

import '../../session/domain/mastery.dart';

/// Five-star mastery indicator. Accepts either a discrete [level] (legacy,
/// snaps to whole stars) or a continuous [fillFraction] (preferred — fills
/// partial stars so the indicator moves smoothly as stability grows, not
/// just when an FSRS tier threshold is crossed). At least one must be given.
///
/// Pass [showLabel: true] to include the textual tier name ("Learning",
/// "Strong", "Mastered", etc.) under the stars.
class MasteryStars extends StatelessWidget {
  const MasteryStars({
    super.key,
    this.level,
    this.fillFraction,
    this.size = 18,
    this.showLabel = false,
    this.compact = false,
  }) : assert(level != null || fillFraction != null,
            'MasteryStars: pass either level or fillFraction');

  /// Integer tier 0..5. Used when [fillFraction] is null.
  final int? level;

  /// Continuous fill in [0, 5]. When set, takes precedence over [level] and
  /// stars are rendered with partial fills.
  final double? fillFraction;

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

    final fill = (fillFraction ?? level!.toDouble()).clamp(0.0, 5.0);
    // Label uses the floored integer tier so the verbiage still maps to
    // the canonical "Learning / Familiar / Strong / Solid / Mastered" rungs.
    final labelLevel = fill.floor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final starFill = (fill - i).clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0.5 : 1.5),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    // Outline always visible — establishes the slot.
                    Icon(
                      Icons.star_outline_rounded,
                      size: size,
                      color: emptyColor,
                    ),
                    // Filled star clipped to the partial fill amount.
                    if (starFill > 0)
                      ClipRect(
                        clipper: _LeftFractionClipper(starFill),
                        child: Icon(
                          Icons.star_rounded,
                          size: size,
                          color: _filledColor,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            masteryLabelFor(labelLevel),
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

/// Clips a child to its left [fraction] (0..1) of width — used to render
/// partially-filled star icons.
class _LeftFractionClipper extends CustomClipper<Rect> {
  const _LeftFractionClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _LeftFractionClipper old) =>
      old.fraction != fraction;
}
