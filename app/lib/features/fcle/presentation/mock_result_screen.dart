// lib/features/fcle/presentation/mock_result_screen.dart
//
// Mock FCLE results: score against the 60% bar, per-domain breakdown,
// the score-challenge share ("beat my score"), and a straight line into
// weak-area practice. A mock is practice, not a prediction; the copy
// says so (FLDOE positioning rule).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/editorial_theme.dart';
import '../../trivia/presentation/share_card_renderer.dart';
import '../domain/mock_engine.dart';
import 'fcle_share_card.dart';

class MockResultScreen extends ConsumerStatefulWidget {
  const MockResultScreen({required this.result, super.key});

  final MockResult result;

  @override
  ConsumerState<MockResultScreen> createState() => _MockResultScreenState();
}

class _MockResultScreenState extends ConsumerState<MockResultScreen> {
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
        dateLabel: 'mock-fcle-${DateTime.now().millisecondsSinceEpoch}',
      );
      final xfile = await renderer.render();
      await Share.shareXFiles(
        [xfile],
        subject: 'Mock FCLE',
        sharePositionOrigin: originRect,
      );
    } on Object catch (e, st) {
      debugPrint('[fcle-share] render failed: $e\n$st');
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
    final theme = Theme.of(context);
    final result = widget.result;
    final green = theme.colorScheme.brandGreen;
    final red = theme.colorScheme.brandRed;
    final passColor = result.passed ? green : red;
    final passLine = (result.total * MockEngine.passFraction).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock results'),
        automaticallyImplyLeading: false,
      ),
      body: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) => Positioned(
          left: -10000,
          top: -10000,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: FcleShareCard.canvasWidth,
              height: FcleShareCard.canvasHeight,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: FcleShareCard(
                    result: result,
                    dateLabel: _todayLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: passColor.withOpacity(0.10),
                border: Border.all(color: passColor.withOpacity(0.55)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    '${result.score} / ${result.total}',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.passed
                        ? 'Above the passing bar of $passLine.'
                        : 'The passing bar is $passLine. Keep practicing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: passColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A mock is practice, not a prediction of your official result.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (result.pendingSync) ...[
              const SizedBox(height: 4),
              Text(
                'Scored offline. Your attempt syncs on the next connection.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'BY DOMAIN',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in result.perDomain.entries) ...[
              _DomainBar(
                label: entry.key.label,
                score: entry.value,
                passFraction: MockEngine.passFraction,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              key: _shareButtonKey,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              onPressed: _isSharing ? null : _onShare,
              icon: _isSharing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: const Text(
                'CHALLENGE A FRIEND',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              onPressed: () => context.pushReplacement(
                '/fcle/practice?domain=${result.weakestDomain.code}',
              ),
              child: Text(
                'PRACTICE ${result.weakestDomain.label.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              onPressed: () => context.go('/fcle'),
              child: const Text(
                'BACK TO FCLE PREP',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({
    required this.label,
    required this.score,
    required this.passFraction,
  });

  final String label;
  final DomainScore score;
  final double passFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = score.total == 0 ? 0.0 : score.correct / score.total;
    final color = fraction >= passFraction
        ? theme.colorScheme.brandGreen
        : theme.colorScheme.brandRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${score.correct}/${score.total}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}
