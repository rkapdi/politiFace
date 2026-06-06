import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/state_views.dart';

/// Cross-mode History list reached from the Memory tab's AppBar clock
/// icon. Reads [CompletedRuns] in reverse-chronological order. Filter
/// chips narrow by mode; each row taps into the per-mode review screen.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _HistoryFilter { all, daily, trivia, endless }

extension _HistoryFilterMode on _HistoryFilter {
  String? get mode {
    switch (this) {
      case _HistoryFilter.all:
        return null;
      case _HistoryFilter.daily:
        return 'round';
      case _HistoryFilter.trivia:
        return 'trivia';
      case _HistoryFilter.endless:
        return 'endless';
    }
  }
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<CompletedRunEntry>>(
        future: db.completedRunsDao.recent(mode: _filter.mode, limit: 200),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingView();
          }
          if (snap.hasError) {
            return AppErrorView(
              title: 'Failed to load history',
              message: '${snap.error}',
              onRetry: () => setState(() {}),
            );
          }
          final entries = snap.data ?? const <CompletedRunEntry>[];
          return Column(
            children: [
              _FilterRow(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              if (entries.isEmpty)
                Expanded(
                  child: AppEmptyView(
                    icon: Icons.history,
                    title: 'No runs yet',
                    body: _filter == _HistoryFilter.all
                        ? 'Finish a daily round, trivia, or endless run to see it here.'
                        : 'No ${_filter.name} runs yet.',
                  ),
                )
              else
                Expanded(child: _Grouped(entries: entries)),
            ],
          );
        },
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});
  final _HistoryFilter value;
  final ValueChanged<_HistoryFilter> onChanged;

  static const _labels = {
    _HistoryFilter.all: 'All',
    _HistoryFilter.daily: 'Daily',
    _HistoryFilter.trivia: 'Trivia',
    _HistoryFilter.endless: 'Endless',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (final f in _HistoryFilter.values) ...[
            _Chip(
              label: _labels[f]!,
              selected: f == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(f);
              },
            ),
            if (f != _HistoryFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Grouped extends StatelessWidget {
  const _Grouped({required this.entries});
  final List<CompletedRunEntry> entries;

  String _bucketLabel(DateTime completed) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(completed.year, completed.month, completed.day);
    final diffDays = today.difference(day).inDays;
    if (diffDays == 0) return 'TODAY';
    if (diffDays == 1) return 'YESTERDAY';
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[day.month - 1]} ${day.day}';
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CompletedRunEntry>>{};
    final order = <String>[];
    for (final e in entries) {
      final completed = DateTime.fromMillisecondsSinceEpoch(
        e.completedAt * 1000,
      );
      final bucket = _bucketLabel(completed);
      if (!groups.containsKey(bucket)) {
        groups[bucket] = [];
        order.add(bucket);
      }
      groups[bucket]!.add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        for (final bucket in order) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
            child: Text(
              bucket,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          for (final entry in groups[bucket]!)
            _Row(entry: entry),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final CompletedRunEntry entry;

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    // Deep-link by runId so the review screen hydrates from the row's
    // persisted payload — works for any past run, not just the most
    // recent in-memory one.
    final uri = Uri(queryParameters: {'runId': entry.id}).toString();
    switch (entry.mode) {
      case 'trivia':
        context.push('/trivia/review$uri');
      case 'round':
        context.push('/round/review$uri');
      case 'endless':
        context.push('/endless/review$uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeColor = _modeColor(entry.mode);
    final modeLabel = _modeLabel(entry.mode);
    final time = DateTime.fromMillisecondsSinceEpoch(entry.completedAt * 1000);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final correct = entry.correctCount;
    final total = entry.totalCount;
    final headline = entry.summary ??
        (correct != null && total != null ? '$correct/$total' : '—');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline, width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.14),
                    border: Border.all(color: modeColor.withOpacity(0.55)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    modeLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: modeColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (correct != null && total != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '$correct/$total',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _modeLabel(String mode) {
    switch (mode) {
      case 'trivia':
        return 'TRIVIA';
      case 'round':
        return 'DAILY';
      case 'endless':
        return 'ENDLESS';
      default:
        return mode.toUpperCase();
    }
  }

  static Color _modeColor(String mode) {
    switch (mode) {
      case 'trivia':
        return const Color(0xFFD6242C); // action red
      case 'round':
        return const Color(0xFFC9A05B); // ochre
      case 'endless':
        return const Color(0xFF1E2A4A); // navy
      default:
        return const Color(0xFF5C5C66);
    }
  }
}
