import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../trivia/presentation/share_card_renderer.dart';
import '../application/endless_controller.dart';
import 'endless_share_card.dart';

/// Post-run summary for an ended Endless session. Mirrors the structure of
/// [TriviaResultScreen]: hero stats, share button, review CTA, dismiss.
class EndlessResultScreen extends ConsumerStatefulWidget {
  const EndlessResultScreen({super.key});

  @override
  ConsumerState<EndlessResultScreen> createState() =>
      _EndlessResultScreenState();
}

class _EndlessResultScreenState extends ConsumerState<EndlessResultScreen> {
  final _portalController = OverlayPortalController();
  final _boundaryKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portalController.show();
    });
  }

  String get _todayLabel {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  Rect? _shareOriginRect() {
    final ctx = _shareButtonKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _onShare() async {
    if (_isSharing) return;
    HapticFeedback.lightImpact();
    final originRect = _shareOriginRect();
    setState(() => _isSharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderer = ShareCardRenderer(
        boundaryKey: _boundaryKey,
        dateLabel: 'endless-${DateTime.now().millisecondsSinceEpoch}',
      );
      final xfile = await renderer.render();
      await Share.shareXFiles(
        [xfile],
        subject: 'Politiface Endless',
        sharePositionOrigin: originRect,
      );
    } on Object catch (e, st) {
      debugPrint('[endless-share] render failed: $e\n$st');
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image share unavailable.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(endlessControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Complete'),
        automaticallyImplyLeading: false,
      ),
      body: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) {
          final s = state;
          return Positioned(
            left: -10000,
            top: -10000,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox(
                width: EndlessShareCard.canvasWidth,
                height: EndlessShareCard.canvasHeight,
                child: MediaQuery(
                  data: const MediaQueryData(),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: EndlessShareCard(
                      currentStreak: s?.currentStreak ?? 0,
                      bestStreak: s?.bestStreak ?? 0,
                      totalCorrect: s?.totalCorrect ?? 0,
                      totalAnswered: s?.totalAnswered ?? 0,
                      dateLabel: _todayLabel,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  'BEST STREAK',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${state?.bestStreak ?? 0}',
                    style: const TextStyle(
                      fontSize: 130,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE67E22),
                      height: 1.0,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ).animate().scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                        duration: 460.ms,
                        curve: Curves.elasticOut,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  state == null
                      ? ''
                      : '${state.totalCorrect}/${state.totalAnswered} correct',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ).animate().fade(delay: 360.ms, duration: 320.ms),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: _shareButtonKey,
                    onPressed: _isSharing ? null : _onShare,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(_isSharing ? 'Preparing…' : 'Share'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/endless/review');
                        },
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: const Text('View Run'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // Reset the controller so the next Endless launch
                          // starts fresh — otherwise the user would re-enter
                          // an ended run.
                          ref
                              .read(endlessControllerProvider.notifier)
                              .reset();
                          context.go('/');
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
