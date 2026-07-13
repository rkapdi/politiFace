import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/photo_zoom_modal.dart';
import '../../shared/widgets/state_views.dart';
import '../../trivia/presentation/share_card_renderer.dart';
import '../application/endless_controller.dart';
import '../domain/endless_question.dart';
import 'endless_share_card.dart';

class EndlessScreen extends ConsumerStatefulWidget {
  const EndlessScreen({super.key});

  @override
  ConsumerState<EndlessScreen> createState() => _EndlessScreenState();
}

class _EndlessScreenState extends ConsumerState<EndlessScreen> {
  final _portalController = OverlayPortalController();
  final _boundaryKey = GlobalKey();
  final _shareIconKey = GlobalKey();
  bool _isSharing = false;
  bool _routingToResult = false;

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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  Rect? _shareOriginRect() {
    final ctx = _shareIconKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() async {
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
      final s = ref.read(endlessControllerProvider).valueOrNull;
      final text =
          'Politiface Endless — streak ${s?.bestStreak ?? 0} (${s?.totalCorrect ?? 0}/${s?.totalAnswered ?? 0} correct)\npolitiface.app';
      await Clipboard.setData(ClipboardData(text: text));
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

  Future<void> _endRun() async {
    HapticFeedback.mediumImpact();
    await ref.read(endlessControllerProvider.notifier).endRun();
    if (!mounted) return;
    setState(() => _routingToResult = true);
    context.push('/endless/result');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(endlessControllerProvider);
    final state = async.valueOrNull;
    final canEnd = state != null && state.totalAnswered > 0 && !state.runEnded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Endless'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (canEnd)
            IconButton(
              key: _shareIconKey,
              tooltip: 'Share streak',
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              onPressed: _isSharing ? null : _share,
            ),
          if (canEnd)
            TextButton(
              onPressed: _routingToResult ? null : _endRun,
              child: const Text(
                'END RUN',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) {
          // Off-screen share-card RepaintBoundary. The OverlayPortal mounts
          // it outside the visible viewport but with real layout
          // dimensions, so ShareCardRenderer can call toImage successfully.
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
        child: async.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorView(
            title: 'Endless failed to start',
            message: '$e',
            onRetry: () => ref.invalidate(endlessControllerProvider),
          ),
          data: (s) {
            if (s.question == null) {
              if (s.runEnded) {
                return const AppLoadingView(label: 'Wrapping up run…');
              }
              return AppEmptyView(
                icon: Icons.layers_outlined,
                title: 'Not enough cards yet',
                body: 'Endless needs at least 4 cards in the pool. Add more '
                    'content or sit tight — V1.1 will have a lot more.',
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Home'),
                ),
              );
            }
            return _EndlessView(state: s);
          },
        ),
      ),
    );
  }
}

class _EndlessView extends ConsumerWidget {
  const _EndlessView({required this.state});
  final EndlessState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final q = state.question!;
    final answered = state.lastWasCorrect != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            _ScoreBar(state: state),
            const SizedBox(height: 20),
            Expanded(child: _Prompt(question: q)),
            const SizedBox(height: 16),
            _Options(
              question: q,
              answered: answered,
              onTap: (idx) async {
                if (answered) return;
                HapticFeedback.lightImpact();
                await ref.read(endlessControllerProvider.notifier).answer(idx);
                final correct = idx == q.correctIndex;
                if (correct) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.heavyImpact();
                }
                ref.read(soundServiceProvider).play(
                      correct ? SoundEffect.correct : SoundEffect.incorrect,
                    );
                await Future<void>.delayed(const Duration(milliseconds: 700));
                await ref.read(endlessControllerProvider.notifier).advance();
              },
            ),
            const SizedBox(height: 8),
            if (state.lastWasCorrect == false)
              Text(
                'Correct: ${q.correct.politicianName} — ${q.correct.title}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.state});
  final EndlessState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _Chip(
          icon: Icons.bolt,
          label: 'Streak',
          value: '${state.currentStreak}',
          accent: state.currentStreak > 0
              ? const Color(0xFFE67E22)
              : theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.workspace_premium_outlined,
          label: 'Best',
          value: '${state.bestStreak}',
          accent: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.check_circle_outline,
          label: 'Correct',
          value: '${state.totalCorrect}/${state.totalAnswered}',
          accent: Colors.green.shade400,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.question});
  final EndlessQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    String label;
    switch (question.mode) {
      case QuestionMode.photoToName:
        label = 'Who is this?';
        body = _ZoomablePromptAvatar(
          heroTag: 'endless-prompt-${question.correct.id}',
          name: '', // empty caption: zooming must not reveal the answer
          photoUrl: question.correct.photoUrl,
        );
      case QuestionMode.nameToPhoto:
        label = 'Pick the face';
        body = _PromptText(question.correct.politicianName);
      case QuestionMode.titleToWho:
        label = 'Who holds this role?';
        body = _PromptText(question.correct.title);
      case QuestionMode.photoToTitle:
        label = 'What is their role?';
        body = _ZoomablePromptAvatar(
          heroTag: 'endless-prompt-${question.correct.id}',
          name: '', // empty caption: zooming must not reveal the answer
          photoUrl: question.correct.photoUrl,
        );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        body,
      ],
    ).animate(key: ValueKey(question.correct.id)).fade(duration: 180.ms).scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 180.ms,
        );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.question,
    required this.answered,
    required this.onTap,
  });

  final EndlessQuestion question;
  final bool answered;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final mode = question.mode;
    // For photo-output formats, render a 2×2 grid of avatars; otherwise a
    // vertical stack of text buttons.
    final isPhotoGrid =
        mode == QuestionMode.nameToPhoto || mode == QuestionMode.titleToWho;
    if (isPhotoGrid) {
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < question.options.length; i++)
            _PhotoOption(
              card: question.options[i],
              isCorrect: i == question.correctIndex,
              answered: answered,
              onTap: () => onTap(i),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TextOption(
              text: mode == QuestionMode.photoToTitle
                  ? question.options[i].title
                  : question.options[i].politicianName,
              isCorrect: i == question.correctIndex,
              answered: answered,
              onTap: () => onTap(i),
            ),
          ),
      ],
    );
  }
}

class _TextOption extends StatelessWidget {
  const _TextOption({
    required this.text,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final String text;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = !answered
        ? theme.colorScheme.surfaceContainer
        : isCorrect
            ? Colors.green.shade400.withOpacity(0.25)
            : theme.colorScheme.surfaceContainer;
    final borderColor = !answered
        ? theme.colorScheme.outlineVariant
        : isCorrect
            ? Colors.green.shade400
            : theme.colorScheme.outlineVariant.withOpacity(0.4);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (answered && isCorrect)
                Icon(Icons.check_circle, color: Colors.green.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.card,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final LocalCard card;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = !answered
        ? theme.colorScheme.outlineVariant
        : isCorrect
            ? Colors.green.shade400
            : theme.colorScheme.outlineVariant.withOpacity(0.4);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: ResponsiveCardAvatar(
                    name: card.politicianName,
                    photoUrl: card.photoUrl,
                    factor: 0.42,
                    minRadius: 38,
                    maxRadius: 72,
                  ),
                ),
              ),
              if (answered && isCorrect) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade400,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prompt-sized avatar in Endless mode. Scales to the device and opens a
/// full-screen Hero-animated zoom when tapped.
class _ZoomablePromptAvatar extends StatelessWidget {
  const _ZoomablePromptAvatar({
    required this.heroTag,
    required this.name,
    required this.photoUrl,
  });

  final String heroTag;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          PhotoZoomModal.show(
            context,
            heroTag: heroTag,
            name: name,
            photoUrl: photoUrl,
          );
        },
        child: Hero(
          tag: heroTag,
          child: ResponsiveCardAvatar(
            name: name,
            photoUrl: photoUrl,
            minRadius: 80,
          ),
        ),
      );
}
