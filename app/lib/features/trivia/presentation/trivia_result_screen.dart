import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/trivia_controller.dart';
import '../domain/trivia_scoring.dart';

/// Post-run archetype reveal. Designed as the screen-recordable money shot:
/// big emoji + bold archetype name + score, with a small grid footer that
/// shows the per-question color block. Phone screen-recorded vertically →
/// drop into TikTok / Reels with zero editing.
class TriviaResultScreen extends ConsumerWidget {
  const TriviaResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(triviaControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Archetype'),
        automaticallyImplyLeading: false,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to compute result: $e'),
        ),
        data: (state) {
          if (!state.isComplete) {
            // Bounce to the active run if the user landed here weird.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/trivia');
            });
            return const SizedBox.shrink();
          }
          return _ResultBody(result: state.result);
        },
      ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.result});
  final TriviaResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _archetypeColor(result.archetype);
    final scoreColor = result.totalScore < 0
        ? Colors.red.shade400
        : (result.totalScore >= 100
            ? Colors.green.shade400
            : theme.colorScheme.onSurface);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Archetype emoji — big and centered. Screen-record this.
            Center(
              child: Text(
                result.archetype.emoji,
                style: const TextStyle(fontSize: 110),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1.0, 1.0),
                    duration: 520.ms,
                    curve: Curves.elasticOut,
                  )
                  .fade(duration: 300.ms),
            ),
            const SizedBox(height: 8),
            // Archetype name — bold, all caps for share appeal.
            Text(
              result.archetype.name.toUpperCase(),
              style: theme.textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 240.ms, duration: 360.ms).slideY(
                  begin: 0.1,
                  end: 0,
                  delay: 240.ms,
                  duration: 360.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 6),
            Text(
              result.archetype.blurb,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 520.ms, duration: 360.ms),
            const SizedBox(height: 28),
            // Score, big.
            Center(
              child: Text(
                '${result.totalScore > 0 ? '+' : ''}${result.totalScore} / 150',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ).animate().fade(delay: 700.ms, duration: 360.ms),
            const SizedBox(height: 8),
            Text(
              '${result.correctCount}/${result.totalQuestions} correct · avg confidence ${result.averageConfidence.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(delay: 820.ms, duration: 360.ms),
            const SizedBox(height: 28),
            // The emoji grid — share-block preview. Also rendered inline in
            // the share text by _shareText().
            Center(
              child: Text(
                result.gridEmojis.join(' '),
                style: const TextStyle(fontSize: 26, height: 1.2),
                textAlign: TextAlign.center,
              ),
            ).animate().fade(delay: 940.ms, duration: 380.ms),
            const Spacer(),
            // Actions.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(
                        ClipboardData(text: _shareText(result)),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(triviaControllerProvider.notifier).reset();
                      context.go('/');
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Wordle-style text payload for iMessage / X — emoji grid, archetype,
  /// score, app pointer.
  String _shareText(TriviaResult r) {
    return 'Politiface Daily — ${r.archetype.emoji} ${r.archetype.name}\n'
        '${r.totalScore > 0 ? '+' : ''}${r.totalScore} / 150\n'
        '${r.gridEmojis.join('')}\n'
        'politiface.app';
  }

  Color _archetypeColor(TriviaArchetype a) {
    switch (a) {
      case TriviaArchetype.civicScholar:
        return const Color(0xFF34D399); // green
      case TriviaArchetype.luckyGuesser:
        return const Color(0xFF60A5FA); // blue
      case TriviaArchetype.civicBullshitter:
        return const Color(0xFFEF4444); // red — the viral one
      case TriviaArchetype.humbleApprentice:
        return const Color(0xFFC084FC); // purple
    }
  }
}
