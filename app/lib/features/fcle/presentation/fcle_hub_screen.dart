// lib/features/fcle/presentation/fcle_hub_screen.dart
//
// FCLE prep hub: per-domain readiness, Mock FCLE entry, weak-area practice.
// Positioning rule (see CLAUDE.md): supplemental practice students choose,
// never "official prep"; mocks are practice, not predictors.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../application/fcle_providers.dart';
import '../data/question_bank_loader.dart';
import '../domain/fcle_question.dart';

class FcleHubScreen extends ConsumerWidget {
  const FcleHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bank = ref.watch(questionBankProvider).valueOrNull;
    final readiness = ref.watch(readinessProvider).valueOrNull;
    final weakest = ref.watch(weakestDomainProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FCLE Prep'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: bank == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Florida Civic Literacy Exam',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '80 questions, four domains, 60% to pass. This is '
                  'supplemental practice you choose; it is not the official '
                  'exam and does not predict your score.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _BlueprintEntryTile(theme: theme),
                const SizedBox(height: 24),
                _SectionLabel(text: 'READINESS BY DOMAIN', theme: theme),
                const SizedBox(height: 12),
                for (final d in FcleDomain.values) ...[
                  _ReadinessRow(
                    domain: d,
                    readiness: readiness?[d],
                    questionCount: bank.countFor(d),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                _SectionLabel(text: 'MOCK EXAM', theme: theme),
                const SizedBox(height: 12),
                if (bank.canAssembleMock)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text(
                      'START MOCK FCLE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/fcle/mock');
                    },
                  )
                else
                  _BankGrowingCard(bank: bank, theme: theme),
                const SizedBox(height: 24),
                _SectionLabel(text: 'PRACTICE', theme: theme),
                const SizedBox(height: 12),
                if (weakest != null && bank.countFor(weakest) > 0)
                  _PracticeTile(
                    title: 'Weakest area: ${weakest.label}',
                    subtitle: 'Ten questions where you miss the most.',
                    icon: Icons.trending_up,
                    onTap: () =>
                        context.push('/fcle/practice?domain=${weakest.code}'),
                  ),
                for (final d in FcleDomain.values)
                  if (bank.countFor(d) > 0)
                    _PracticeTile(
                      title: d.label,
                      subtitle:
                          '${bank.countFor(d)} question${bank.countFor(d) == 1 ? '' : 's'} available',
                      icon: Icons.quiz_outlined,
                      onTap: () =>
                          context.push('/fcle/practice?domain=${d.code}'),
                    ),
                if (bank.all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'The question bank is in editorial review. Practice '
                      'opens as soon as the first reviewed questions are '
                      'published.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _BlueprintEntryTile extends StatelessWidget {
  const _BlueprintEntryTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/fcle/blueprint');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.brandNavy, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            color: theme.colorScheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              Icon(Icons.map_outlined,
                  size: 22, color: theme.colorScheme.brandNavy,),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's on the exam, and where you stand",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All 32 objectives across the four competencies, with '
                      'your coverage on each.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.domain,
    required this.readiness,
    required this.questionCount,
  });

  final FcleDomain domain;
  final DomainReadiness? readiness;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = readiness?.accuracy;
    final green = theme.colorScheme.brandGreen;
    final color = accuracy == null
        ? theme.colorScheme.outlineVariant
        : accuracy >= 0.6
            ? green
            : theme.colorScheme.brandRed;
    // One semantic node per domain: "American Democracy, readiness 75%".
    return MergeSemantics(
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
              children: [
                Expanded(
                  child: Text(
                    domain.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  accuracy == null
                      ? 'No data yet'
                      : '${(accuracy * 100).round()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accuracy == null
                        ? theme.colorScheme.onSurfaceVariant
                        : color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: accuracy ?? 0,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankGrowingCard extends StatelessWidget {
  const _BankGrowingCard({required this.bank, required this.theme});

  final QuestionBank bank;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top,
                color: theme.colorScheme.onSurfaceVariant, size: 18,),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'The full 80-question mock unlocks as the question bank '
                'grows: ${bank.mockBankProgress} of 80 ready.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
