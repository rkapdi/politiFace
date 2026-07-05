// lib/features/fcle/domain/fcle_question.dart
//
// FCLE exam-prep question model. The bundled YAML (public in the repo, MIT)
// carries answers and explanations; the server withholds them until an
// answer is submitted, but locally the app grades instantly and offline.

/// The four FCLE domains. Order and codes mirror the server's domains table
/// and content/questions/*.yaml. 80-question exam, 20 per domain, pass 48.
enum FcleDomain {
  americanDemocracy('american_democracy', 'American Democracy'),
  usConstitution('us_constitution', 'United States Constitution'),
  foundingDocuments('founding_documents', 'Founding Documents'),
  landmarkImpact('landmark_impact', 'Landmark Influences and Supreme Court Cases');

  const FcleDomain(this.code, this.label);

  final String code;
  final String label;

  static FcleDomain? fromCode(String code) {
    for (final d in FcleDomain.values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

class FcleOption {
  const FcleOption({required this.key, required this.text});

  final String key;
  final String text;
}

class FcleQuestion {
  const FcleQuestion({
    required this.id,
    required this.domain,
    required this.stem,
    required this.options,
    required this.answerKey,
    required this.explanation,
    required this.citation,
    required this.difficulty,
  });

  /// Stable YAML slug (e.g. usconst-article1-congress-001). Maps
  /// deterministically to the server UUID via [serverUuidForQuestion].
  final String id;
  final FcleDomain domain;
  final String stem;
  final List<FcleOption> options;
  final String answerKey;
  final String explanation;
  final String citation;
  final int difficulty;

  bool isCorrect(String chosenKey) => chosenKey == answerKey;
}
