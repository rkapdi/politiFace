import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';

/// One-time, three-step orientation shown over the first Home view.
/// Skippable; never shown again once dismissed (flag in app_meta).
/// Deliberately not anchored to widgets — three short panels that
/// explain the three places the app lives: the daily round, the Atlas,
/// and the Memory tab.
class FirstRunTour {
  static const flagKey = 'onboarding.tour_done';
  static bool _checkedThisLaunch = false;

  /// Call once from Home's first frame. Reads the flag, shows the tour for
  /// brand-new installs, and writes the flag when dismissed.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;
    final db = ref.read(databaseProvider);
    if (await db.metaDao.get(flagKey) == '1') return;
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      pageBuilder: (ctx, _, __) => const _TourDialog(),
    );
    await db.metaDao.set(flagKey, '1');
  }
}

class _TourDialog extends StatefulWidget {
  const _TourDialog();

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  int _step = 0;

  static const _steps = [
    (
      icon: Icons.menu_book_outlined,
      title: 'One round a day',
      body: 'Each day teaches a few short lessons, then drills them as '
          'cards and trivia. Your progress through the season lives on '
          'this Home tab.',
    ),
    (
      icon: Icons.account_balance_outlined,
      title: 'The Atlas',
      body: 'Every politician in the app, browsable by branch. Tap anyone '
          'for their role and a short bio.',
    ),
    (
      icon: Icons.auto_awesome_outlined,
      title: 'Your Memory',
      body: 'Watch faces and concepts crystallize into long-term memory. '
          'The app schedules reviews right before you would forget.',
    ),
  ];

  bool get _last => _step == _steps.length - 1;

  void _advance() {
    HapticFeedback.lightImpact();
    if (_last) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text-safe ochre: the plain accent misses the 3:1
                  // non-text minimum on light surfaces.
                  Icon(
                    step.icon,
                    size: 40,
                    color: theme.colorScheme.brandOchreText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _steps.length; i++) ...[
                        Container(
                          width: i == _step ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? EditorialPalette.ochre
                                : theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        if (i != _steps.length - 1) const SizedBox(width: 5),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _advance,
                    child: Text(_last ? 'START LEARNING' : 'NEXT'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
