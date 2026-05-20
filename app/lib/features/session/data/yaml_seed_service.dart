import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../../../core/database/drift/app_database.dart';

/// Reads every deck YAML file bundled under `assets/content/decks/` and
/// upserts decks + cards into Drift. Card memory state is only initialized
/// the first time a card is seen so existing user progress is preserved.
///
/// Bump [_flagKey] when the YAML schema itself changes; for *content* edits
/// you don't need to bump — re-running the service on app launch picks up
/// renames / new cards via upsert (memory state never touched for
/// already-seen cards).
class YamlSeedService {
  YamlSeedService(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AppDatabase _db;
  final AssetBundle _bundle;

  static const _flagKey = 'yaml_seed_v1_done';
  static const _deckPrefix = 'assets/content/decks/';

  Future<void> ensureSeeded() async {
    final flag = await _db.metaDao.get(_flagKey);
    final firstRun = flag != '1';

    final manifest = await _loadManifest();
    final deckPaths = manifest.keys
        .where((p) => p.startsWith(_deckPrefix) && p.endsWith('.yaml'))
        .toList()
      ..sort();
    if (deckPaths.isEmpty) return;

    await _db.transaction(() async {
      for (final path in deckPaths) {
        final raw = await _bundle.loadString(path);
        final yaml = loadYaml(raw);
        if (yaml is! Map) continue;
        await _seedDeck(yaml, firstRun: firstRun);
      }
      await _db.metaDao.set(_flagKey, '1');
    });
  }

  Future<Map<String, dynamic>> _loadManifest() async {
    final json = await _bundle.loadString('AssetManifest.json');
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> _seedDeck(Map yaml, {required bool firstRun}) async {
    final meta = yaml['meta'] as Map?;
    if (meta == null) return;
    final deckExternalId = meta['external_id'] as String? ?? meta['id'] as String?;
    final deckName = meta['name'] as String?;
    if (deckExternalId == null || deckName == null) return;

    final deckId = 'deck_$deckExternalId';
    final nodeId = meta['node_id'] as String?;
    final tierOrder = (meta['tier_order'] as num?)?.toInt() ?? 0;
    final cards = (yaml['cards'] as List?) ?? const [];
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _db.decksDao.upsertDeck(LocalDecksCompanion.insert(
      id: deckId,
      externalId: deckExternalId,
      name: deckName,
      nodeId: Value(nodeId),
      tierOrder: Value(tierOrder),
      cardCount: Value(cards.length),
      updatedAt: nowSeconds,
    ));

    for (var i = 0; i < cards.length; i++) {
      final raw = cards[i];
      if (raw is! Map) continue;
      final cardId = raw['id'] as String?;
      final name = raw['name'] as String?;
      final title = raw['title'] as String?;
      if (cardId == null || name == null || title == null) continue;

      await _db.cardsDao.upsertCard(LocalCardsCompanion.insert(
        id: cardId,
        deckId: deckId,
        externalId: cardId,
        politicianName: name,
        title: title,
        party: Value(raw['party'] as String?),
        jurisdiction: Value(raw['jurisdiction'] as String? ?? 'US Federal'),
        oneLiner: Value(raw['one_liner'] as String?),
        photoUrl: Value(raw['photo_url'] as String?),
        sourceUrl: raw['source'] as String? ?? '',
        sortOrder: Value(i),
        updatedAt: nowSeconds,
      ));

      // Only init memory state if this card is genuinely new. Re-seeding a
      // YAML edit must not wipe a user's review history.
      final existing = await _db.reviewsDao.stateFor(cardId);
      if (existing == null) {
        await _db.reviewsDao.upsertState(
          CardMemoryStatesCompanion(
            cardId: Value(cardId),
            isNew: const Value(true),
          ),
        );
      }

      // Suppress unused-variable warning for firstRun.
      // Keeping it in signature in case a future patch needs it.
      // ignore: unused_local_variable
      final _ = firstRun;
    }
  }
}
