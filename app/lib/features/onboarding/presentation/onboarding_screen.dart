// lib/features/onboarding/presentation/onboarding_screen.dart
//
// First-launch onboarding: three pages into the "can you pass?" hook.
// Standing rules honored: no signup wall (no account ask anywhere here),
// skippable from every page, supplemental-practice positioning, and it
// marks the old Home overlay tour done so a new user never sits through
// two orientations back to back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../home/presentation/first_run_tour.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const doneFlagKey = 'onboarding.done';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(String route) async {
    final db = ref.read(databaseProvider);
    await db.metaDao.set(OnboardingScreen.doneFlagKey, '1');
    await db.metaDao.set(FirstRunTour.flagKey, '1');
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      const _OnboardPage(
        kicker: 'POLITIFACE',
        title: 'Pass the FCLE with confidence',
        body: 'Practice built on the exam blueprint: all four competencies, '
            'all 32 official objectives. Every question cited to a primary '
            'source, nothing partisan, free to start.',
        icon: Icons.account_balance_outlined,
      ),
      const _OnboardPage(
        kicker: 'FIVE MINUTES A DAY',
        title: 'Learn it once, keep it for good',
        body: 'A short daily round teaches faces, concepts, and vocabulary. '
            'Spaced repetition brings each one back right before you would '
            'forget it. The Atlas holds the full reference, and the Memory '
            'tab shows what you have made stick.',
        icon: Icons.psychology_outlined,
      ),
      const _OnboardPage(
        kicker: 'THE REAL TEST',
        title: 'Could you pass it today?',
        body: 'Take a full-length mock exam, 80 questions in the same four '
            'domains as the real thing, and find out where you stand before '
            'exam day does it for you.',
        icon: Icons.fact_check_outlined,
      ),
    ];

    final onLastPage = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextButton(
                  onPressed: () => _finish('/'),
                  child: const Text('SKIP'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: i == _page ? 22 : 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? theme.colorScheme.brandNavy
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (onLastPage) {
                        _finish('/fcle');
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(
                      onLastPage ? 'SEE IF YOU CAN PASS' : 'NEXT',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (onLastPage) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _finish('/'),
                      child: const Text('EXPLORE ON MY OWN'),
                    ),
                    TextButton(
                      onPressed: () => _finish('/leaderboard'),
                      child: const Text('I HAVE A CLASS CODE'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.kicker,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String kicker;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.brandNavy),
          const SizedBox(height: 24),
          Text(
            kicker,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
