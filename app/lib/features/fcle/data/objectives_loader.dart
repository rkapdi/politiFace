// lib/features/fcle/data/objectives_loader.dart
//
// Loads the bundled FCLE objective taxonomy (app/assets/content/fcle/
// objectives.yaml, CI-synced from the canonical content/fcle/objectives.yaml).
// The 32 objectives are grouped into the four FCLE domains.

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import '../domain/fcle_question.dart';
import '../domain/objective.dart';

class ObjectivesLoader {
  ObjectivesLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _path = 'assets/content/fcle/objectives.yaml';

  Future<List<Objective>> load() async {
    final doc = loadYaml(await _bundle.loadString(_path));
    if (doc is! YamlMap) return const [];
    final list = doc['objectives'];
    if (list is! YamlList) return const [];
    final result = <Objective>[];
    for (final o in list.whereType<YamlMap>()) {
      final domain = FcleDomain.fromCode(o['domain'] as String? ?? '');
      final code = o['code'] as String?;
      if (domain == null || code == null) continue;
      result.add(
        Objective(
          code: code,
          domain: domain,
          description: (o['description'] as String? ?? '').trim(),
        ),
      );
    }
    return result;
  }
}
