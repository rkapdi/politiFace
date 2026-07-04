import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../curriculum/domain/curriculum.dart';
import '../data/atlas_data_provider.dart';

/// Top strip of the Atlas. Shows the player's current chapter and which
/// Atlas branches it touches. Tapping the strip scrolls the Atlas to the
/// first highlighted branch via the [onJumpToBranch] callback.
///
/// Renders nothing (zero height) until both the curriculum and the
/// progress lookup complete — keeps the Atlas head from layout-jumping.
class ChapterSpotlight extends ConsumerWidget {
  const ChapterSpotlight({required this.onJumpToBranch, super.key});

  /// Called with the atlas branch id (e.g. `atlas-executive`) when the
  /// strip is tapped. Pass null-safe scrolling — silently no-op if the
  /// branch isn't in the Atlas (which can happen for the curriculum
  /// `foundations` branch since it has no face cards yet).
  final void Function(String atlasBranchId) onJumpToBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(currentChapterProgressProvider);

    final curriculum = curriculumAsync.valueOrNull;
    final progress = progressAsync.valueOrNull;
    if (curriculum == null) return const SizedBox.shrink();
    if (progress == null) {
      return _SeasonCompleteStrip();
    }
    final chapter = curriculum.chapterById(progress.chapterId);
    if (chapter == null) return const SizedBox.shrink();

    final curriculumBranchIds = curriculum.branchIdsForChapter(chapter);
    final atlasBranchIds = <String>[
      for (final id in curriculumBranchIds)
        if (curriculumBranchToAtlasBranch[id] != null)
          curriculumBranchToAtlasBranch[id]!,
    ];
    final highlightLabel = _highlightLabel(curriculum, curriculumBranchIds);

    return _Strip(
      title: 'YOU\'RE LEARNING',
      subtitle: 'Chapter ${chapter.order} · ${chapter.title}',
      hint: highlightLabel,
      enabled: atlasBranchIds.isNotEmpty,
      onTap: atlasBranchIds.isEmpty
          ? null
          : () => onJumpToBranch(atlasBranchIds.first),
    );
  }

  String _highlightLabel(Curriculum curriculum, List<String> branchIds) {
    if (branchIds.isEmpty) {
      return 'No face cards in today\'s chapter.';
    }
    final names = branchIds.map((id) {
      final branch = curriculum.branchById(id);
      return branch?.title ?? id;
    }).toList();
    if (names.length == 1) {
      return 'Highlights: ${names.first}';
    }
    if (names.length == 2) {
      return 'Highlights: ${names.first} + ${names.last}';
    }
    return 'Highlights: ${names.take(names.length - 1).join(', ')} + ${names.last}';
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String hint;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap?.call();
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: theme.colorScheme.brandOchre),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (enabled)
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonCompleteStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const _Strip(
      title: 'YOU\'RE LEARNING',
      subtitle: 'Season complete',
      hint: "You've walked the season. New chapters coming.",
      enabled: false,
      onTap: null,
    );
}
