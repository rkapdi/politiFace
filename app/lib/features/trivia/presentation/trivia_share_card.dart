import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';
import '../domain/trivia_scoring.dart';

/// The 360x640 logical-pt canvas rendered off-screen to PNG (1080x1920 at
/// pixelRatio 3.0) for the trivia share artifact. More branded than the
/// in-app reveal — a stranger seeing this on TikTok needs to know "this is
/// an app" within one second. Light theme always so the artifact reads
/// consistently across recipients regardless of their device theme.
class TriviaShareCard extends StatelessWidget {
  const TriviaShareCard({
    required this.result,
    required this.dateLabel,
    this.benchmark,
    super.key,
  });

  final TriviaResult result;

  /// Pre-formatted "May 26" string. Pass the trivia date, not DateTime.now().
  final String dateLabel;

  /// Optional national-stat line ("Only 11% of Americans can name…") rendered
  /// above the footer. Null on the standalone trivia card (and in golden
  /// tests), so the card's existing layout is unchanged when absent.
  final String? benchmark;

  static const double canvasWidth = 360;
  static const double canvasHeight = 640;

  @override
  Widget build(BuildContext context) {
    final accent = _archetypeAccent(result.archetype);
    final scoreColor = result.totalScore < 0
        ? EditorialPalette.actionRed
        : EditorialPalette.ink;
    final scorePrefix = result.totalScore > 0 ? '+' : '';

    // We deliberately do NOT use Theme.of(context) — the card must render
    // identically regardless of caller theme (especially during off-screen
    // capture, where the inherited theme is whatever sits above the
    // OverlayPortal).
    return Container(
      width: canvasWidth,
      height: canvasHeight,
      color: EditorialPalette.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Branded header (~12% of height) ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POLITIFACE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: EditorialPalette.ink,
                          letterSpacing: 2.4,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'DAILY TRIVIA · ${dateLabel.toUpperCase()}',
                        style: const TextStyle(
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
                  decoration: BoxDecoration(
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1.5,
            color: EditorialPalette.rule,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),

          // ── Hero block (emoji + archetype + score) ─────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji sized via FittedBox so it scales down on tight
                  // viewports (test) but renders large on the real 360pt
                  // canvas — no overflow, no fixed-px gamble.
                  SizedBox(
                    height: 140,
                    child: FittedBox(
                      child: Text(
                        result.archetype.emoji,
                        style: const TextStyle(fontSize: 140, height: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Archetype name — squeeze instead of wrap so long names
                  // like CIVIC BULLSHITTER never push the column over.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      result.archetype.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        letterSpacing: 1.6,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$scorePrefix${result.totalScore} / 150',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                      letterSpacing: -1,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        result.archetype.blurb,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: EditorialPalette.inkSubdued,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Grid emojis (~15% of height) ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Center(
              child: Text(
                result.gridEmojis.join(' '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.4,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // ── Benchmark line (only when provided) ────────────────────────
          if (benchmark != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                benchmark!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: EditorialPalette.inkSubdued,
                  height: 1.25,
                ),
              ),
            ),

          // ── URL footer (~15% of height) ────────────────────────────────
          Container(
            height: 1.5,
            color: EditorialPalette.rule,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 22),
            child: Column(
              children: [
                Text(
                  'PLAY TODAY\'S AT',
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

  static Color _archetypeAccent(TriviaArchetype a) {
    switch (a) {
      case TriviaArchetype.civicScholar:
        return EditorialPalette.civicGreen;
      case TriviaArchetype.luckyGuesser:
        return EditorialPalette.civicNavy;
      case TriviaArchetype.civicBullshitter:
        return EditorialPalette.actionRed;
      case TriviaArchetype.humbleApprentice:
        return EditorialPalette.ochre;
    }
  }
}

/// Format a YYYY-MM-DD string into a "May 26" share-card label. Tolerates
/// malformed input by returning the original string.
String formatShareCardDate(String yyyymmdd) {
  final parts = yyyymmdd.split('-');
  if (parts.length != 3) return yyyymmdd;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final monthIdx = int.tryParse(parts[1]);
  if (monthIdx == null || monthIdx < 1 || monthIdx > 12) return yyyymmdd;
  final day = int.tryParse(parts[2]) ?? 0;
  return '${months[monthIdx - 1]} $day';
}
