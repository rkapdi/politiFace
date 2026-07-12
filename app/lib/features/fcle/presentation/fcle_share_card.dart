// lib/features/fcle/presentation/fcle_share_card.dart
//
// The score-challenge share artifact: "I got X of 80. Could you pass?"
// Off-screen 360x640 logical-pt canvas captured to PNG (1080x1920 at
// pixelRatio 3.0), sibling to TriviaShareCard and EndlessShareCard.
// Positioning holds even here: a mock is practice, never the official
// exam, so the card says Mock FCLE and challenges, it does not certify.

import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';
import '../domain/fcle_question.dart';
import '../domain/mock_engine.dart';

class FcleShareCard extends StatelessWidget {
  const FcleShareCard({
    required this.result,
    required this.dateLabel,
    super.key,
  });

  final MockResult result;
  final String dateLabel;

  static const double canvasWidth = 360;
  static const double canvasHeight = 640;

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final accent =
        passed ? EditorialPalette.civicGreen : EditorialPalette.actionRed;
    final passLine = (result.total * MockEngine.passFraction).ceil();

    return Container(
      width: canvasWidth,
      height: canvasHeight,
      color: EditorialPalette.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
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
                        'MOCK FCLE · FLORIDA CIVIC LITERACY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: EditorialPalette.inkSubdued,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: EditorialPalette.inkSubdued,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: EditorialPalette.ink,
          ),
          const Spacer(),
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${result.score}',
                    style: TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      height: 1,
                      letterSpacing: -3,
                    ),
                  ),
                  TextSpan(
                    text: ' /${result.total}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: EditorialPalette.inkSubdued,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent, width: 1.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                passed ? 'ABOVE THE PASSING BAR' : 'BELOW THE BAR, FOR NOW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Passing is $passLine of ${result.total}.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EditorialPalette.inkSubdued,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                for (final d in FcleDomain.values)
                  _DomainRow(
                    label: d.label,
                    score: result.perDomain[d],
                  ),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Could you pass the Florida civics exam?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: EditorialPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 22),
            child: Column(
              children: [
                Text(
                  'BEAT MY SCORE AT',
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

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.label, required this.score});

  final String label;
  final DomainScore? score;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final fraction = s == null || s.total == 0 ? 0.0 : s.correct / s.total;
    final color = fraction >= MockEngine.passFraction
        ? EditorialPalette.civicGreen
        : EditorialPalette.actionRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: EditorialPalette.inkSubdued,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                s == null ? '·' : '${s.correct}/${s.total}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: EditorialPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: EditorialPalette.ink.withOpacity(0.08),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
