// lib/features/fcle/presentation/mock_result_screen.dart
//
// Mock FCLE results: score against the 60% bar, per-domain breakdown,
// straight line into weak-area practice. A mock is practice, not a
// prediction; the copy says so (FLDOE positioning rule).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../domain/mock_engine.dart';

class MockResultScreen extends ConsumerWidget {
  const MockResultScreen({required this.result, super.key});

  final MockResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    final red = theme.colorScheme.brandRed;
    final passColor = result.passed ? green : red;
    final passLine = (result.total * MockEngine.passFraction).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock results'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: passColor.withOpacity(0.10),
              border: Border.all(color: passColor.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  '${result.score} / ${result.total}',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  result.passed
                      ? 'Above the passing bar of $passLine.'
                      : 'The passing bar is $passLine. Keep practicing.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: passColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A mock is practice, not a prediction of your official result.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (result.pendingSync) ...[
            const SizedBox(height: 4),
            Text(
              'Scored offline. Your attempt syncs on the next connection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'BY DOMAIN',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in result.perDomain.entries) ...[
            _DomainBar(
              label: entry.key.label,
              score: entry.value,
              passFraction: MockEngine.passFraction,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            onPressed: () => context.pushReplacement(
              '/fcle/practice?domain=${result.weakestDomain.code}',
            ),
            child: Text(
              'PRACTICE ${result.weakestDomain.label.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            onPressed: () => context.go('/fcle'),
            child: const Text(
              'BACK TO FCLE PREP',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({
    required this.label,
    required this.score,
    required this.passFraction,
  });

  final String label;
  final DomainScore score;
  final double passFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = score.total == 0 ? 0.0 : score.correct / score.total;
    final color = fraction >= passFraction
        ? theme.colorScheme.brandGreen
        : theme.colorScheme.brandRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${score.correct}/${score.total}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}
