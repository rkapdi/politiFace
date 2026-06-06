import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../application/trivia_controller.dart';
import '../domain/trivia_scoring.dart';
import 'share_card_renderer.dart';
import 'trivia_share_card.dart';

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

class _ResultBody extends ConsumerStatefulWidget {
  const _ResultBody({required this.result});
  final TriviaResult result;

  @override
  ConsumerState<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends ConsumerState<_ResultBody> {
  final _portalController = OverlayPortalController();
  final _boundaryKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _isSharing = false;

  /// iOS share sheet needs a `sharePositionOrigin` rect to anchor the
  /// popover (mandatory on iPad, increasingly enforced on iPhone too).
  /// Read the Share button's screen-space rect right before invoking
  /// `shareXFiles` — must happen synchronously to avoid the button
  /// rebuilding (`onPressed: null`) and losing its render object.
  Rect? _shareOriginRect() {
    final ctx = _shareButtonKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void initState() {
    super.initState();
    // Mount the off-screen share-card boundary immediately so it's ready
    // whenever the user taps Share. Show happens in the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portalController.show();
    });
  }

  String get _todayIso {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _onShare() async {
    if (_isSharing) return;
    HapticFeedback.lightImpact();
    // Capture the share-button rect BEFORE we disable the button, so the
    // render object is still attached when we read it.
    final originRect = _shareOriginRect();
    setState(() => _isSharing = true);
    try {
      // Wait for the disabled-button rebuild + ensure the off-screen
      // boundary has had a frame to lay out.
      await WidgetsBinding.instance.endOfFrame;
      final renderer = ShareCardRenderer(
        boundaryKey: _boundaryKey,
        dateLabel: _todayIso,
      );
      final xfile = await renderer.render();
      await Share.shareXFiles(
        [xfile],
        subject: 'Politiface Daily',
        sharePositionOrigin: originRect,
      );
    } on Object catch (e, st) {
      // The cardinal sin would be silent failure — the user must always end
      // a Share tap with *something*. Fall back to text-copy + snackbar.
      // Sentry captures the underlying exception as non-fatal so we learn
      // which failure modes hit production.
      debugPrint('[share-card] render failed: $e\n$st');
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!mounted) return;
      await Clipboard.setData(
        ClipboardData(text: _shareText(widget.result)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image share unavailable — copied as text instead'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _onCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _shareText(widget.result)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final color = _archetypeColor(result.archetype);
    final scoreColor = result.totalScore < 0
        ? Colors.red.shade400
        : (result.totalScore >= 100
            ? Colors.green.shade400
            : theme.colorScheme.onSurface);

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (overlayContext) {
        // Mount the share-card off-screen so RenderRepaintBoundary has real
        // layout dimensions (Offstage doesn't reliably propagate
        // constraints), but the user never sees it.
        return Positioned(
          left: -10000,
          top: -10000,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: TriviaShareCard.canvasWidth,
              height: TriviaShareCard.canvasHeight,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TriviaShareCard(
                    result: result,
                    dateLabel: formatShareCardDate(_todayIso),
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
              // The emoji grid — share-block preview. Also rendered inline
              // in the share text by _shareText().
              Center(
                child: Text(
                  result.gridEmojis.join(' '),
                  style: const TextStyle(fontSize: 26, height: 1.2),
                  textAlign: TextAlign.center,
                ),
              ).animate().fade(delay: 940.ms, duration: 380.ms),
              const Spacer(),
              // Primary CTA — Share image. Disabled while rendering so a
              // double-tap can't queue two captures. Key is used by
              // `_shareOriginRect` to anchor the iOS share popover.
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
              // Secondary row: review the run, copy plain text (kept for
              // iMessage/X), and dismiss.
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/trivia/review');
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('Review'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _onCopy,
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        // No reset() here — invalidating the provider would
                        // rebuild state with isComplete=false, which would
                        // race the navigation home and dump the user back
                        // into a fresh trivia run. The completed state
                        // stays in memory until the controller naturally
                        // rebuilds on next cold launch (or, eventually, a
                        // date check we add in v2).
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
    );
  }
}

/// Wordle-style text payload for iMessage / X — emoji grid, archetype,
/// score, app pointer. Also the fallback payload when the PNG render
/// pipeline fails.
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

