import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../progression/presentation/org_chart_map.dart';

/// Learn tab — single canvas, the OSINT-style progression tree. Pinch-zoom,
/// pan, tap a node to open its detail. The old Path / System toggle is gone:
/// one map, always visible, lit by mastery.
class GovMapScreen extends ConsumerWidget {
  const GovMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('US Government')),
      body: OrgChartMap(
        onNodeTap: (nodeId) {
          HapticFeedback.selectionClick();
          // Phase 2 will replace this with an in-place bottom sheet that
          // groups decks by tier; for now reuse the existing node detail.
          GoRouter.of(context).go('/node/$nodeId');
        },
      ),
    );
  }
}
