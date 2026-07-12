// lib/features/fcle/data/question_bank_loader.dart
//
// Loads the bundled FCLE question bank (app/assets/content/questions/,
// CI-synced from the canonical content/questions/). Published questions
// only: draft and reviewed content never reaches students, mirroring the
// server's RLS rule.

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import '../domain/fcle_question.dart';

class QuestionBank {
  const QuestionBank(this.byDomain);

  final Map<FcleDomain, List<FcleQuestion>> byDomain;

  List<FcleQuestion> get all =>
      [for (final qs in byDomain.values) ...qs];

  int countFor(FcleDomain d) => byDomain[d]?.length ?? 0;

  /// The full Mock FCLE needs 20 questions per domain.
  static const perDomainForMock = 20;

  bool get canAssembleMock =>
      FcleDomain.values.every((d) => countFor(d) >= perDomainForMock);

  /// Bank readiness toward a full mock, 0..80, for the "bank growing" UI.
  int get mockBankProgress => FcleDomain.values.fold(
        0,
        (sum, d) =>
            sum +
            (countFor(d) > perDomainForMock
                ? perDomainForMock
                : countFor(d)),
      );
}

class QuestionBankLoader {
  QuestionBankLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _files = [
    'assets/content/questions/american_democracy.yaml',
    'assets/content/questions/us_constitution.yaml',
    'assets/content/questions/founding_documents.yaml',
    'assets/content/questions/landmark_impact.yaml',
  ];

  Future<QuestionBank> load() async {
    final byDomain = <FcleDomain, List<FcleQuestion>>{
      for (final d in FcleDomain.values) d: <FcleQuestion>[],
    };
    for (final path in _files) {
      final doc = loadYaml(await _bundle.loadString(path));
      if (doc is! YamlMap) continue;
      final domain = FcleDomain.fromCode(doc['domain'] as String? ?? '');
      if (domain == null) continue;
      final questions = doc['questions'];
      if (questions is! YamlList) continue;
      for (final q in questions.whereType<YamlMap>()) {
        if ((q['status'] as String? ?? 'draft') != 'published') continue;
        final options = [
          for (final o in (q['options'] as YamlList).whereType<YamlMap>())
            FcleOption(key: o['key'] as String, text: o['text'] as String),
        ];
        byDomain[domain]!.add(FcleQuestion(
          id: q['id'] as String,
          domain: domain,
          stem: (q['stem'] as String).trim(),
          options: options,
          answerKey: q['answer'] as String,
          explanation: (q['explanation'] as String).trim(),
          citation: q['citation'] as String,
          difficulty: q['difficulty'] as int? ?? 3,
          objective: q['objective'] as String?,
        ),);
      }
    }
    return QuestionBank(byDomain);
  }
}
