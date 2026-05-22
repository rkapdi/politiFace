import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progression/presentation/node_detail_sheet.dart';
import '../../progression/presentation/org_chart_map.dart';

/// Learn tab — single canvas, the OSINT-style progression tree. Pinch-zoom,
/// pan, tap a node to open the in-place tier sheet.
class GovMapScreen extends ConsumerWidget {
  const GovMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('US Government')),
      body: OrgChartMap(
        onNodeTap: (nodeId) {
          HapticFeedback.selectionClick();
          NodeDetailSheet.show(context, nodeId);
        },
      ),
    );
  }
}
