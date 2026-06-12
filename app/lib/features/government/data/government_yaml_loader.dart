import 'package:yaml/yaml.dart';

/// Parsed government graph from a `government.yaml` file — the canonical
/// content format (see content/governments/). Pure parsing, no database:
/// [GovernmentSeedService] maps this onto Drift rows.
///
/// The same file is validated structurally by scripts/validate_government.py
/// in CI; this parser still throws [FormatException] on schema violations so
/// a malformed bundle fails tests loudly instead of seeding garbage.
class GovernmentDefinition {
  const GovernmentDefinition({
    required this.id,
    required this.nodes,
    required this.edges,
  });

  final String id;
  final List<GovNodeDef> nodes;
  final List<GovEdgeDef> edges;
}

class GovNodeDef {
  const GovNodeDef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.nodeType,
    required this.tierOrder,
    required this.unlockRequires,
    required this.mapX,
    required this.mapY,
    required this.mapWidth,
    required this.mapHeight,
    required this.mapShape,
    required this.mapColor,
    required this.mapIcon,
    required this.mapLabelPos,
    required this.isHeadOfState,
    required this.isHeadOfGovt,
    required this.isElected,
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final String nodeType;
  final int tierOrder;
  final List<String> unlockRequires;
  final double mapX;
  final double mapY;
  final double mapWidth;
  final double mapHeight;
  final String mapShape;
  final String mapColor;
  final String? mapIcon;
  final String? mapLabelPos;
  final bool isHeadOfState;
  final bool isHeadOfGovt;
  final bool? isElected;
}

class GovEdgeDef {
  const GovEdgeDef({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.relationshipType,
    required this.description,
    required this.lineStyle,
    required this.lineColor,
    required this.arrowDirection,
    required this.isVisibleOnMap,
  });

  /// Deterministic, derived from (from, to, type) — the YAML schema has no
  /// edge id field, and the validator guarantees that triple is unique.
  /// Stable ids keep edge replacement idempotent across re-seeds.
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String relationshipType;
  final String? description;
  final String lineStyle;
  final String? lineColor;
  final String arrowDirection;
  final bool isVisibleOnMap;
}

class GovernmentYamlLoader {
  const GovernmentYamlLoader();

  GovernmentDefinition parse(String yamlSource) {
    final doc = loadYaml(yamlSource);
    if (doc is! Map) {
      throw const FormatException('government.yaml: root is not a map');
    }

    final meta = doc['meta'];
    if (meta is! Map || meta['id'] is! String) {
      throw const FormatException('government.yaml: meta.id missing');
    }
    final governmentId = meta['id'] as String;

    final rawNodes = doc['nodes'];
    if (rawNodes is! List || rawNodes.isEmpty) {
      throw const FormatException('government.yaml: nodes missing or empty');
    }
    final nodes = <GovNodeDef>[
      for (final n in rawNodes) _parseNode(n),
    ];

    final rawEdges = doc['edges'];
    if (rawEdges is! List) {
      throw const FormatException('government.yaml: edges missing');
    }
    final edges = <GovEdgeDef>[
      for (final e in rawEdges) _parseEdge(e),
    ];

    return GovernmentDefinition(id: governmentId, nodes: nodes, edges: edges);
  }

  GovNodeDef _parseNode(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('government.yaml: node is not a map');
    }
    final id = raw['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('government.yaml: node missing id');
    }
    final map = raw['map'];
    if (map is! Map) {
      throw FormatException('government.yaml: node $id missing map block');
    }
    final name = raw['name'];
    final shortName = raw['short_name'];
    final nodeType = raw['node_type'];
    final tierOrder = raw['tier_order'];
    if (name is! String || shortName is! String || nodeType is! String) {
      throw FormatException(
          'government.yaml: node $id missing name/short_name/node_type',);
    }
    if (tierOrder is! int) {
      throw FormatException('government.yaml: node $id missing tier_order');
    }

    return GovNodeDef(
      id: id,
      name: name,
      shortName: shortName,
      // Folded YAML scalars (>) carry a trailing newline — trim for storage.
      description: ((raw['description'] as String?) ?? '').trim(),
      nodeType: nodeType,
      tierOrder: tierOrder,
      unlockRequires: [
        for (final r in raw['unlock_requires'] as List? ?? const [])
          r as String,
      ],
      mapX: _toDouble(map['x'], id, 'map.x'),
      mapY: _toDouble(map['y'], id, 'map.y'),
      mapWidth: _toDouble(map['width'], id, 'map.width'),
      mapHeight: _toDouble(map['height'], id, 'map.height'),
      mapShape: (map['shape'] as String?) ?? 'rectangle',
      mapColor: (map['color'] as String?) ?? '#444444',
      mapIcon: map['icon'] as String?,
      mapLabelPos: map['label_position'] as String?,
      isHeadOfState: raw['is_head_of_state'] == true,
      isHeadOfGovt: raw['is_head_of_govt'] == true,
      isElected: raw['is_elected'] as bool?,
    );
  }

  GovEdgeDef _parseEdge(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('government.yaml: edge is not a map');
    }
    final from = raw['from'];
    final to = raw['to'];
    final type = raw['type'];
    if (from is! String || to is! String || type is! String) {
      throw const FormatException('government.yaml: edge missing from/to/type');
    }
    final map = (raw['map'] as Map?) ?? const {};
    return GovEdgeDef(
      id: 'edge:$from>$to:$type',
      fromNodeId: from,
      toNodeId: to,
      relationshipType: type,
      description: (raw['description'] as String?)?.trim(),
      lineStyle: (map['style'] as String?) ?? 'solid',
      lineColor: map['color'] as String?,
      arrowDirection: (map['arrow'] as String?) ?? 'to',
      isVisibleOnMap: (map['visible'] as bool?) ?? true,
    );
  }

  double _toDouble(dynamic v, String nodeId, String field) {
    if (v is num) return v.toDouble();
    throw FormatException('government.yaml: node $nodeId: $field not a number');
  }
}
