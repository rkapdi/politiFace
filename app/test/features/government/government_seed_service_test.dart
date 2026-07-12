// GovernmentSeedService: checksum-versioned seeding from government.yaml.
//
// The contract under test:
//   1. Fresh DB → full graph seeded, entry nodes unlocked, the rest locked.
//   2. Unchanged content → ensureSeeded is a no-op (hash short-circuit).
//   3. Changed content → propagates to existing installs WITHOUT touching
//      user unlock progress.
//   4. Nodes removed from content → deactivated, never deleted.
//   5. Malformed content → keeps the existing graph, never throws.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/government/data/government_seed_service.dart';

import '../../helpers/fake_asset_bundle.dart';

const _yamlV1 = '''
meta:
  id: test-government
nodes:
  - id: t-node-a
    name: "Node A"
    short_name: "A"
    description: >
      First node.
    node_type: executive
    is_head_of_state: true
    is_head_of_govt: true
    tier_order: 1
    unlock_requires: []
    map: {x: 0.5, y: 0.1, width: 0.2, height: 0.1, shape: rectangle, color: "#111111", icon: icon_a, label_position: top}
  - id: t-node-b
    name: "Node B"
    short_name: "B"
    description: >
      Second node.
    node_type: legislature
    tier_order: 2
    unlock_requires: [t-node-a]
    map: {x: 0.5, y: 0.3, width: 0.2, height: 0.1, shape: rectangle, color: "#222222"}
edges:
  - from: t-node-a
    to: t-node-b
    type: appoints
    map: {style: solid, color: "#111111", arrow: to, visible: true}
''';

// v2: Node B description edited, Node C added, edge replaced by two edges.
const _yamlV2 = '''
meta:
  id: test-government
nodes:
  - id: t-node-a
    name: "Node A"
    short_name: "A"
    description: >
      First node.
    node_type: executive
    is_head_of_state: true
    is_head_of_govt: true
    tier_order: 1
    unlock_requires: []
    map: {x: 0.5, y: 0.1, width: 0.2, height: 0.1, shape: rectangle, color: "#111111", icon: icon_a, label_position: top}
  - id: t-node-b
    name: "Node B"
    short_name: "B"
    description: >
      Second node, now with an updated description.
    node_type: legislature
    tier_order: 2
    unlock_requires: [t-node-a]
    map: {x: 0.5, y: 0.3, width: 0.2, height: 0.1, shape: rectangle, color: "#222222"}
  - id: t-node-c
    name: "Node C"
    short_name: "C"
    description: >
      Brand new node from a content update.
    node_type: judicial
    tier_order: 3
    unlock_requires: [t-node-b]
    map: {x: 0.5, y: 0.5, width: 0.2, height: 0.1, shape: rectangle, color: "#333333"}
edges:
  - from: t-node-a
    to: t-node-b
    type: appoints
    map: {style: solid, color: "#111111", arrow: to, visible: true}
  - from: t-node-b
    to: t-node-c
    type: confirms
    map: {style: dashed, color: "#222222", arrow: to, visible: true}
''';

// v3: Node C removed again.
const _yamlV3 = _yamlV1;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seedWith(String yaml) {
    final bundle =
        FakeAssetBundle({GovernmentSeedService.assetPath: yaml});
    return GovernmentSeedService(db, bundle: bundle).ensureSeeded();
  }

  test('fresh database: graph seeded, entry node unlocked, rest locked',
      () async {
    await seedWith(_yamlV1);

    final nodes = await db.governmentDao.nodes();
    expect(nodes.map((n) => n.id).toSet(), {'t-node-a', 't-node-b'});
    final a = nodes.singleWhere((n) => n.id == 't-node-a');
    expect(a.isHeadOfState, true);
    expect(a.mapIcon, 'icon_a');
    expect(a.mapLabelPos, 'top');

    final edges = await db.governmentDao.edges();
    expect(edges.single.id, 'edge:t-node-a>t-node-b:appoints');

    final progressA = await db.progressDao.forNode('t-node-a');
    final progressB = await db.progressDao.forNode('t-node-b');
    expect(progressA!.status, 'unlocked');
    expect(progressB!.status, 'locked');
  });

  test('unchanged content is a no-op (checksum short-circuit)', () async {
    await seedWith(_yamlV1);

    // Tamper a row directly; if the second seed re-ran, it would overwrite.
    await (db.update(db.govNodes)..where((n) => n.id.equals('t-node-a')))
        .write(const GovNodesCompanion(name: Value('TAMPERED')));

    await seedWith(_yamlV1);

    final a = (await db.governmentDao.nodes())
        .singleWhere((n) => n.id == 't-node-a');
    expect(a.name, 'TAMPERED',
        reason: 'identical content must not re-seed',);
  });

  test('content update propagates without touching user unlock progress',
      () async {
    await seedWith(_yamlV1);

    // Simulate real user progress: B was unlocked and completed.
    await db.progressDao.upsert(UserNodeProgressCompanion.insert(
      nodeId: 't-node-b',
      governmentId: 'test-government',
      status: const Value('completed'),
      unlockedAt: const Value(1716000000),
      completedAt: const Value(1717000000),
    ),);

    await seedWith(_yamlV2);

    final nodes = await db.governmentDao.nodes();
    final b = nodes.singleWhere((n) => n.id == 't-node-b');
    expect(b.description, contains('updated description'),
        reason: 'content edits must reach existing installs',);

    final c = nodes.singleWhere((n) => n.id == 't-node-c');
    expect(c.tierOrder, 3);

    // User progress untouched; new node gets a fresh locked row.
    final progressB = await db.progressDao.forNode('t-node-b');
    expect(progressB!.status, 'completed');
    expect(progressB.completedAt, 1717000000);
    final progressC = await db.progressDao.forNode('t-node-c');
    expect(progressC!.status, 'locked');

    // Edges replaced wholesale, not duplicated.
    final edges = await db.governmentDao.edges();
    expect(edges, hasLength(2));
  });

  test('node removed from content is deactivated, progress preserved',
      () async {
    await seedWith(_yamlV2);
    await seedWith(_yamlV3); // C is gone again

    final nodes = await db.governmentDao.nodes();
    final c = nodes.singleWhere((n) => n.id == 't-node-c');
    expect(c.isActive, false, reason: 'removed nodes deactivate, not delete');
    expect(await db.progressDao.forNode('t-node-c'), isNotNull);

    final active = nodes.where((n) => n.isActive).map((n) => n.id).toSet();
    expect(active, {'t-node-a', 't-node-b'});
  });

  test('malformed YAML keeps the existing graph and does not throw',
      () async {
    await seedWith(_yamlV1);
    await seedWith('nodes: "not even close"');

    final nodes = await db.governmentDao.nodes();
    expect(nodes, hasLength(2), reason: 'bad content must never wipe data');
  });

  test('legacy run-once flag is cleaned up after first checksum seed',
      () async {
    await db.metaDao.set('gov_seed_v1_done', '1');
    await seedWith(_yamlV1);
    expect(await db.metaDao.get('gov_seed_v1_done'), isNull);
    expect(await db.metaDao.get('seed.government_hash'), isNotNull);
  });
}
