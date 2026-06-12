// Parses the REAL bundled government.yaml and pins the graph contract.
//
// The node-ID set, tier ordering, and unlock graph are pinned deliberately:
// user_node_progress rows key on node IDs, so renaming an id in the YAML
// would orphan existing users' unlock progress. If this test fails on a
// content PR, the id change needs a data migration, not just a YAML edit.
// (These pinned values are exactly what the deleted gov_seed_data.dart
// hardcoded — the parity proof for the YAML cutover.)

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/government/data/government_seed_service.dart';
import 'package:politiface/features/government/data/government_yaml_loader.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  Future<GovernmentDefinition> loadBundled() async {
    final raw = await rootBundle.loadString(GovernmentSeedService.assetPath);
    return const GovernmentYamlLoader().parse(raw);
  }

  test('bundled YAML parses with the canonical government id', () async {
    final gov = await loadBundled();
    expect(gov.id, 'us-government');
  });

  test('node id set matches the ids existing installs have progress for',
      () async {
    final gov = await loadBundled();
    expect(gov.nodes.map((n) => n.id).toSet(), {
      'us-node-president',
      'us-node-cabinet',
      'us-node-exec-office',
      'us-node-congress',
      'us-node-senate',
      'us-node-house',
      'us-node-how-laws-are-made',
      'us-node-scotus',
      'us-node-parties',
    });
  });

  test('tier ordering matches the pre-cutover graph', () async {
    final gov = await loadBundled();
    final tiers = {for (final n in gov.nodes) n.id: n.tierOrder};
    expect(tiers, {
      'us-node-president': 1,
      'us-node-cabinet': 2,
      'us-node-congress': 2,
      'us-node-exec-office': 3,
      'us-node-senate': 3,
      'us-node-house': 3,
      'us-node-how-laws-are-made': 4,
      'us-node-scotus': 4,
      'us-node-parties': 6,
    });
  });

  test('unlock graph matches the pre-cutover graph', () async {
    final gov = await loadBundled();
    final unlocks = {for (final n in gov.nodes) n.id: n.unlockRequires};
    expect(unlocks['us-node-president'], isEmpty);
    expect(unlocks['us-node-cabinet'], ['us-node-president']);
    expect(unlocks['us-node-exec-office'], ['us-node-president']);
    expect(unlocks['us-node-congress'], ['us-node-president']);
    expect(unlocks['us-node-senate'], ['us-node-congress']);
    expect(unlocks['us-node-house'], ['us-node-congress']);
    expect(unlocks['us-node-how-laws-are-made'],
        ['us-node-senate', 'us-node-house'],);
    expect(unlocks['us-node-scotus'], ['us-node-senate']);
    expect(unlocks['us-node-parties'], ['us-node-senate', 'us-node-house']);
  });

  test('exactly one head of state / head of government', () async {
    final gov = await loadBundled();
    expect(gov.nodes.where((n) => n.isHeadOfState).map((n) => n.id),
        ['us-node-president'],);
    expect(gov.nodes.where((n) => n.isHeadOfGovt).map((n) => n.id),
        ['us-node-president'],);
  });

  test('edges parse with deterministic ids and valid node references',
      () async {
    final gov = await loadBundled();
    expect(gov.edges, hasLength(10));
    final nodeIds = gov.nodes.map((n) => n.id).toSet();
    for (final e in gov.edges) {
      expect(nodeIds, contains(e.fromNodeId));
      expect(nodeIds, contains(e.toNodeId));
      expect(e.id, 'edge:${e.fromNodeId}>${e.toNodeId}:${e.relationshipType}');
    }
    // Determinism — parsing twice yields identical edge ids in order.
    final again = await loadBundled();
    expect(again.edges.map((e) => e.id).toList(),
        gov.edges.map((e) => e.id).toList(),);
  });

  test('map metadata the old Dart seed never carried is now loaded', () async {
    final gov = await loadBundled();
    final president =
        gov.nodes.singleWhere((n) => n.id == 'us-node-president');
    expect(president.mapIcon, 'white_house');
    expect(president.mapLabelPos, 'top');
    expect(president.mapX, 0.50);
    expect(president.mapColor, '#8B0000');
  });

  test('folded descriptions are trimmed', () async {
    final gov = await loadBundled();
    for (final n in gov.nodes) {
      expect(n.description, isNot(endsWith('\n')));
      expect(n.description, isNotEmpty);
    }
  });

  group('schema violations throw', () {
    const loader = GovernmentYamlLoader();

    test('missing meta.id', () {
      expect(() => loader.parse('nodes: []\nedges: []'),
          throwsFormatException,);
    });

    test('node without id', () {
      expect(
        () => loader.parse('''
meta: {id: x}
nodes:
  - name: "No id"
edges: []
'''),
        throwsFormatException,
      );
    });

    test('node without map block', () {
      expect(
        () => loader.parse('''
meta: {id: x}
nodes:
  - id: n1
    name: "N"
    short_name: "N"
    node_type: executive
    tier_order: 1
edges: []
'''),
        throwsFormatException,
      );
    });

    test('edge without from/to/type', () {
      expect(
        () => loader.parse('''
meta: {id: x}
nodes:
  - id: n1
    name: "N"
    short_name: "N"
    node_type: executive
    tier_order: 1
    map: {x: 0.1, y: 0.1, width: 0.1, height: 0.1}
edges:
  - from: n1
'''),
        throwsFormatException,
      );
    });
  });
}
