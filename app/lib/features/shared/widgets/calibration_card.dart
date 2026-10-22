// lib/features/shared/widgets/calibration_card.dart
//
// "How sure vs. how right": one plain sentence per confidence label the
// student actually used. Text carries the whole message (no colour
// meaning, no points), and the card renders nothing when no answer had a
// confidence, so older flows and skipped answers stay quiet.

import 'package:flutter/material.dart';

import '../../trivia/domain/calibration.dart';

class CalibrationCard extends StatelessWidget {
  const CalibrationCard({required this.outcomes, super.key});

  final List<ConfidenceOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final rows = calibrate(outcomes);
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'HOW SURE VS. HOW RIGHT',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                row.sentence,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          Text(
            'Knowing what you know is a skill too. It does not change your '
            'score.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
