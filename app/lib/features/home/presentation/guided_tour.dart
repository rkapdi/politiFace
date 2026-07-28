// lib/features/home/presentation/guided_tour.dart
//
// The guided tour: spotlight coach marks over the REAL Home screen, not
// a slideshow. Runs once after the diagnostic lands a new user on Home
// (value first, orientation second), and any time from Settings > "Show
// me around". Each step dims the screen with a hard-edged cutout around
// the actual widget it explains. Skippable at every step; finishing or
// skipping writes the flag.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../shared/widgets/neo/neo_kit.dart';

/// Settings flips this to true and navigates home; Home listens and
/// starts the tour on its next frame.
final tourRequestProvider = StateProvider<bool>((ref) => false);

class GuidedTour {
  /// Kept from the previous orientation so already-toured installs are
  /// not re-toured on upgrade.
  static const flagKey = 'onboarding.tour_done';
  static bool _checkedThisLaunch = false;
  static bool _running = false;

  // Spotlight anchors, attached by Home via KeyedSubtree.
  static final readinessKey = GlobalKey(debugLabel: 'tour-readiness');
  static final buttonKey = GlobalKey(debugLabel: 'tour-button');
  static final verbsKey = GlobalKey(debugLabel: 'tour-verbs');

  /// First-frame check: shows the tour for installs that have never seen
  /// it. Call from Home's post-frame callback.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (_checkedThisLaunch || _running) return;
    _checkedThisLaunch = true;
    final db = ref.read(databaseProvider);
    if (await db.metaDao.get(flagKey) == '1') return;
    if (!context.mounted) return;
    await start(context, ref);
  }

  /// Runs the tour now (Settings replay path resets nothing; the flag is
  /// simply rewritten on completion).
  static Future<void> start(BuildContext context, WidgetRef ref) async {
    if (_running) return;
    _running = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, _, __) => const _TourOverlay(),
      );
      await ref.read(databaseProvider).metaDao.set(flagKey, '1');
    } finally {
      _running = false;
    }
  }
}

class _TourStep {
  const _TourStep({
    required this.kicker,
    required this.title,
    required this.body,
    this.targetKey,
  });

  final String kicker;
  final String title;
  final String body;

  /// Null = no spotlight; the card centers itself (used for the tabs
  /// step, whose targets live in the shell scaffold).
  final GlobalKey? targetKey;
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay();

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _step = 0;
  Rect? _target;

  static final _steps = <_TourStep>[
    _TourStep(
      kicker: 'YOUR READINESS',
      title: 'This band is the whole game',
      body: 'It projects your FCLE score from everything you answer, '
          'anywhere in the app. The goal: get the band past the pass '
          'line of 48 before your exam date.',
      targetKey: GuidedTour.readinessKey,
    ),
    _TourStep(
      kicker: 'THE ONE BUTTON',
      title: 'When in doubt, press the yellow',
      body: 'It always holds your highest-impact next step: cards about '
          'to fade, your weakest exam domain, or today’s round. '
          'One tap, no decisions.',
      targetKey: GuidedTour.buttonKey,
    ),
    _TourStep(
      kicker: 'FOUR DOORS',
      title: 'Pick a door when you have a mood',
      body: 'Study keeps what you know fresh. Drill moves your exam '
          'score. Play is the arcade, zero stakes, never burns your '
          'streak. Pulse is what Washington did this week.',
      targetKey: GuidedTour.verbsKey,
    ),
    const _TourStep(
      kicker: 'TWO MORE TABS',
      title: 'Atlas looks up, Memory looks in',
      body: 'Atlas (bottom bar) is the reference: every politician, '
          'executive order, and law, all cited. Memory shows what has '
          'stuck and what is fading. Replay this tour any time from '
          'Settings.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _measure() async {
    final key = _steps[_step].targetKey;
    if (key?.currentContext == null) {
      setState(() => _target = null);
      return;
    }
    // Bring the anchor on screen first, then measure it.
    await Scrollable.ensureVisible(
      key!.currentContext!,
      alignment: 0.35,
      duration: const Duration(milliseconds: 200),
    );
    if (!mounted) return;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      setState(() => _target = null);
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    setState(
      () => _target = (origin & box.size).inflate(6),
    );
  }

  void _advance() {
    HapticFeedback.lightImpact();
    if (_step + 1 >= _steps.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step++;
      _target = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];
    final screen = MediaQuery.of(context).size;
    // Card sits under the spotlight when the target is in the top half,
    // above it otherwise; centered when there is no target.
    final targetInTopHalf =
        _target == null || _target!.center.dy < screen.height / 2;

    return Stack(
      children: [
        // Hard-edged scrim with a cutout over the explained widget.
        Positioned.fill(
          child: CustomPaint(
            painter: _SpotlightPainter(
              target: _target,
              scrim: Colors.black.withOpacity(0.78),
              borderColor: EditorialPalette.signal,
            ),
          ),
        ),
        SafeArea(
          child: Column(
            mainAxisAlignment: _target == null
                ? MainAxisAlignment.center
                : targetInTopHalf
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
            children: [
              if (_target != null && !targetInTopHalf)
                const SizedBox(height: 60),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  _target != null && targetInTopHalf
                      ? (screen.height - _target!.bottom)
                              .clamp(0, screen.height * 0.55)
                              .toDouble() -
                          40
                      : 24,
                ),
                child: _CoachCard(
                  step: step,
                  index: _step,
                  total: _steps.length,
                  onNext: _advance,
                  onSkip: () => Navigator.of(context).pop(),
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    required this.theme,
  });

  final _TourStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final last = index == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: neoCardBg(context),
        border: Border.all(color: neoLine(context), width: 4),
        boxShadow: [neoShadow(context)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${step.kicker} · ${index + 1} OF $total',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              InkWell(
                onTap: onSkip,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    'SKIP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(step.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Step dots: square, like everything else here.
              for (var i = 0; i < total; i++) ...[
                Container(
                  width: i == index ? 14 : 6,
                  height: 6,
                  color: i == index
                      ? EditorialPalette.signal
                      : neoLineDim(context),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              InkWell(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: EditorialPalette.signal,
                    border: Border.all(width: 2),
                  ),
                  child: Text(
                    last ? 'GOT IT' : 'NEXT →',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: EditorialPalette.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.target,
    required this.scrim,
    required this.borderColor,
  });

  final Rect? target;
  final Color scrim;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    if (target == null) {
      canvas.drawRect(full, Paint()..color = scrim);
      return;
    }
    final cutout = Path()
      ..addRect(full)
      ..addRect(target!)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(cutout, Paint()..color = scrim);
    // Hard signal frame around the spotlighted widget.
    canvas.drawRect(
      target!,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.scrim != scrim;
}
