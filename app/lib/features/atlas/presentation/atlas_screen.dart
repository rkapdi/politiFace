import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shared/widgets/state_views.dart';
import '../data/atlas_data_provider.dart';
import 'branch_section.dart';
import 'chapter_spotlight.dart';

/// The Learn tab, reframed as the Atlas — a vertical scroll through the
/// territory rather than a free-form graph. Replaces the previous
/// pan/zoom org chart for the same `/map` route.
///
/// Structure (top to bottom):
///   - Chapter Spotlight strip (links the Atlas to the player's current
///     round chapter; tap to scroll to a highlighted branch).
///   - One BranchSection per top-level branch (Legislative → Executive →
///     Judicial → State and Local). Each section renders all of its
///     face cards in a 2-column grid with mastery rings.
///   - Bottom summary: "X / Y cards mastered."
class AtlasScreen extends ConsumerStatefulWidget {
  const AtlasScreen({super.key});

  @override
  ConsumerState<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends ConsumerState<AtlasScreen> {
  /// One key per atlas branch id so ChapterSpotlight can scroll the
  /// corresponding section into view via Scrollable.ensureVisible.
  final Map<String, GlobalKey> _branchKeys = {};

  GlobalKey _keyFor(String branchId) =>
      _branchKeys.putIfAbsent(branchId, GlobalKey.new);

  void _scrollToBranch(String branchId) {
    final key = _branchKeys[branchId];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05, // tuck just below the appbar
    );
  }

  @override
  Widget build(BuildContext context) {
    final atlasAsync = ref.watch(atlasViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas'),
      ),
      body: atlasAsync.when(
        loading: () => const AppLoadingView(label: 'Loading the Atlas…'),
        error: (e, _) => AppErrorView(
          title: 'Failed to load Atlas',
          message: '$e',
          onRetry: () => ref.invalidate(atlasViewProvider),
        ),
        data: (view) => _AtlasBody(
          view: view,
          keyFor: _keyFor,
          onJumpToBranch: _scrollToBranch,
        ),
      ),
    );
  }
}

class _AtlasBody extends ConsumerWidget {
  const _AtlasBody({
    required this.view,
    required this.keyFor,
    required this.onJumpToBranch,
  });

  final AtlasView view;
  final GlobalKey Function(String branchId) keyFor;
  final void Function(String branchId) onJumpToBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotlightedIds = _spotlightedAtlasBranchIds(ref);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChapterSpotlight(onJumpToBranch: onJumpToBranch),
            const SizedBox(height: 20),
            for (final branch in view.branches) ...[
              KeyedSubtree(
                key: keyFor(branch.id),
                child: BranchSection(
                  branch: branch,
                  spotlighted: spotlightedIds.contains(branch.id),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            _MasterySummary(view: view),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Which atlas branch ids the current chapter touches. Empty when the
  /// curriculum hasn't loaded or the season is complete.
  Set<String> _spotlightedAtlasBranchIds(WidgetRef ref) {
    final curriculum = ref.watch(curriculumProvider).valueOrNull;
    final progress = ref.watch(currentChapterProgressProvider).valueOrNull;
    if (curriculum == null || progress == null) return const {};
    final chapter = curriculum.chapterById(progress.chapterId);
    if (chapter == null) return const {};
    final curriculumBranchIds = curriculum.branchIdsForChapter(chapter);
    return {
      for (final id in curriculumBranchIds)
        if (curriculumBranchToAtlasBranch[id] != null)
          curriculumBranchToAtlasBranch[id]!,
    };
  }
}

class _MasterySummary extends StatelessWidget {
  const _MasterySummary({required this.view});
  final AtlasView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: theme.colorScheme.outlineVariant),
        ),
        const SizedBox(width: 10),
        Text(
          'YOUR ATLAS · ${view.masteredCards} / ${view.totalCards} MASTERED',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: theme.colorScheme.outlineVariant),
        ),
      ],
    );
  }
}
