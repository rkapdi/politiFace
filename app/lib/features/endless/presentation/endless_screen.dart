import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../application/endless_controller.dart';
import '../domain/endless_question.dart';

class EndlessScreen extends ConsumerWidget {
  const EndlessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(endlessControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Endless'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Endless failed to start',
          message: '$e',
          onRetry: () => ref.invalidate(endlessControllerProvider),
        ),
        data: (s) {
          if (s.question == null) {
            return AppEmptyView(
              icon: Icons.layers_outlined,
              title: 'Not enough cards yet',
              body:
                  'Endless needs at least 4 cards in the pool. Add more content '
                  'or sit tight — V1.1 will have a lot more.',
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Home'),
              ),
            );
          }
          return _EndlessView(state: s);
        },
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
                await ref
                    .read(endlessControllerProvider.notifier)
                    .answer(idx);
                final correct = idx == q.correctIndex;
                if (correct) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.heavyImpact();
                }
                await Future<void>.delayed(const Duration(milliseconds: 700));
                await ref
                    .read(endlessControllerProvider.notifier)
                    .advance();
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
        body = CardAvatar(
          name: question.correct.politicianName,
          radius: 80,
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
        body = CardAvatar(
          name: question.correct.politicianName,
          radius: 80,
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
    )
        .animate(key: ValueKey(question.correct.id))
        .fade(duration: 180.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1.0, 1.0),
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
    final isPhotoGrid = mode == QuestionMode.nameToPhoto ||
        mode == QuestionMode.titleToWho;
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
                  child: CardAvatar(
                    name: card.politicianName,
                    radius: 38,
                    photoUrl: card.photoUrl,
                  ),
                ),
              ),
              if (answered && isCorrect) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle,
                    color: Colors.green.shade400, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
