// lib/features/atlas/data/atlas_reference_loader.dart
//
// The Atlas reference layer beyond the government graph: executive orders
// (fetched from the Federal Register into canonical YAML by
// scripts/fetch_executive_orders.py) and the cited civic vocabulary.
// Bundled copies are CI-synced from content/atlas/.

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

class ExecutiveOrder {
  const ExecutiveOrder({
    required this.number,
    required this.title,
    required this.president,
    required this.signingDate,
    required this.url,
    this.federalRegisterCitation,
    this.abstractText,
  });

  final int number;
  final String title;
  final String president;
  final String signingDate; // ISO yyyy-mm-dd
  final String url;
  final String? federalRegisterCitation;
  final String? abstractText;
}

class CivicTerm {
  const CivicTerm({
    required this.id,
    required this.term,
    required this.definition,
    required this.citation,
    this.domain,
  });

  final String id;
  final String term;
  final String definition;
  final String citation;
  final String? domain; // FCLE domain code, when the term maps to one
}

class AtlasReference {
  const AtlasReference({
    required this.orders,
    required this.terms,
    required this.ordersUpdated,
  });

  /// Newest first (the YAML is already sorted by EO number descending).
  final List<ExecutiveOrder> orders;

  /// Alphabetical by term.
  final List<CivicTerm> terms;

  /// The `updated:` stamp from the fetcher run, shown as data provenance.
  final String? ordersUpdated;
}

class AtlasReferenceLoader {
  AtlasReferenceLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _ordersAsset = 'assets/content/atlas/executive_orders.yaml';
  static const _vocabularyAsset = 'assets/content/atlas/vocabulary.yaml';

  Future<AtlasReference> load() async {
    final ordersDoc = loadYaml(await _bundle.loadString(_ordersAsset));
    final vocabDoc = loadYaml(await _bundle.loadString(_vocabularyAsset));

    final orders = <ExecutiveOrder>[];
    if (ordersDoc is YamlMap) {
      for (final o in (ordersDoc['orders'] as YamlList? ?? YamlList())
          .whereType<YamlMap>()) {
        final number = o['eo_number'];
        final url = o['url'];
        if (number is! int || url is! String) continue;
        orders.add(ExecutiveOrder(
          number: number,
          title: (o['title'] as String? ?? '').trim(),
          president: o['president'] as String? ?? '',
          signingDate: o['signing_date'] as String? ?? '',
          url: url,
          federalRegisterCitation: o['federal_register_citation'] as String?,
          abstractText: o['abstract'] as String?,
        ),);
      }
    }

    final terms = <CivicTerm>[];
    if (vocabDoc is YamlMap) {
      for (final t in (vocabDoc['terms'] as YamlList? ?? YamlList())
          .whereType<YamlMap>()) {
        terms.add(CivicTerm(
          id: t['id'] as String,
          term: (t['term'] as String).trim(),
          definition: (t['definition'] as String).trim(),
          citation: t['citation'] as String,
          domain: t['domain'] as String?,
        ),);
      }
    }
    terms.sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

    return AtlasReference(
      orders: orders,
      terms: terms,
      ordersUpdated:
          ordersDoc is YamlMap ? ordersDoc['updated']?.toString() : null,
    );
  }
}

final atlasReferenceProvider = FutureProvider<AtlasReference>(
  (ref) => AtlasReferenceLoader().load(),
);
