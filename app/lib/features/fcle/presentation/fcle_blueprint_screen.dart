// lib/features/fcle/presentation/fcle_blueprint_screen.dart
//
// The FCLE "blueprint": what is on the exam (the 32 objectives across the four
// competencies) and where the student stands on each, drawn from their own
// practice history. Positioning rule (see CLAUDE.md): this reports coverage
// and qualitative readiness only. It NEVER shows a predicted score or a single
// "% ready" number, because practice does not predict the real exam.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../application/objective_readiness.dart';
import '../domain/fcle_question.dart';
import '../domain/objective.dart';

class FcleBlueprintScreen extends ConsumerWidget {
  const FcleBlueprintScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final objectives = ref.watch(objectivesProvider).valueOrNull;
    final readiness = ref.watch(objectiveReadinessProvider).valueOrNull;
    final exam = ref.watch(examReadinessProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Blueprint'),
        leading: IconButton(
          tooltip: 'Back to FCLE prep',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/fcle'),
        ),
      ),
      body: (objectives == null || readiness == null || exam == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  "What's on the exam, and where you stand",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'The FCLE draws on 32 objectives across four competencies. '
                  'This shows how much of each you have practiced. It reports '
                  'coverage, not a predicted score.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _VerdictCard(exam: exam, theme: theme),
                const SizedBox(height: 24),
                for (final domain in FcleDomain.values) ...[
                  _CompetencySection(
                    domain: domain,
                    objectives: [
                      for (final o in objectives)
                        if (o.domain == domain) o,
                    ],
                    readiness: readiness,
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }
}

String overallStateWords(ExamOverallState state) {
  switch (state) {
    case ExamOverallState.justStarting:
      return 'Just starting. Answer a few questions to map where you stand.';
    case ExamOverallState.buildingCoverage:
      return 'Building coverage. You have touched some objectives; keep '
          'widening across the four competencies.';
    case ExamOverallState.mostAreasCovered:
      return 'Most areas covered. You have practiced across the exam; firm up '
          'the objectives still marked needs work.';
    case ExamOverallState.strongAcrossTheBoard:
      return 'Strong across the board. Every competency has objectives you are '
          'solid on. Keep them warm.';
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.exam, required this.theme});

  final ExamReadiness exam;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final focus = exam.focusNext;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${exam.covered} of ${exam.total} objectives practiced',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            overallStateWords(exam.overallState),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                label: 'Solid',
                count: exam.solid,
                color: theme.colorScheme.brandGreen,
                theme: theme,
              ),
              _CountChip(
                label: 'Needs work',
                count: exam.needsWork,
                color: theme.colorScheme.brandRed,
                theme: theme,
              ),
              _CountChip(
                label: 'Not yet seen',
                count: exam.unseen,
                color: theme.colorScheme.onSurfaceVariant,
                theme: theme,
              ),
            ],
          ),
          if (focus != null) ...[
            const SizedBox(height: 14),
            _FocusNextCta(focus: focus, theme: theme),
          ],
        ],
      ),
    );
  }
}

class _FocusNextCta extends StatelessWidget {
  const _FocusNextCta({required this.focus, required this.theme});

  final FocusNext focus;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final obj = focus.objective;
    final title = obj != null ? obj.code : focus.domain.label;
    final subtitle = obj != null
        ? obj.description
        : 'The competency with the most objectives you have not touched yet.';
    final target = obj != null
        ? '/fcle/practice?domain=${focus.domain.code}&objective=${obj.code}'
        : '/fcle/practice?domain=${focus.domain.code}';

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(target);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.brandNavy, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.my_location,
                size: 20, color: theme.colorScheme.brandNavy,),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus next: $title',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PRACTICE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.theme,
  });

  final String label;
  final int count;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CompetencySection extends StatelessWidget {
  const _CompetencySection({
    required this.domain,
    required this.objectives,
    required this.readiness,
  });

  final FcleDomain domain;
  final List<Objective> objectives;
  final Map<String, ObjectiveReadiness> readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          domain.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final o in objectives) ...[
          _ObjectiveRow(
            objective: o,
            readiness: readiness[o.code],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.objective, required this.readiness});

  final Objective objective;
  final ObjectiveReadiness? readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = readiness?.state ?? ReadinessState.unseen;
    final count = readiness?.count ?? 0;
    final accuracy = readiness?.accuracy;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(
          '/fcle/practice?domain=${objective.domain.code}'
          '&objective=${objective.code}',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    objective.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
                const SizedBox(width: 10),
                _StatePill(state: state, theme: theme),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  objective.code,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (count > 0) ...[
                  Text(
                    accuracy == null
                        ? ''
                        : 'Recent practice accuracy '
                            '${(accuracy * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$count attempt${count == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Text(
                    'Not practiced yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String readinessLabel(ReadinessState state) {
  switch (state) {
    case ReadinessState.unseen:
      return 'Not seen';
    case ReadinessState.practicing:
      return 'Practicing';
    case ReadinessState.needsWork:
      return 'Needs work';
    case ReadinessState.onTrack:
      return 'On track';
    case ReadinessState.solid:
      return 'Solid';
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, required this.theme});

  final ReadinessState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (state) {
      case ReadinessState.solid:
        color = theme.colorScheme.brandGreen;
      case ReadinessState.onTrack:
        color = theme.colorScheme.brandNavy;
      case ReadinessState.needsWork:
        color = theme.colorScheme.brandRed;
      case ReadinessState.practicing:
        color = theme.colorScheme.brandOchreText;
      case ReadinessState.unseen:
        color = theme.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        readinessLabel(state).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontSize: 10,
        ),
      ),
    );
  }
}
