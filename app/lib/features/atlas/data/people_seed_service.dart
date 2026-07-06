// lib/features/atlas/data/people_seed_service.dart
//
// Seeds the people reference table from the bundled legislators YAML.
// Checksum-gated like the deck seeder: unchanged content is a no-op,
// changed content replaces the table wholesale (it is pure content; no
// user state rides on it).

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import '../../../core/content/content_checksum.dart';
import '../../../core/database/drift/app_database.dart';

class PeopleSeedService {
  PeopleSeedService(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AppDatabase _db;
  final AssetBundle _bundle;

  static const _asset = 'assets/content/people/legislators.yaml';
  static const _hashKey = 'seed.people.hash';
  static const _portraitDir = 'assets/content/portraits/congress';

  Future<void> ensureSeeded() async {
    final raw = await _bundle.loadString(_asset);
    final hash = contentChecksum({_asset: raw});
    if (await _db.metaDao.get(_hashKey) == hash) return;

    final doc = loadYaml(raw);
    if (doc is! YamlMap) return;

    // Which members actually have a bundled portrait.
    final manifest = json.decode(
      await _bundle.loadString('AssetManifest.json'),
    ) as Map<String, dynamic>;
    final withPortrait = <String>{
      for (final key in manifest.keys)
        if (key.startsWith('$_portraitDir/') && key.endsWith('.jpg'))
          key.substring(_portraitDir.length + 1, key.length - 4),
    };

    final rows = <PeopleCompanion>[];
    for (final p in (doc['people'] as YamlList? ?? YamlList())
        .whereType<YamlMap>()) {
      final id = p['id'] as String;
      final chamber = p['chamber'] as String?;
      final state = p['state'] as String?;
      final district = p['district'] as int?;
      final current = p['current_term'] as YamlMap?;
      rows.add(PeopleCompanion.insert(
        id: id,
        name: p['name'] as String,
        chamber: Value(chamber),
        state: Value(state),
        district: Value(district),
        party: Value(p['party'] as String?),
        birthday: Value(p['birthday']?.toString()),
        currentRole: _roleLine(chamber, state, district),
        termStart: Value(current?['start']?.toString()),
        termEnd: Value(current?['end']?.toString()),
        officialUrl: Value(current?['url'] as String?),
        wikidataId: Value(p['wikidata'] as String?),
        portraitAsset: Value(
          withPortrait.contains(id) ? '$_portraitDir/$id.jpg' : null,
        ),
        terms: Value(json.encode(_deepConvert(p['terms']))),
        committees: Value(json.encode(_deepConvert(p['committees']))),
        citations: Value(json.encode(_deepConvert(p['citations']))),
      ),);
    }

    await _db.peopleDao.replaceAll(rows);
    await _db.metaDao.set(_hashKey, hash);
  }

  static String _roleLine(String? chamber, String? state, int? district) {
    if (chamber == 'senate') return 'United States Senator from $state';
    if (chamber == 'house') {
      if (district == null || district == 0) {
        return 'Member of the U.S. House from $state (at large)';
      }
      return 'U.S. Representative, $state district $district';
    }
    return 'Federal official';
  }

  /// YamlMap/YamlList -> plain JSON-encodable structures.
  static Object? _deepConvert(Object? node) {
    if (node is YamlMap) {
      return {
        for (final e in node.entries) e.key.toString(): _deepConvert(e.value),
      };
    }
    if (node is YamlList) return [for (final v in node) _deepConvert(v)];
    return node;
  }
}
