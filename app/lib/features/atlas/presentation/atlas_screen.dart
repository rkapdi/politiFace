import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
///   - Search field (filters every branch's cards in-place).
///   - Chapter Spotlight strip (links the Atlas to the player's current
///     round chapter; tap to scroll to a highlighted branch).
///   - One BranchSection per top-level branch (Legislative → Executive →
///     Judicial → State and Local). Each section renders all of its
///     face cards in an alphabetized 2-column grid with mastery rings.
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
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';

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
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
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
          searchController: _searchCtl,
          query: _query,
          onQueryChanged: (q) => setState(() => _query = q),
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
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
  });

  final AtlasView view;
  final GlobalKey Function(String branchId) keyFor;
  final void Function(String branchId) onJumpToBranch;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotlightedIds = _spotlightedAtlasBranchIds(ref);
    final filteredBranches = _applySortAndFilter(view.branches, query);
    final totalAfter =
        filteredBranches.fold<int>(0, (sum, b) => sum + b.cards.length);
    final showSpotlight = query.trim().isEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: searchController,
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 16),
            if (showSpotlight) ...[
              ChapterSpotlight(onJumpToBranch: onJumpToBranch),
              const SizedBox(height: 20),
            ],
            if (totalAfter == 0 && query.isNotEmpty)
              _NoResults(query: query)
            else
              for (final branch in filteredBranches) ...[
                if (branch.cards.isNotEmpty) ...[
                  KeyedSubtree(
                    key: keyFor(branch.id),
                    child: BranchSection(
                      branch: branch,
                      spotlighted: spotlightedIds.contains(branch.id),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            if (showSpotlight) ...[
              const _ReferenceSection(),
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

  /// Returns a copy of [branches] with each branch's cards alphabetized by
  /// politician name, optionally filtered by [query] (case-insensitive
  /// match on name + title).
  List<AtlasBranch> _applySortAndFilter(
    List<AtlasBranch> branches,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    return [
      for (final b in branches)
        AtlasBranch(
          id: b.id,
          title: b.title,
          subtitle: b.subtitle,
          color: b.color,
          cards: [
            for (final c in b.cards)
              if (needle.isEmpty ||
                  c.name.toLowerCase().contains(needle) ||
                  c.title.toLowerCase().contains(needle))
                c,
          ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        ),
    ];
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search politicians or roles',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            color: theme.colorScheme.onSurfaceVariant,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            'No matches for "$query".',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry tiles for the reference layer beyond the graph: executive orders
/// (Federal Register) and the cited civic vocabulary.
class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REFERENCE',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _ReferenceTile(
          icon: Icons.gavel_outlined,
          title: 'Executive orders',
          subtitle: 'Every order of the current administration, '
              'from the Federal Register.',
          onTap: () => context.push('/atlas/orders'),
        ),
        const SizedBox(height: 8),
        _ReferenceTile(
          icon: Icons.menu_book_outlined,
          title: 'Civic vocabulary',
          subtitle: 'Key terms, defined and cited to primary sources.',
          onTap: () => context.push('/atlas/vocabulary'),
        ),
      ],
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
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
    );
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
