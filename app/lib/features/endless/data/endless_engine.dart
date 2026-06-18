import 'dart:math';

import '../../../core/database/drift/app_database.dart';
import '../domain/endless_question.dart';

/// Generates a stream of MCQ questions from the active card pool. Avoids
/// repeating a card within [_recentBufferSize] picks so the same face doesn't
/// flash twice in a row.
class EndlessEngine {
  EndlessEngine(this._db, {Random? random}) : _random = random ?? Random();
  final AppDatabase _db;
  final Random _random;

  List<LocalCard>? _pool;
  final List<String> _recent = [];
  static const _recentBufferSize = 3;

  Future<List<LocalCard>> _loadPool() async {
    final cached = _pool;
    if (cached != null) return cached;
    final cards = await _db.cardsDao.allActiveCards();
    _pool = cards;
    return cards;
  }

  /// Returns null when the pool has fewer than 4 cards — MCQ needs 4 options.
  Future<EndlessQuestion?> nextQuestion({QuestionMode? forceMode}) async {
    final pool = await _loadPool();
    if (pool.length < 4) return null;

    // Pick a correct answer, avoiding recent repeats.
    var eligible = pool.where((c) => !_recent.contains(c.id)).toList();
    if (eligible.isEmpty) eligible = pool;
    eligible.shuffle(_random);
    final correct = eligible.first;
    _recent.add(correct.id);
    while (_recent.length > _recentBufferSize) {
      _recent.removeAt(0);
    }

    // Decide the format up front so title-answer questions can exclude
    // same-title distractors. Every Associate Justice shares one title, so
    // otherwise two options would both correctly answer "who holds the role
    // of Associate Justice?" and a genuinely-right pick gets marked wrong.
    final mode = forceMode ??
        QuestionMode.values[_random.nextInt(QuestionMode.values.length)];
    final titleIsAnswer =
        mode == QuestionMode.titleToWho || mode == QuestionMode.photoToTitle;
    bool eligibleDistractor(LocalCard c) =>
        c.id != correct.id && (!titleIsAnswer || c.title != correct.title);

    // Build 3 distractors. Prefer gender-matched cards (so "identify the male
    // senator" doesn't foil with women), then any title-safe card, then —
    // only if a shared-title pool can't fill three — any card, so we never
    // emit fewer than 4 options.
    final answerGender = correct.gender;
    final genderMatched = answerGender == null || answerGender == 'nonbinary'
        ? const <LocalCard>[]
        : (pool
            .where((c) => eligibleDistractor(c) && c.gender == answerGender)
            .toList()
          ..shuffle(_random));
    final titleSafe = pool.where(eligibleDistractor).toList()
      ..shuffle(_random);
    final anyCard = pool.where((c) => c.id != correct.id).toList()
      ..shuffle(_random);
    final distractors = <LocalCard>[];
    final seen = <String>{};
    for (final source in [genderMatched, titleSafe, anyCard]) {
      for (final c in source) {
        if (distractors.length == 3) break;
        if (seen.add(c.id)) distractors.add(c);
      }
      if (distractors.length == 3) break;
    }
    final options = [correct, ...distractors]..shuffle(_random);
    final correctIndex = options.indexWhere((c) => c.id == correct.id);

    return EndlessQuestion(
      mode: mode,
      correct: correct,
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// Force the pool to be reloaded on the next [nextQuestion]. Use when
  /// content changes mid-run (rare).
  void invalidatePool() => _pool = null;
}
