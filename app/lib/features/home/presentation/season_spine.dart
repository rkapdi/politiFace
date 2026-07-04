import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../curriculum/domain/curriculum.dart';
import 'chapter_info_sheet.dart';

/// Vertical strip showing the entire season at a glance — one row per
/// chapter, with status glyph + title + day dots. Lives at the bottom of
/// home as a "where am I in the bigger picture" anchor.
///
/// Status per chapter:
///   - **completed**: solid check, full row of filled dots.
///   - **current**: solid filled dot, partial dots reflecting `dayInChapter`.
///   - **locked**: hollow circle, hollow dots, muted text.
class SeasonSpine extends ConsumerWidget {
  const SeasonSpine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumAsync = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(seasonProgressProvider);

    final curriculum = curriculumAsync.valueOrNull;
    final entries = progressAsync.valueOrNull ?? const <ChapterProgressEntry>[];
    if (curriculum == null) return const SizedBox.shrink();

    final byId = <String, ChapterProgressEntry>{
      for (final e in entries) e.chapterId: e,
    };

    // Determine the "current" chapter order — the first chapter that isn't
    // yet completed. Defaults to chapter 1 for a fresh user with no entries,
    // so chapter 1 always reads as available rather than locked.
    final currentOrder = _resolveCurrentOrder(
      chapters: curriculum.chapters,
      byId: byId,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < curriculum.chapters.length; i++) ...[
            _ChapterRow(
              chapter: curriculum.chapters[i],
              entry: byId[curriculum.chapters[i].id],
              currentOrder: currentOrder,
            ),
            if (i != curriculum.chapters.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  /// First chapter (by `order`) that hasn't been completed yet. Returns the
  /// last chapter's order when the whole season is done.
  static int _resolveCurrentOrder({
    required List<Chapter> chapters,
    required Map<String, ChapterProgressEntry> byId,
  }) {
    for (final c in chapters) {
      final e = byId[c.id];
      if (e == null || e.completedAt == null) return c.order;
    }
    return chapters.isEmpty ? 1 : chapters.last.order;
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.entry,
    required this.currentOrder,
  });

  final Chapter chapter;
  final ChapterProgressEntry? entry;

  /// Order of the chapter the player is on right now. Drives current/locked
  /// status without relying solely on entry presence, so chapter 1 reads as
  /// available even before its progress row gets seeded.
  final int currentOrder;

  bool get _isCompleted => entry?.completedAt != null;
  bool get _isCurrent => chapter.order == currentOrder && !_isCompleted;
  bool get _isLocked => chapter.order > currentOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = _isLocked
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final fontWeight = _isCurrent ? FontWeight.w900 : FontWeight.w700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ChapterInfoSheet.show(
            context,
            chapter: chapter,
            entry: entry,
            currentOrder: currentOrder,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _StatusGlyph(
                isCompleted: _isCompleted,
                isCurrent: _isCurrent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'CH ${chapter.order}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: titleColor,
                          fontWeight: fontWeight,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DayDots(
                total: chapter.days,
                filled: _isCompleted
                    ? chapter.days
                    : _isCurrent && entry != null
                        ? (entry!.dayInChapter - 1).clamp(0, chapter.days)
                        : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.isCompleted, required this.isCurrent});
  final bool isCompleted;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isCompleted) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: theme.colorScheme.brandGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
      );
    }
    if (isCurrent) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: theme.colorScheme.brandOchre,
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
      ),
    );
  }
}

class _DayDots extends StatelessWidget {
  const _DayDots({required this.total, required this.filled});
  final int total;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.surfaceContainerHigh,
              border: i >= filled
                  ? Border.all(
                      color: theme.colorScheme.outlineVariant,
                    )
                  : null,
            ),
          ),
          if (i != total - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
