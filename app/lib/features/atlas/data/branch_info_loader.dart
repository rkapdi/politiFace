import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// One branch's library blurb. Rendered by the BranchInfoSheet when the
/// user taps a branch header in the Atlas.
class BranchInfo {
  const BranchInfo({
    required this.id,
    required this.title,
    required this.short,
    required this.summary,
    required this.quickFacts,
    required this.relatedChapterIds,
  });

  /// Atlas branch id (e.g. `atlas-legislative`) — matches AtlasBranch.id.
  final String id;
  final String title;

  /// One-sentence headline ("Congress — the lawmakers.").
  final String short;

  /// 2-3 sentence paragraph that explains what the branch is + does.
  final String summary;

  /// 3-5 short bullet facts.
  final List<String> quickFacts;

  /// Curriculum chapter ids that touch this branch. Lets the sheet link
  /// "see more in Chapter X."
  final List<String> relatedChapterIds;
}

class BranchInfoLibrary {
  const BranchInfoLibrary(this._byId);
  final Map<String, BranchInfo> _byId;

  BranchInfo? forId(String atlasBranchId) => _byId[atlasBranchId];

  Iterable<BranchInfo> get all => _byId.values;
}

class BranchInfoLoader {
  BranchInfoLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String _assetPath = 'assets/content/atlas/branch_info.yaml';

  Future<BranchInfoLibrary> load() async {
    final raw = await _bundle.loadString(_assetPath);
    final root = loadYaml(raw);
    if (root is! Map) {
      throw StateError('branch_info.yaml: root must be a map');
    }
    final list = root['branches'];
    if (list is! List) {
      throw StateError('branch_info.yaml: missing branches list');
    }
    final out = <String, BranchInfo>{};
    for (final entry in list) {
      if (entry is! Map) continue;
      final id = entry['id'] as String?;
      if (id == null) continue;
      out[id] = BranchInfo(
        id: id,
        title: entry['title'] as String? ?? id,
        short: entry['short'] as String? ?? '',
        summary: entry['summary'] as String? ?? '',
        quickFacts: [
          for (final f in entry['quick_facts'] as List<dynamic>? ?? const [])
            '$f',
        ],
        relatedChapterIds: [
          for (final c
              in entry['related_chapters'] as List<dynamic>? ?? const [])
            '$c',
        ],
      );
    }
    return BranchInfoLibrary(out);
  }
}
