import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

/// First-run onboarding. Single screen, single CTA, single archetype hook.
///
/// Replaces the prior 3-page Material-icon walkthrough. Philosophy:
/// the Confidence Score archetype IS the hook — leading with "Are you a
/// Civic Bullshitter?" sets expectations that this isn't a dry civics
/// app, and ties the first impression to the same wedge the share card
/// + trivia reveal lean on. Yellow + black palette is deliberately
/// off-system (high-contrast App Store stopping power, not party-coded)
/// so the onboarding stands apart from the editorial Home theme.
///
/// Design source: `~/.gstack/projects/rkapdi-politiFace/designs/onboarding-20260528/approved.json`.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  // Brand-coherent yellow/black palette for the onboarding only.
  // Intentionally distinct from the editorial Home theme — first
  // impression should feel viral, not magazine.
  static const _yellow = Color(0xFFFFC93A);
  static const _ink = Color(0xFF0A0A0A);

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    await db.metaDao.set('onboarding_v1_done', '1');
    if (!context.mounted) return;
    // Drop the user directly into today's round — the actual game is
    // the best demo of the game. No more "ok let me explain" screens.
    context.go('/round');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: _yellow,
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _yellow,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top-right skip — same idempotent finish as the CTA but
                // routes home instead of /round (in case someone wants
                // to poke around first).
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final db = ref.read(databaseProvider);
                      await db.metaDao.set('onboarding_v1_done', '1');
                      if (!context.mounted) return;
                      context.go('/');
                    },
                    style: TextButton.styleFrom(foregroundColor: _ink),
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // Hero emoji — the archetype that does the most viral work.
                const Text(
                  '💩',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 140, height: 1.0),
                ),
                const SizedBox(height: 32),
                // Headline — the hook. All-caps, tight, two lines.
                Text(
                  'ARE YOU A\nCIVIC BULLSHITTER?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle — sets the stakes (Confidence Score wedge).
                Text(
                  'Find out in 10 questions.\nThe Confidence Score is brutal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink.withOpacity(0.75),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const Spacer(flex: 3),
                // Single CTA — drops the user into the actual round.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _start(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: _yellow,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    child: const Text(
                      'TAKE THE TEST',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Honest footnote — depletes friction by setting
                // expectations: no signup, fast.
                Text(
                  '60 seconds · No signup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
