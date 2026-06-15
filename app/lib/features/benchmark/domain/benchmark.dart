/// A single national civics-knowledge statistic, surfaced at the end of a
/// daily round to give the player a "most people don't know this" moment.
///
/// Every value originates from a named public survey — see the authoring
/// rules in `assets/content/curriculum/benchmarks.yaml`. Pure value type, no
/// Flutter/Drift dependencies.
class Benchmark {
  const Benchmark({
    required this.id,
    required this.chapterIds,
    required this.stat,
    required this.youLine,
    required this.source,
    required this.year,
    this.url,
  });

  final String id;

  /// Curriculum chapter ids this stat is topically relevant to. The reveal
  /// screen matches the chapter just played against this list.
  final List<String> chapterIds;

  /// The national figure, phrased to highlight the knowledge gap. Shown
  /// verbatim on the reveal screen and the share card.
  final String stat;

  /// A short, honest encouragement that caps the stat on the reveal screen.
  final String youLine;

  /// Survey name for attribution.
  final String source;
  final int year;

  /// Source URL (optional but expected for every authored benchmark).
  final String? url;

  /// "Annenberg Constitution Day Civics Survey, 2025"
  String get attribution => '$source, $year';
}

/// Loaded set of benchmarks with chapter-aware, date-stable selection.
class Benchmarks {
  const Benchmarks(this.all);
  final List<Benchmark> all;

  bool get isEmpty => all.isEmpty;

  /// The benchmark to show for [chapterId], deterministic for a given
  /// [dateIso] so it stays stable across re-opens of the same round. Returns
  /// null when no benchmark is keyed to that chapter.
  Benchmark? forChapter(String chapterId, {required String dateIso}) {
    final matches = [
      for (final b in all)
        if (b.chapterIds.contains(chapterId)) b,
    ];
    if (matches.isEmpty) return null;
    return matches[_hash('$dateIso|$chapterId') % matches.length];
  }

  static int _hash(String s) {
    var hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }
}
