import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../curriculum/domain/curriculum.dart';
import '../data/atlas_data_provider.dart';
import '../data/branch_info_loader.dart';

/// Library-style detail sheet for a branch. Opens when the user taps the
/// branch header in the Atlas. Read-only, scannable, links into the
/// chapters of the round where the branch shows up.
class BranchInfoSheet extends ConsumerWidget {
  const BranchInfoSheet({
    required this.branch, super.key,
    this.scrollController,
  });

  final AtlasBranch branch;
  final ScrollController? scrollController;

  static Future<void> show(BuildContext context, AtlasBranch branch) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => BranchInfoSheet(
            branch: branch,
            scrollController: controller,
          ),
        ),
    );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final infoAsync = ref.watch(branchInfoLibraryProvider);
    final curriculumAsync = ref.watch(curriculumProvider);

    final info = infoAsync.valueOrNull?.forId(branch.id);
    final curriculum = curriculumAsync.valueOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle.
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Branch color strip — same accent the card uses.
        Container(
          height: 4,
          color: branch.color,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: info == null
                ? _Loading(branch: branch)
                : _Body(
                    branch: branch,
                    info: info,
                    curriculum: curriculum,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.branch});
  final AtlasBranch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            branch.title.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(strokeWidth: 2),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.branch,
    required this.info,
    required this.curriculum,
  });

  final AtlasBranch branch;
  final BranchInfo info;
  final Curriculum? curriculum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final related = <Chapter>[];
    if (curriculum != null) {
      for (final id in info.relatedChapterIds) {
        final ch = curriculum!.chapterById(id);
        if (ch != null) related.add(ch);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Eyebrow + title.
        Text(
          'THE BRANCH',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          info.title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          info.short,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        // Summary paragraph.
        Text(
          info.summary,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(label: 'QUICK FACTS'),
        const SizedBox(height: 10),
        for (final fact in info.quickFacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 10),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: branch.color,
                  ),
                ),
                Expanded(
                  child: Text(
                    fact,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader(label: 'IN THE ROUND'),
          const SizedBox(height: 10),
          for (final ch in related)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1.5,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EditorialPalette.ochre,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'CH ${ch.order}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: EditorialPalette.ink,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ch.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}
