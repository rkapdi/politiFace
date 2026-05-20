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

    // Build 3 distractors. For "title" modes we'd ideally bias toward cards
    // with distinct titles, but in practice our pool is small enough that
    // random distractors work fine.
    final distractors = pool.where((c) => c.id != correct.id).toList()
      ..shuffle(_random);
    final options = [correct, ...distractors.take(3)]..shuffle(_random);
    final correctIndex = options.indexWhere((c) => c.id == correct.id);

    final mode = forceMode ??
        QuestionMode.values[_random.nextInt(QuestionMode.values.length)];

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
