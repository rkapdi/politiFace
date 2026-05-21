import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/state_views.dart';
import '../application/gov_map_data.dart';
import 'system_view.dart';

class GovMapScreen extends ConsumerWidget {
  const GovMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(govMapDataProvider);
    final mode = ref.watch(govMapViewModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('US Government')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<GovMapViewMode>(
              segments: const [
                ButtonSegment(
                  value: GovMapViewMode.path,
                  label: Text('Path'),
                  icon: Icon(Icons.timeline),
                ),
                ButtonSegment(
                  value: GovMapViewMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.hub_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                ref.read(govMapViewModeProvider.notifier).state = s.first;
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const AppLoadingView(label: 'Loading map…'),
              error: (e, _) => AppErrorView(
                title: 'Failed to load map',
                message: '$e',
                onRetry: () => ref.invalidate(govMapDataProvider),
              ),
              data: (data) => mode == GovMapViewMode.path
                  ? _DuolingoPath(data: data)
                  : SystemView(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section({
    required this.title,
    required this.accent,
    required this.nodes,
  });
  final String title;
  final Color accent;
  final List<GovNode> nodes;
}

class _DuolingoPath extends StatelessWidget {
  const _DuolingoPath({required this.data});
  final GovMapData data;

  static const _sectionDefs = <String, ({String title, Color accent})>{
    'executive': (title: 'Executive Branch', accent: Color(0xFF8B0000)),
    'legislature': (title: 'Legislative Branch', accent: Color(0xFF002868)),
    'judicial': (title: 'Judicial Branch', accent: Color(0xFF3D3D3D)),
    'political-party': (title: 'Political Parties', accent: Color(0xFF5A5A8A)),
  };

  List<_Section> _buildSections() {
    final byType = <String, List<GovNode>>{};
    for (final n in data.nodes) {
      byType.putIfAbsent(n.nodeType, () => []).add(n);
    }
    for (final list in byType.values) {
      list.sort((a, b) => a.tierOrder.compareTo(b.tierOrder));
    }
    // Stable section order — executive first, parties last.
    const order = ['executive', 'legislature', 'judicial', 'political-party'];
    return [
      for (final t in order)
        if (byType[t] != null && byType[t]!.isNotEmpty)
          _Section(
            title: _sectionDefs[t]!.title,
            accent: _sectionDefs[t]!.accent,
            nodes: byType[t]!,
          ),
      // Catch-all for any unrecognized nodeType we add later.
      for (final entry in byType.entries)
        if (!order.contains(entry.key))
          _Section(
            title: entry.key,
            accent: Theme.of(WidgetsBinding.instance.rootElement!).colorScheme.primary,
            nodes: entry.value,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();
    final activeNodeId = _findActiveNode(sections);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      // +1 for the trailing "more coming soon" footer.
      itemCount: sections.length + 1,
      itemBuilder: (ctx, sectionIdx) {
        if (sectionIdx == sections.length) return const _ComingSoonFooter();
        final section = sections[sectionIdx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: section.title, accent: section.accent),
            for (var i = 0; i < section.nodes.length; i++)
              _PathNode(
                node: section.nodes[i],
                accent: section.accent,
                position: i.isEven ? _Side.left : _Side.right,
                isUnlocked: data.isUnlocked(section.nodes[i].id),
                isCompleted: data.progressByNodeId[section.nodes[i].id] ==
                    'completed',
                isActive: section.nodes[i].id == activeNodeId,
                isFirstInSection: i == 0,
                isLastInSection: i == section.nodes.length - 1,
                mastery: data.masteryFor(section.nodes[i].id),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  /// First unlocked-but-not-completed node — the recommended "next step".
  String? _findActiveNode(List<_Section> sections) {
    for (final section in sections) {
      for (final n in section.nodes) {
        final status = data.progressByNodeId[n.id];
        if (status != null && status != 'locked' && status != 'completed') {
          return n.id;
        }
      }
    }
    // Fall back to the first unlocked node we can find.
    for (final section in sections) {
      for (final n in section.nodes) {
        if (data.isUnlocked(n.id)) return n.id;
      }
    }
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.accent});
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 26,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonFooter extends StatelessWidget {
  const _ComingSoonFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          // Long fading vertical line that visually says "the path continues"
          Container(
            width: 2,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.outlineVariant,
                  theme.colorScheme.outlineVariant.withOpacity(0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'More coming soon',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cabinet members, Senate & House leadership, '
                  'SCOTUS justices, party figures — and more countries.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Side { left, right }

class _PathNode extends StatelessWidget {
  const _PathNode({
    required this.node,
    required this.accent,
    required this.position,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isActive,
    required this.isFirstInSection,
    required this.isLastInSection,
    required this.mastery,
  });

  final GovNode node;
  final Color accent;
  final _Side position;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isActive;
  final bool isFirstInSection;
  final bool isLastInSection;
  final NodeMastery? mastery;

  static const _circleSize = 92.0;
  static const _horizOffset = 40.0;

  IconData _iconFor(String id) {
    switch (id) {
      case 'us-node-president':
        return Icons.star_outline;
      case 'us-node-cabinet':
        return Icons.work_outline;
      case 'us-node-exec-office':
        return Icons.business_outlined;
      case 'us-node-congress':
        return Icons.account_balance_outlined;
      case 'us-node-senate':
        return Icons.gavel_outlined;
      case 'us-node-house':
        return Icons.groups_outlined;
      case 'us-node-how-laws-are-made':
        return Icons.menu_book_outlined;
      case 'us-node-scotus':
        return Icons.balance_outlined;
      case 'us-node-parties':
        return Icons.flag_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final circleColor = isUnlocked
        ? accent
        : theme.colorScheme.surfaceContainerHighest;
    final iconColor = isUnlocked
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
    final label = (node.shortName?.isNotEmpty ?? false) ? node.shortName! : node.name;

    final alignment = position == _Side.left
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final padding = position == _Side.left
        ? const EdgeInsets.only(left: _horizOffset)
        : const EdgeInsets.only(right: _horizOffset);

    Widget circle = Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        boxShadow: [
          if (isUnlocked)
            BoxShadow(
              color: accent.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Icon(_iconFor(node.id), color: iconColor, size: 44),
    );

    if (isActive) {
      circle = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _circleSize + 16,
            height: _circleSize + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 3),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.08, 1.08),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              ),
          circle,
        ],
      );
    }

    if (isCompleted) {
      circle = Stack(
        children: [
          circle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.green.shade500,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 3),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          ),
        ],
      );
    } else if (!isUnlocked) {
      circle = Stack(
        children: [
          circle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock,
                color: theme.colorScheme.outline,
                size: 14,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (!isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Locked — complete the prerequisites first.'),
            duration: Duration(seconds: 2),
          ));
          HapticFeedback.lightImpact();
          return;
        }
        HapticFeedback.lightImpact();
        GoRouter.of(context).go('/node/${node.id}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            if (!isFirstInSection)
              _Connector(
                fromSide: position == _Side.left ? _Side.right : _Side.left,
                toSide: position,
                color: accent.withOpacity(isUnlocked ? 0.4 : 0.18),
              ),
            Align(
              alignment: alignment,
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    circle,
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isUnlocked
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isActive)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'START',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    if (isUnlocked &&
                        mastery != null &&
                        mastery!.hasContent) ...[
                      const SizedBox(height: 6),
                      _MasteryPill(mastery: mastery!, accent: accent),
                    ],
                  ],
                ),
              ),
            ),
            if (isLastInSection) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Small badge under each unlocked node showing "N/M mastered" with a
/// gradient progress bar behind the text. The count ticks on ★5 milestones;
/// the bar fills smoothly with every grade so the user gets immediate
/// "I'm progressing" feedback even before any card hits full mastery.
class _MasteryPill extends StatelessWidget {
  const _MasteryPill({required this.mastery, required this.accent});
  final NodeMastery mastery;
  final Color accent;

  static const _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFull = mastery.isFullyMastered;
    final fraction = mastery.masteryFraction;

    return TweenAnimationBuilder<double>(
      // begin == end so the bar doesn't replay 0 → N on every map re-render;
      // when fraction genuinely changes, TweenAnimationBuilder still animates
      // from the prior value to the new end.
      tween: Tween<double>(begin: fraction, end: fraction),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final stop = animated.clamp(0.0, 1.0);
        // Use the node's own accent color (e.g. President's red) so the fill
        // visibly belongs to that node. The earlier theme-primary fill at low
        // opacity disappeared into the dark surface and read as "no progress."
        final fillColor = isFull ? _gold : accent;
        final trackColor = theme.colorScheme.surfaceContainerHighest;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            // Hard-stop gradient = a fill bar behind the text. Two colors,
            // both doubled so the transition is crisp (no soft blend in the
            // middle).
            gradient: LinearGradient(
              colors: [
                fillColor.withOpacity(isFull ? 0.45 : 0.65),
                fillColor.withOpacity(isFull ? 0.45 : 0.65),
                trackColor,
                trackColor,
              ],
              stops: [0.0, stop, stop, 1.0],
            ),
            borderRadius: BorderRadius.circular(12),
            border:
                isFull ? Border.all(color: _gold.withOpacity(0.6)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 14,
                color: isFull ? _gold : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${mastery.masteredCount}/${mastery.totalCards}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isFull ? _gold : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Diagonal dashed line connecting two alternating nodes.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.fromSide,
    required this.toSide,
    required this.color,
  });
  final _Side fromSide;
  final _Side toSide;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _ConnectorPainter(
          fromSide: fromSide,
          toSide: toSide,
          color: color,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.fromSide,
    required this.toSide,
    required this.color,
  });
  final _Side fromSide;
  final _Side toSide;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fromX = fromSide == _Side.left ? size.width * 0.32 : size.width * 0.68;
    final toX = toSide == _Side.left ? size.width * 0.32 : size.width * 0.68;

    // Dotted curved-ish line.
    const dashLen = 5.0;
    const gapLen = 6.0;
    final total = (dashLen + gapLen);
    final dy = size.height;
    final dx = toX - fromX;
    final lineLength = (dx * dx + dy * dy);
    final dist = lineLength <= 0 ? 1.0 : (lineLength).abs();
    // Simple parametric: divide by length-ish into segments
    var t = 0.0;
    final steps = (size.height / total).floor();
    for (var i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + dashLen / size.height) / steps;
      final p0 = Offset(fromX + dx * t0, dy * t0);
      final p1 = Offset(fromX + dx * t1, dy * t1);
      canvas.drawLine(p0, p1, paint);
    }
    // dist + t are intentionally unused — kept for potential curve refactor.
    // ignore: unused_local_variable
    final _ = dist + t;
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.color != color || old.fromSide != fromSide || old.toSide != toSide;
}
