// lib/features/shared/widgets/confidence_bar.dart
//
// The "How sure are you?" control: three buttons (Guess, Pretty sure,
// Certain) that lock in the chosen answer together with a confidence.
// Shared by the daily round's trivia and the FCLE practice, mock and live
// surfaces so the gesture reads the same everywhere.
//
// Two tones:
//   game  The daily round's filled buttons (signal, slate, orange).
//   calm  Neutral outlined buttons for institutional surfaces. No colour
//         carries meaning; the text label is the whole message.
//
// Accessibility: every button is a labelled button with a hint saying it
// locks in the answer; foregrounds are chosen for WCAG AA contrast on
// their fills.

import 'package:flutter/material.dart';

import '../../../app/editorial_theme.dart';
import '../../trivia/domain/trivia_question.dart';

enum ConfidenceBarTone { game, calm }

class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    required this.onPick,
    this.tone = ConfidenceBarTone.game,
    this.title = 'HOW SURE ARE YOU?',
    this.enabled = true,
    super.key,
  });

  final void Function(TriviaConfidence confidence) onPick;
  final ConfidenceBarTone tone;
  final String title;
  final bool enabled;

  static const _gameFill = {
    TriviaConfidence.guess: EditorialPalette.ochre,
    TriviaConfidence.prettySure: EditorialPalette.civicNavy,
    TriviaConfidence.certain: EditorialPalette.actionRed,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calm = tone == ConfidenceBarTone.calm;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in TriviaConfidence.values) ...[
                Expanded(
                  child: Semantics(
                    hint: 'Locks in your answer',
                    child: calm
                        ? _calmButton(theme, c)
                        : _gameButton(c),
                  ),
                ),
                if (c != TriviaConfidence.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _gameButton(TriviaConfidence c) {
    final fill = _gameFill[c]!;
    // Ink on the light fills (signal yellow, orange), white on slate: each
    // pairing clears AA for bold 14pt text.
    final foreground =
        fill == EditorialPalette.civicNavy ? Colors.white : EditorialPalette.ink;
    return FilledButton(
      onPressed: enabled ? () => onPick(c) : null,
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      child: Text(
        c.label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }

  Widget _calmButton(ThemeData theme, TriviaConfidence c) => OutlinedButton(
        onPressed: enabled ? () => onPick(c) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        child: Text(
          c.plainLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      );
}
