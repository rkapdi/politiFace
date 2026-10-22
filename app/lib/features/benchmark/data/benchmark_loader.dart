import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../domain/benchmark.dart';

/// Loads and parses the bundled national civics-knowledge benchmarks.
///
/// One file: `assets/content/curriculum/benchmarks.yaml`. Parse happens once
/// per launch (cached by the provider layer). Throws [BenchmarkLoadException]
/// on any schema problem — these are developer errors surfaced loudly so a
/// malformed or unsourced benchmark can't ship silently.
class BenchmarkLoader {
  BenchmarkLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const String _assetPath =
      'assets/content/curriculum/benchmarks.yaml';

  Future<Benchmarks> load() async {
    final raw = await _bundle.loadString(_assetPath);
    final root = loadYaml(raw);
    if (root is! Map) {
      throw BenchmarkLoadException(
        'Root of $_assetPath must be a YAML map, got ${root.runtimeType}.',
      );
    }
    final list = root['benchmarks'];
    if (list is! List) {
      throw const BenchmarkLoadException(
        'benchmarks.yaml: `benchmarks` must be a list.',
      );
    }
    final seen = <String>{};
    final parsed = <Benchmark>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      final b = _parse(entry);
      if (!seen.add(b.id)) {
        throw BenchmarkLoadException('Duplicate benchmark id "${b.id}".');
      }
      parsed.add(b);
    }
    return Benchmarks(parsed);
  }

  Benchmark _parse(Map<dynamic, dynamic> raw) {
    final id = _str(raw, 'id', context: 'benchmark');
    final chapterIds = raw['chapter_ids'];
    if (chapterIds is! List || chapterIds.isEmpty) {
      throw BenchmarkLoadException(
        'benchmark[$id]: `chapter_ids` must be a non-empty list.',
      );
    }
    return Benchmark(
      id: id,
      chapterIds: [for (final c in chapterIds) '$c'],
      stat: _str(raw, 'stat', context: 'benchmark[$id]'),
      youLine: _str(raw, 'you_line', context: 'benchmark[$id]'),
      source: _str(raw, 'source', context: 'benchmark[$id]'),
      year: _int(raw, 'year', context: 'benchmark[$id]'),
      url: raw['url'] as String?,
    );
  }

  String _str(
    Map<dynamic, dynamic> raw,
    String key, {
    required String context,
  }) {
    final v = raw[key];
    if (v is! String || v.trim().isEmpty) {
      throw BenchmarkLoadException(
        '$context: required field `$key` missing or empty.',
      );
    }
    return v.trim();
  }

  int _int(Map<dynamic, dynamic> raw, String key, {required String context}) {
    final v = raw[key];
    if (v is! int) {
      throw BenchmarkLoadException(
        '$context: required field `$key` must be an integer.',
      );
    }
    return v;
  }
}

class BenchmarkLoadException implements Exception {
  const BenchmarkLoadException(this.message);
  final String message;
  @override
  String toString() => 'BenchmarkLoadException: $message';
}
