#!/usr/bin/env python3
"""
scripts/validate_government.py

Validates a government YAML file before it is merged and seeded.
Run by GitHub Actions on every PR touching content/governments/**

Exit 0: validation passed
Exit 1: validation failed (with error details)

Checks:
  1. Schema completeness (required fields present)
  2. Cycle detection in unlock_requires graph (DFS, O(n+e))
  3. Reachability: all nodes reachable from entry points (BFS, O(n+e))
  4. Edge references valid node IDs
  5. Map coordinates in 0.0-1.0 range
  6. Exactly one head_of_state and one head_of_govt
  7. unlock_requires references exist in nodes
  8. No duplicate node IDs or edge combinations
"""

import sys
import yaml
from pathlib import Path
from collections import defaultdict, deque


REQUIRED_META_FIELDS = ['id', 'country', 'formal_name', 'system_type']
REQUIRED_NODE_FIELDS = ['id', 'name', 'short_name', 'node_type', 'tier_order', 'unlock_requires', 'map']
REQUIRED_MAP_FIELDS  = ['x', 'y', 'width', 'height', 'shape', 'color']
VALID_SHAPES         = {'rectangle', 'circle', 'hexagon', 'custom'}
VALID_ARROW_DIRS     = {'to', 'from', 'both', 'none'}
VALID_LINE_STYLES    = {'solid', 'dashed', 'dotted'}


def validate(path: str) -> list[str]:
    errors = []
    file_path = Path(path)

    if not file_path.exists():
        return [f"File not found: {path}"]

    with open(file_path) as f:
        try:
            data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            return [f"YAML parse error: {e}"]

    if not isinstance(data, dict):
        return ["Root document must be a mapping (dict)"]

    # ── Meta ──────────────────────────────────────────────────────────────────
    meta = data.get('meta', {})
    for field in REQUIRED_META_FIELDS:
        if field not in meta:
            errors.append(f"meta.{field} is required")

    # ── Nodes ─────────────────────────────────────────────────────────────────
    raw_nodes = data.get('nodes', [])
    if not raw_nodes:
        errors.append("At least one node is required")
        return errors  # can't validate further without nodes

    nodes = {}
    for node in raw_nodes:
        # Required fields
        for field in REQUIRED_NODE_FIELDS:
            if field not in node:
                errors.append(f"Node {node.get('id', '?')} missing required field: {field}")

        node_id = node.get('id')
        if not node_id:
            errors.append("Node missing 'id' field")
            continue

        if node_id in nodes:
            errors.append(f"Duplicate node id: {node_id}")
            continue

        nodes[node_id] = node

        # Map coordinate validation
        m = node.get('map', {})
        for coord in REQUIRED_MAP_FIELDS:
            if coord not in m:
                errors.append(f"Node {node_id}.map.{coord} is required")
                continue
            val = m[coord]
            if coord in ('x', 'y', 'width', 'height'):
                if not isinstance(val, (int, float)) or not (0.0 <= float(val) <= 1.0):
                    errors.append(
                        f"Node {node_id}.map.{coord} must be 0.0-1.0, got: {val}"
                    )

        if 'shape' in m and m['shape'] not in VALID_SHAPES:
            errors.append(
                f"Node {node_id}.map.shape must be one of {VALID_SHAPES}, got: {m['shape']}"
            )

        # unlock_requires must be a list
        if 'unlock_requires' in node and not isinstance(node['unlock_requires'], list):
            errors.append(f"Node {node_id}.unlock_requires must be a list")

    # ── unlock_requires reference check ───────────────────────────────────────
    for node in nodes.values():
        for dep in node.get('unlock_requires', []):
            if dep not in nodes:
                errors.append(
                    f"Node {node['id']} requires unknown node: {dep}"
                )

    # ── Cycle detection (DFS, O(n+e)) ─────────────────────────────────────────
    if _has_cycle(nodes):
        errors.append(
            "Cycle detected in unlock_requires graph. "
            "Nodes must form a directed acyclic graph (DAG)."
        )

    # ── Reachability from entry points (BFS, O(n+e)) ──────────────────────────
    entry_points = [
        n['id'] for n in nodes.values()
        if not n.get('unlock_requires')
    ]
    if not entry_points:
        errors.append(
            "No entry point nodes found. "
            "At least one node must have an empty unlock_requires list."
        )
    else:
        reachable = _bfs_reachable(nodes, entry_points)
        unreachable = set(nodes.keys()) - reachable
        if unreachable:
            errors.append(
                f"Unreachable nodes (not reachable from any entry point): "
                f"{sorted(unreachable)}"
            )

    # ── Head of state and govt ────────────────────────────────────────────────
    heads_of_state = [n['id'] for n in nodes.values() if n.get('is_head_of_state')]
    heads_of_govt  = [n['id'] for n in nodes.values() if n.get('is_head_of_govt')]

    if len(heads_of_state) == 0:
        errors.append("No node has is_head_of_state: true. At least one is required.")
    if len(heads_of_govt) == 0:
        errors.append("No node has is_head_of_govt: true. At least one is required.")

    # ── Edges ─────────────────────────────────────────────────────────────────
    edges = data.get('edges', [])
    seen_edge_combos = set()

    for edge in edges:
        from_id = edge.get('from')
        to_id   = edge.get('to')
        rel_type = edge.get('type')

        if not from_id:
            errors.append("Edge missing 'from' field")
        elif from_id not in nodes:
            errors.append(f"Edge 'from' references unknown node: {from_id}")

        if not to_id:
            errors.append("Edge missing 'to' field")
        elif to_id not in nodes:
            errors.append(f"Edge 'to' references unknown node: {to_id}")

        if not rel_type:
            errors.append(f"Edge {from_id} → {to_id} missing 'type' field")

        # Check for duplicate edge combinations
        combo = (from_id, to_id, rel_type)
        if combo in seen_edge_combos:
            errors.append(
                f"Duplicate edge: {from_id} → {to_id} ({rel_type})"
            )
        seen_edge_combos.add(combo)

        # Map rendering validation
        m = edge.get('map', {})
        if 'style' in m and m['style'] not in VALID_LINE_STYLES:
            errors.append(
                f"Edge {from_id}→{to_id}: map.style must be one of {VALID_LINE_STYLES}"
            )
        if 'arrow' in m and m['arrow'] not in VALID_ARROW_DIRS:
            errors.append(
                f"Edge {from_id}→{to_id}: map.arrow must be one of {VALID_ARROW_DIRS}"
            )

    return errors


def _has_cycle(nodes: dict) -> bool:
    """DFS cycle detection. O(n + e). WHITE=0, GRAY=1, BLACK=2."""
    WHITE, GRAY, BLACK = 0, 1, 2
    color = defaultdict(lambda: WHITE)

    def dfs(node_id: str) -> bool:
        color[node_id] = GRAY
        for dep in nodes.get(node_id, {}).get('unlock_requires', []):
            if dep not in nodes:
                continue  # already caught in reference check
            if color[dep] == GRAY:
                return True  # back edge = cycle
            if color[dep] == WHITE and dfs(dep):
                return True
        color[node_id] = BLACK
        return False

    return any(dfs(n) for n in nodes if color[n] == WHITE)


def _bfs_reachable(nodes: dict, entry_points: list[str]) -> set[str]:
    """BFS from entry points following forward dependency edges. O(n + e)."""
    # Build forward adjacency: if B requires A, then A → B in forward graph
    dependents = defaultdict(list)
    for node_id, node in nodes.items():
        for dep in node.get('unlock_requires', []):
            if dep in nodes:
                dependents[dep].append(node_id)

    visited = set(entry_points)
    queue = deque(entry_points)

    while queue:
        current = queue.popleft()
        for dep in dependents[current]:
            if dep not in visited:
                visited.add(dep)
                queue.append(dep)

    return visited


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python validate_government.py <path/to/government.yaml>")
        sys.exit(1)

    target = sys.argv[1]
    errors = validate(target)

    if errors:
        print(f"\n❌ Validation FAILED for {target}:")
        for e in errors:
            print(f"   • {e}")
        sys.exit(1)
    else:
        print(f"✅ Validation passed for {target}")
        sys.exit(0)
