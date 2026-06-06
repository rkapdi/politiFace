import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/editorial_theme.dart';
import '../../trivia/domain/trivia_scoring.dart';
import '../../trivia/presentation/share_card_renderer.dart';
import '../../trivia/presentation/trivia_share_card.dart';
import '../domain/round_state.dart';

/// Reveal phase of the daily round — archetype + score + share, plus a
/// "Chapter day complete" line that distinguishes it from the standalone
/// trivia reveal.
///
/// Shares the share-card pipeline with `trivia_result_screen.dart`:
/// off-screen `OverlayPortal` mount of `TriviaShareCard`, capture via
/// `ShareCardRenderer`, hand the PNG to the iOS share sheet. On any
/// pipeline failure (font race, Skia exception, share-sheet platform
/// error), falls back to copying the Wordle-style text to the clipboard
/// and showing a snackbar — never silent.
class RoundRevealPhase extends ConsumerStatefulWidget {
  const RoundRevealPhase({
    super.key,
    required this.state,
    required this.onDone,
  });

  final DailyRoundState state;
  final VoidCallback onDone;

  @override
  ConsumerState<RoundRevealPhase> createState() => _RoundRevealPhaseState();
}

class _RoundRevealPhaseState extends ConsumerState<RoundRevealPhase> {
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

  String get _todayIso => widget.state.dateIso;

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
        dateLabel: _todayIso,
      );
      final xfile = await renderer.render();
      await Share.shareXFiles(
        [xfile],
        subject: 'Politiface Daily',
        sharePositionOrigin: originRect,
      );
    } on Object catch (e, st) {
      debugPrint('[round-reveal] share failed: $e\n$st');
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!mounted) return;
      final result = widget.state.result;
      if (result != null) {
        await Clipboard.setData(ClipboardData(text: _shareText(result)));
      }
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

  void _onCopy(TriviaResult result) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _shareText(result)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onDone() async {
    HapticFeedback.lightImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.state.result;
    if (result == null) {
      // Defensive — DailyRoundScreen should only route us here once the
      // controller has a result. If somehow not, show a loader.
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final color = _archetypeColor(result.archetype);
    final scoreColor = result.totalScore < 0
        ? EditorialPalette.actionRed
        : (result.totalScore >= 100
            ? EditorialPalette.civicGreen
            : theme.colorScheme.onSurface);

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (overlayContext) {
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChapterCompletionStrip(state: widget.state),
              const Spacer(),
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
                '${result.correctCount}/${result.totalQuestions} correct · '
                'avg confidence ${result.averageConfidence.toStringAsFixed(1)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 820.ms, duration: 360.ms),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  result.gridEmojis.join(' '),
                  style: const TextStyle(fontSize: 26, height: 1.2),
                  textAlign: TextAlign.center,
                ),
              ).animate().fade(delay: 940.ms, duration: 380.ms),
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
                        context.push('/round/review');
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('Review'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _onCopy(result),
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _onDone,
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

/// "Chapter 2 · Day 2 of 3 complete" strip above the archetype reveal —
/// the only visual element that distinguishes a round reveal from the
/// standalone trivia reveal.
class _ChapterCompletionStrip extends StatelessWidget {
  const _ChapterCompletionStrip({required this.state});
  final DailyRoundState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(height: 3, color: EditorialPalette.ochre),
        const SizedBox(height: 10),
        Text(
          'CHAPTER ${state.chapterTitle.toUpperCase()} · '
          'DAY ${state.dayInChapter} OF ${state.daysInChapter} COMPLETE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

String _shareText(TriviaResult r) {
  return 'Politiface Daily — ${r.archetype.emoji} ${r.archetype.name}\n'
      '${r.totalScore > 0 ? '+' : ''}${r.totalScore} / 150\n'
      '${r.gridEmojis.join('')}\n'
      'politiface.app';
}

Color _archetypeColor(TriviaArchetype a) {
  switch (a) {
    case TriviaArchetype.civicScholar:
      return EditorialPalette.civicGreen;
    case TriviaArchetype.luckyGuesser:
      return EditorialPalette.civicNavy;
    case TriviaArchetype.civicBullshitter:
      return EditorialPalette.actionRed;
    case TriviaArchetype.humbleApprentice:
      return EditorialPalette.ochre;
  }
}
