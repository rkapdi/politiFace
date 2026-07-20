import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../government/application/gov_map_data.dart';
import '../../government/application/node_detail_data.dart';
import '../application/session_controller.dart';
import 'session_map_summary.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    // Delay play() so the map fly-to widget has time to lay out — otherwise
    // the confetti emits before the screen is settled and particles
    // sometimes hang at the top instead of raining down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Screen-appear sound: skipped under VoiceOver so the chime never
      // lands on top of the screen announcement.
      final a11y = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
      if (!a11y) {
        ref.read(soundServiceProvider).play(SoundEffect.complete);
      }
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _confetti.play();
      });
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(sessionControllerProvider);
    final state = async.value;
    final profile = ref.watch(profileProvider).valueOrNull;

    final completed = state?.completed ?? 0;
    final correct = state?.correct ?? 0;
    final again = state?.again ?? 0;
    final accuracyPct =
        completed == 0 ? 0 : ((correct / completed) * 100).round();
    final isPerfect = completed > 0 && again == 0;
    final reviewedCardIds = state?.reviewedCardIds ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SessionMapSummary(reviewedCardIds: reviewedCardIds)
                            .animate()
                            .fade(duration: 380.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              duration: 420.ms,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 20),
                        Text(
                          isPerfect ? 'Flawless!' : 'Nice work',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fade(duration: 380.ms, delay: 1400.ms),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Center(
                                  child: _AccuracyRing(
                                    percent: accuracyPct.toDouble(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _Row(
                                  label: 'Cards reviewed',
                                  value: '$completed',
                                ),
                                const SizedBox(height: 12),
                                _Row(label: 'Correct', value: '$correct'),
                                const SizedBox(height: 12),
                                _Row(label: 'Again', value: '$again'),
                                if (profile != null) ...[
                                  const Divider(height: 28),
                                  _Row(
                                    label: 'Streak',
                                    value:
                                        '${profile.streakDays} day${profile.streakDays == 1 ? "" : "s"}',
                                  ),
                                  const SizedBox(height: 12),
                                  _Row(
                                    label: 'XP',
                                    value: '${profile.xpTotal}',
                                  ),
                                  const SizedBox(height: 12),
                                  _Row(
                                    label: 'Level',
                                    value: '${profile.level}',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fade(duration: 380.ms, delay: 1500.ms)
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              delay: 1500.ms,
                              duration: 380.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(activeSessionDeckIdProvider.notifier).state =
                            null;
                        ref.read(activeSessionCardIdsProvider.notifier).state =
                            null;
                        ref.read(sessionControllerProvider.notifier).reset();
                        ref.invalidate(govMapDataProvider);
                        ref.invalidate(nodeDetailProvider);
                        context.go('/');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Confetti rains down from the top center. Positioned (not Align)
          // so it has explicit bounds and isn't sized by its child's natural
          // size — keeps particles from being clipped to the emitter point.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: math.pi / 2, // down
                maxBlastForce: 18,
                minBlastForce: 6,
                emissionFrequency: 0.04,
                numberOfParticles: isPerfect ? 30 : 15,
                gravity: 0.25,
                colors: const [
                  Color(0xFFC0392B),
                  Color(0xFF1A3A5C),
                  Color(0xFFF1C40F),
                  Color(0xFF27AE60),
                  Color(0xFFE67E22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.percent});
  final double percent; // 0..100

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percent.clamp(0, 100)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(_ringColor(value, theme)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'accuracy',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _ringColor(double v, ThemeData theme) {
    if (v >= 90) return Colors.green.shade400;
    if (v >= 70) return theme.colorScheme.primary;
    if (v >= 50) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
