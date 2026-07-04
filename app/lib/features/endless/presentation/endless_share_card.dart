import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';

/// Off-screen 360x640 logical-pt canvas captured to PNG (1080x1920 at
/// pixelRatio 3.0) for the Endless share artifact. Mirrors the shape of
/// [TriviaShareCard] so the two share cards feel like siblings — but
/// surfaces streak + correct/total since Endless has no archetype.
class EndlessShareCard extends StatelessWidget {
  const EndlessShareCard({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCorrect,
    required this.totalAnswered,
    required this.dateLabel,
    super.key,
  });

  final int currentStreak;
  final int bestStreak;
  final int totalCorrect;
  final int totalAnswered;
  final String dateLabel;

  static const double canvasWidth = 360;
  static const double canvasHeight = 640;

  @override
  Widget build(BuildContext context) {
    final accuracy = totalAnswered == 0
        ? 0
        : ((totalCorrect / totalAnswered) * 100).round();

    return Container(
      width: canvasWidth,
      height: canvasHeight,
      color: EditorialPalette.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POLITIFACE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: EditorialPalette.ink,
                          letterSpacing: 2.4,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'ENDLESS RUN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: EditorialPalette.inkSubdued,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  color: EditorialPalette.civicNavy,
                ),
              ],
            ),
          ),
          Container(
            height: 1.5,
            color: EditorialPalette.rule,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'STREAK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: EditorialPalette.inkSubdued,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$bestStreak',
                    style: const TextStyle(
                      fontSize: 130,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE67E22),
                      height: 1,
                      letterSpacing: -3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'IN A ROW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: EditorialPalette.inkSubdued,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatBlock(
                        label: 'CORRECT',
                        value: '$totalCorrect/$totalAnswered',
                      ),
                      Container(width: 1, height: 36, color: EditorialPalette.rule),
                      _StatBlock(label: 'ACCURACY', value: '$accuracy%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1.5,
            color: EditorialPalette.rule,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(
              dateLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: EditorialPalette.inkSubdued,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 22),
            child: Column(
              children: [
                Text(
                  'BEAT IT AT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: EditorialPalette.inkSubdued,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'politiface.app',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: EditorialPalette.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: EditorialPalette.inkSubdued,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: EditorialPalette.ink,
            letterSpacing: -0.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
}
