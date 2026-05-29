import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/database/drift/app_database.dart';

/// Fetches and caches Wikipedia summary paragraphs for politicians, keyed
/// by their Wikidata QID.
///
/// Two-hop fetch:
///   1. Wikidata `Special:EntityData/<QID>.json` → enwiki article title
///   2. Wikipedia REST `page/summary/<title>` → lead paragraph + URL
///
/// Cached forever in [PoliticianBios] (no TTL for v1 — politician bios
/// don't churn). Idempotent: re-running only touches cards that have no
/// row OR previously failed.
class WikipediaBioService {
  WikipediaBioService(this._db, {AssetBundle? bundle, HttpClient? httpClient})
      : _bundle = bundle ?? rootBundle,
        _http = httpClient ?? HttpClient() {
    _http.userAgent = 'Politiface/1.0 (politiface.app; civic literacy app)';
  }

  final AppDatabase _db;
  final AssetBundle _bundle;
  final HttpClient _http;

  static const String _manifestPath = 'assets/portraits/manifest.json';

  /// Build the cardId → wikidata-QID map from the bundled manifest.
  /// Caches on first call.
  Map<String, String>? _qidByCardId;

  Future<Map<String, String>> _qidIndex() async {
    if (_qidByCardId != null) return _qidByCardId!;
    final manifestRaw = await _bundle.loadString(_manifestPath);
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final hits = (manifest['hits'] as List?) ?? const [];

    // Manifest maps name → qid. Build a normalized-name lookup so we can
    // match against LocalCards.politicianName regardless of whitespace /
    // punctuation variation.
    final byNormName = <String, String>{};
    for (final hit in hits) {
      if (hit is! Map) continue;
      final name = hit['name'] as String?;
      final qid = hit['qid'] as String?;
      if (name == null || qid == null) continue;
      byNormName[_normalize(name)] = qid;
    }

    // Walk every active card and match by normalized name.
    final cards = await _db.cardsDao.allActiveCards();
    final out = <String, String>{};
    for (final card in cards) {
      final qid = byNormName[_normalize(card.politicianName)];
      if (qid != null) out[card.id] = qid;
    }
    _qidByCardId = out;
    return out;
  }

  /// Return the QID for a given cardId if the manifest knows it.
  Future<String?> qidFor(String cardId) async {
    final idx = await _qidIndex();
    return idx[cardId];
  }

  /// Ensure a bio is cached for [cardId]. Returns the cached row (or null
  /// if the manifest doesn't know this card's QID). Network failures are
  /// recorded as `lastError` so we don't hammer the API; the next call
  /// retries.
  Future<PoliticianBio?> ensureBio(String cardId) async {
    final existing = await _db.politicianBiosDao.get(cardId);
    // If we already have a usable extract, return it. Lets repeated screen
    // opens stay fast.
    if (existing?.bioExtract != null && existing!.bioExtract!.isNotEmpty) {
      return existing;
    }

    final qid = await qidFor(cardId);
    if (qid == null) {
      // No manifest entry — surface a row with `lastError` so UI knows we
      // tried.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.politicianBiosDao.upsert(PoliticianBiosCompanion(
        cardId: Value(cardId),
        lastError: Value(now),
        lastErrorMessage: const Value('No Wikidata QID in manifest'),
      ));
      return _db.politicianBiosDao.get(cardId);
    }

    try {
      final title = await _fetchEnwikiTitle(qid);
      if (title == null) {
        throw const FormatException('Wikidata entity has no enwiki sitelink');
      }
      final summary = await _fetchSummary(title);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.politicianBiosDao.upsert(PoliticianBiosCompanion(
        cardId: Value(cardId),
        wikidataQid: Value(qid),
        wikipediaTitle: Value(title),
        wikipediaUrl: Value(summary['url'] as String?),
        bioExtract: Value(summary['extract'] as String?),
        fetchedAt: Value(now),
        lastError: const Value(null),
        lastErrorMessage: const Value(null),
      ));
    } on Object catch (e) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.politicianBiosDao.upsert(PoliticianBiosCompanion(
        cardId: Value(cardId),
        wikidataQid: Value(qid),
        lastError: Value(now),
        lastErrorMessage: Value(e.toString()),
      ));
      if (kDebugMode) {
        debugPrint('[wiki-bio] $cardId ($qid) failed: $e');
      }
    }

    return _db.politicianBiosDao.get(cardId);
  }

  /// Backfill bios for every card the manifest knows about. Safe to call
  /// at app startup; only fetches missing rows. Errors per-card are
  /// logged but don't abort the whole pass.
  Future<int> backfillAll({int maxConcurrent = 4}) async {
    final idx = await _qidIndex();
    final ids = idx.keys.toList();
    var done = 0;
    // Crude limited-parallel loop. Drift writes serialize internally so
    // hammering it doesn't help; the network IO is the bottleneck.
    for (var i = 0; i < ids.length; i += maxConcurrent) {
      final batch = ids.skip(i).take(maxConcurrent).toList();
      await Future.wait(batch.map(ensureBio));
      done += batch.length;
    }
    return done;
  }

  // ── Wikidata: QID → enwiki title ────────────────────────────────────

  Future<String?> _fetchEnwikiTitle(String qid) async {
    final uri = Uri.parse(
      'https://www.wikidata.org/wiki/Special:EntityData/$qid.json',
    );
    final body = await _getJson(uri);
    final entities = body['entities'] as Map<String, dynamic>?;
    if (entities == null) return null;
    final entity = entities[qid] as Map<String, dynamic>?;
    if (entity == null) return null;
    final sitelinks = entity['sitelinks'] as Map<String, dynamic>?;
    final enwiki = sitelinks?['enwiki'] as Map<String, dynamic>?;
    return enwiki?['title'] as String?;
  }

  // ── Wikipedia: title → summary + URL ────────────────────────────────

  Future<Map<String, String?>> _fetchSummary(String title) async {
    final encoded = Uri.encodeComponent(title);
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/$encoded',
    );
    final body = await _getJson(uri);
    return {
      'extract': body['extract'] as String?,
      'url': (body['content_urls']?['desktop']?['page']) as String?,
    };
  }

  // ── HTTP helper ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final req = await _http.getUrl(uri);
    req.headers.add('Accept', 'application/json');
    final res = await req.close();
    if (res.statusCode != 200) {
      // Drain body so the socket can be reused.
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: uri);
    }
    final raw = await res.transform(utf8.decoder).join();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static String _normalize(String s) {
    // Lower + collapse to alphanumerics. Matches the wire_portraits.py
    // normalize() so the manifest lookups line up.
    final lower = s.toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return stripped;
  }
}
