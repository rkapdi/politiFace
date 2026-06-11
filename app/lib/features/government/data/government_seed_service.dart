import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/content/content_checksum.dart';
import '../../../core/database/drift/app_database.dart';
import 'government_yaml_loader.dart';

/// Seeds the government graph from the bundled copy of
/// content/governments/us/government.yaml — the canonical content source.
///
/// Checksum-versioned: the YAML's SHA-256 is stored in app_meta; the graph
/// re-seeds automatically whenever the bundled content changes and is a
/// no-op otherwise. Re-seeding never touches user unlock progress —
/// progress rows are only ever created for nodes that don't have one.
class GovernmentSeedService {
  GovernmentSeedService(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AppDatabase _db;
  final AssetBundle _bundle;

  static const assetPath = 'assets/content/governments/us/government.yaml';
  static const _hashKey = 'seed.government_hash';

  /// Pre-checksum installs stored a run-once flag; cleaned up on first
  /// checksum-based seed.
  static const _legacyFlagKey = 'gov_seed_v1_done';

  Future<void> ensureSeeded() async {
    final String raw;
    final GovernmentDefinition gov;
    try {
      raw = await _bundle.loadString(assetPath);
      gov = const GovernmentYamlLoader().parse(raw);
    } on Exception catch (e) {
      // A missing or malformed bundled asset means a broken build — CI
      // validates this file on every PR. Keep whatever graph is already in
      // the database rather than crashing the launch path.
      debugPrint('GovernmentSeedService: cannot load $assetPath: $e');
      return;
    }

    final hash = contentChecksum({assetPath: raw});
    if (await _db.metaDao.get(_hashKey) == hash) return;

    await _db.transaction(() async {
      final yamlNodeIds = <String>{};
      for (final node in gov.nodes) {
        yamlNodeIds.add(node.id);
        await _db.governmentDao.upsertNode(GovNodesCompanion.insert(
          id: node.id,
          governmentId: gov.id,
          externalId: node.id,
          name: node.name,
          shortName: Value(node.shortName),
          description: Value(node.description),
          nodeType: node.nodeType,
          isHeadOfState: Value(node.isHeadOfState),
          isHeadOfGovt: Value(node.isHeadOfGovt),
          isElected: Value(node.isElected),
          mapX: Value(node.mapX),
          mapY: Value(node.mapY),
          mapWidth: Value(node.mapWidth),
          mapHeight: Value(node.mapHeight),
          mapShape: Value(node.mapShape),
          mapColor: Value(node.mapColor),
          mapIcon: Value(node.mapIcon),
          mapLabelPos: Value(node.mapLabelPos ?? 'bottom'),
          tierOrder: node.tierOrder,
          unlockRequires: Value(_encodeStringList(node.unlockRequires)),
          isActive: const Value(true),
        ));

        // Create progress for nodes the user has never seen; NEVER overwrite
        // an existing row — a content update must not reset unlocks.
        await _db.progressDao.insertIfAbsent(UserNodeProgressCompanion.insert(
          nodeId: node.id,
          governmentId: gov.id,
          status: Value(node.unlockRequires.isEmpty ? 'unlocked' : 'locked'),
          unlockedAt: Value(
            node.unlockRequires.isEmpty
                ? DateTime.now().millisecondsSinceEpoch ~/ 1000
                : null,
          ),
        ));
      }

      // Nodes removed from the YAML are deactivated, not deleted — decks and
      // progress rows may still reference them, and history must stay intact.
      await (_db.update(_db.govNodes)
            ..where((n) =>
                n.governmentId.equals(gov.id) & n.id.isNotIn(yamlNodeIds)))
          .write(const GovNodesCompanion(isActive: Value(false)));

      // Edges carry no user data and have no stable ids in the YAML, so
      // replace them wholesale: delete this government's edges, re-insert.
      await (_db.delete(_db.govEdges)
            ..where((e) => e.governmentId.equals(gov.id)))
          .go();
      for (final edge in gov.edges) {
        await _db.governmentDao.upsertEdge(GovEdgesCompanion.insert(
          id: edge.id,
          governmentId: gov.id,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          relationshipType: edge.relationshipType,
          description: Value(edge.description),
          isVisibleOnMap: Value(edge.isVisibleOnMap),
          lineStyle: Value(edge.lineStyle),
          lineColor: Value(edge.lineColor),
          arrowDirection: Value(edge.arrowDirection),
        ));
      }

      // Backfill the genesis-era deck's nodeId for DBs created before the
      // deck YAML carried node links. No-op when the deck doesn't exist.
      await _db.decksDao.setDeckNodeId(
        deckId: 'deck_us_exec_v1',
        nodeId: 'us-node-president',
      );

      await _db.metaDao.set(_hashKey, hash);
      await _db.metaDao.remove(_legacyFlagKey);
    });
  }

  static String _encodeStringList(List<String> items) {
    if (items.isEmpty) return '[]';
    final escaped = items.map((s) => '"$s"').join(',');
    return '[$escaped]';
  }
}
