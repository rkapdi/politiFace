import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../government/application/gov_map_data.dart';
import '../../government/application/node_detail_data.dart';
import '../application/session_controller.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
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
    final accuracyPct = completed == 0 ? 0 : ((correct / completed) * 100).round();
    final isPerfect = completed > 0 && again == 0;

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
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 96,
                          color: theme.colorScheme.primary,
                        ).animate().scale(
                              begin: const Offset(0.3, 0.3),
                              end: const Offset(1.0, 1.0),
                              duration: 480.ms,
                              curve: Curves.elasticOut,
                            ),
                        const SizedBox(height: 4),
                        Text(
                          isPerfect ? 'Flawless!' : 'Nice work',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ).animate().fade(duration: 380.ms, delay: 200.ms),
                        const SizedBox(height: 24),
                        Center(
                          child: _AccuracyRing(percent: accuracyPct.toDouble())
                              .animate()
                              .fade(duration: 380.ms, delay: 320.ms)
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1.0, 1.0),
                                delay: 320.ms,
                                duration: 480.ms,
                                curve: Curves.easeOutBack,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _Row(
                                    label: 'Cards reviewed',
                                    value: '$completed'),
                                const SizedBox(height: 12),
                                _Row(label: 'Correct', value: '$correct'),
                                const SizedBox(height: 12),
                                _Row(label: 'Again', value: '$again'),
                                if (profile != null) ...[
                                  const Divider(height: 28),
                                  _Row(
                                      label: 'Streak',
                                      value:
                                          '${profile.streakDays} day${profile.streakDays == 1 ? "" : "s"}'),
                                  const SizedBox(height: 12),
                                  _Row(label: 'XP', value: '${profile.xpTotal}'),
                                  const SizedBox(height: 12),
                                  _Row(label: 'Level', value: '${profile.level}'),
                                ],
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fade(duration: 380.ms, delay: 440.ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              delay: 440.ms,
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
                        ref
                            .read(activeDailyChallengeDateProvider.notifier)
                            .state = null;
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
          // Confetti rains down from the top center.
          Align(
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
      builder: (context, value, _) {
        return SizedBox(
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
                  valueColor:
                      AlwaysStoppedAnimation(_ringColor(value, theme)),
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
        );
      },
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
