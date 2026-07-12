// lib/features/fcle/domain/objective.dart
//
// An FCLE objective (competency benchmark). The FCLE has no published
// objective codes of its own; these are the Florida K-12 benchmark codes the
// FLDOE Supplemental Guide hyperlinks each topic to (see
// content/fcle/objectives.yaml for full provenance). Each objective belongs to
// exactly one of the four FCLE domains.

import 'fcle_question.dart';

class Objective {
  const Objective({
    required this.code,
    required this.domain,
    required this.description,
  });

  /// CPALMS benchmark code, e.g. "SS.912.CG.1.1". Stable identifier that
  /// question items reference via [FcleQuestion.objective].
  final String code;
  final FcleDomain domain;

  /// Plain-language description written in our own words (the official
  /// standard text is not reproduced — see the YAML header).
  final String description;
}
