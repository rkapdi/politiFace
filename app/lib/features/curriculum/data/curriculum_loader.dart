import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../domain/curriculum.dart';

/// Loads and parses the bundled US civics curriculum YAML.
///
/// One file, one source of truth: `assets/content/curriculum/us_civics.yaml`.
/// Parse happens once per app launch (cached by the provider layer).
/// Throws [CurriculumLoadException] with a descriptive message on any
/// schema problem — failures here are developer errors, not user errors,
/// so we surface them loudly.
class CurriculumLoader {
  CurriculumLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String _assetPath =
      'assets/content/curriculum/us_civics.yaml';

  Future<Curriculum> load() async {
    final raw = await _bundle.loadString(_assetPath);
    final root = loadYaml(raw);
    if (root is! Map) {
      throw CurriculumLoadException(
        'Root of $_assetPath must be a YAML map, got ${root.runtimeType}.',
      );
    }
    return _parse(root);
  }

  Curriculum _parse(Map<dynamic, dynamic> root) {
    final version = (root['version'] as int?) ?? 1;
    final locale = (root['locale'] as String?) ?? 'en-US';

    final season = _parseSeason(root['season'] as Map<dynamic, dynamic>?);
    final branches = _parseBranches(root['branches'] as List<dynamic>?);
    final chapters = _parseChapters(root['chapters'] as List<dynamic>?);

    // Validate that every item_id in every chapter resolves to an actual
    // curriculum item declared under some branch. Catches typos before they
    // become silent runtime sampling holes.
    final allItemIds = <String>{
      for (final b in branches)
        for (final n in b.conceptNodes)
          for (final i in n.items) i.id,
    };
    final missing = <String>[];
    for (final ch in chapters) {
      for (final id in ch.itemIds) {
        if (!allItemIds.contains(id)) missing.add('${ch.id} -> $id');
      }
    }
    if (missing.isNotEmpty) {
      throw CurriculumLoadException(
        'Chapter references unknown curriculum item(s): '
        '${missing.join(", ")}',
      );
    }

    return Curriculum(
      version: version,
      locale: locale,
      season: season,
      chapters: chapters,
      branches: branches,
    );
  }

  Season _parseSeason(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
      throw const CurriculumLoadException('Missing top-level `season` map.');
    }
    return Season(
      id: _requiredString(raw, 'id', context: 'season'),
      title: _requiredString(raw, 'title', context: 'season'),
      subtitle: _requiredString(raw, 'subtitle', context: 'season'),
      totalChapters: _requiredInt(raw, 'total_chapters', context: 'season'),
      estimatedDays: _requiredInt(raw, 'estimated_days', context: 'season'),
    );
  }

  List<Chapter> _parseChapters(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      throw const CurriculumLoadException('Missing or empty `chapters` list.');
    }
    return [
      for (final entry in raw)
        if (entry is Map) _parseChapter(entry),
    ];
  }

  Chapter _parseChapter(Map<dynamic, dynamic> raw) {
    final id = _requiredString(raw, 'id', context: 'chapter');
    return Chapter(
      id: id,
      order: _requiredInt(raw, 'order', context: 'chapter[$id]'),
      title: _requiredString(raw, 'title', context: 'chapter[$id]'),
      subtitle: _requiredString(raw, 'subtitle', context: 'chapter[$id]'),
      days: _requiredInt(raw, 'days', context: 'chapter[$id]'),
      itemIds: _stringList(raw['item_ids'], 'chapter[$id].item_ids'),
    );
  }

  List<Branch> _parseBranches(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      throw const CurriculumLoadException('Missing or empty `branches` list.');
    }
    return [
      for (final entry in raw)
        if (entry is Map) _parseBranch(entry),
    ];
  }

  Branch _parseBranch(Map<dynamic, dynamic> raw) {
    final id = _requiredString(raw, 'id', context: 'branch');
    final nodes = (raw['concept_nodes'] as List<dynamic>?) ?? const [];
    return Branch(
      id: id,
      title: _requiredString(raw, 'title', context: 'branch[$id]'),
      color: _requiredString(raw, 'color', context: 'branch[$id]'),
      description: raw['description'] as String?,
      conceptNodes: [
        for (final n in nodes)
          if (n is Map) _parseConceptNode(n, branchId: id),
      ],
    );
  }

  ConceptNode _parseConceptNode(Map<dynamic, dynamic> raw, {required String branchId}) {
    final id = _requiredString(raw, 'id', context: 'concept_node($branchId)');
    final items = (raw['items'] as List<dynamic>?) ?? const [];
    return ConceptNode(
      id: id,
      title: _requiredString(raw, 'title', context: 'concept_node[$id]'),
      items: [
        for (final i in items)
          if (i is Map) _parseItem(i, nodeId: id),
      ],
    );
  }

  CurriculumItem _parseItem(Map<dynamic, dynamic> raw, {required String nodeId}) {
    final id = _requiredString(raw, 'id', context: 'item($nodeId)');
    return CurriculumItem(
      id: id,
      prompt: _requiredString(raw, 'prompt', context: 'item[$id]'),
      tier: _parseTier(raw['tier'], itemId: id),
      sources: _parseSources(raw['sources'], itemId: id),
      coverage: _parseCoverage(raw['coverage'], itemId: id),
      crossLinks: _stringList(raw['cross_links'], 'item[$id].cross_links',
          allowMissing: true,),
    );
  }

  CurriculumTier _parseTier(Object? raw, {required String itemId}) {
    final s = (raw as String?)?.toLowerCase() ?? 'standard';
    switch (s) {
      case 'core':
        return CurriculumTier.core;
      case 'standard':
        return CurriculumTier.standard;
      case 'nice-to-have':
      case 'nice_to_have':
      case 'nicetohave':
        return CurriculumTier.niceToHave;
      default:
        throw CurriculumLoadException(
          'item[$itemId]: unknown tier "$s" (expected core|standard|nice-to-have).',
        );
    }
  }

  List<CurriculumSource> _parseSources(Object? raw, {required String itemId}) {
    if (raw is! List) {
      throw CurriculumLoadException(
        'item[$itemId]: `sources` must be a list, got ${raw.runtimeType}.',
      );
    }
    return [
      for (final s in raw) _parseSource('$s', itemId: itemId),
    ];
  }

  CurriculumSource _parseSource(String s, {required String itemId}) {
    switch (s.toUpperCase()) {
      case 'U':
      case 'USCIS':
        return CurriculumSource.uscis;
      case 'F':
      case 'FCLE':
        return CurriculumSource.fcle;
      case 'A':
      case 'AP':
        return CurriculumSource.apGov;
      case 'N':
      case 'NAEP':
        return CurriculumSource.naep;
      case 'I':
      case 'ICIVICS':
        return CurriculumSource.iCivics;
      default:
        throw CurriculumLoadException(
          'item[$itemId]: unknown source "$s" (expected U|F|A|N|I).',
        );
    }
  }

  ItemCoverage _parseCoverage(Object? raw, {required String itemId}) {
    final s = (raw as String?)?.toLowerCase() ?? 'concept';
    switch (s) {
      case 'face_card':
      case 'facecard':
        return ItemCoverage.faceCard;
      case 'concept':
        return ItemCoverage.concept;
      case 'mixed':
        return ItemCoverage.mixed;
      default:
        throw CurriculumLoadException(
          'item[$itemId]: unknown coverage "$s" (expected face_card|concept|mixed).',
        );
    }
  }

  // ── Field helpers ─────────────────────────────────────────────────────

  String _requiredString(Map<dynamic, dynamic> raw, String key, {required String context}) {
    final v = raw[key];
    if (v is! String || v.isEmpty) {
      throw CurriculumLoadException(
        '$context: required field `$key` missing or not a non-empty string.',
      );
    }
    return v;
  }

  int _requiredInt(Map<dynamic, dynamic> raw, String key, {required String context}) {
    final v = raw[key];
    if (v is! int) {
      throw CurriculumLoadException(
        '$context: required field `$key` missing or not an int.',
      );
    }
    return v;
  }

  List<String> _stringList(Object? raw, String context,
      {bool allowMissing = false,}) {
    if (raw == null) {
      if (allowMissing) return const [];
      throw CurriculumLoadException('$context: missing.');
    }
    if (raw is! List) {
      throw CurriculumLoadException(
        '$context: must be a list, got ${raw.runtimeType}.',
      );
    }
    return [for (final v in raw) '$v'];
  }
}

class CurriculumLoadException implements Exception {
  const CurriculumLoadException(this.message);
  final String message;

  @override
  String toString() => 'CurriculumLoadException: $message';
}
