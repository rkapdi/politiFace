import 'dart:math';

import '../../../core/database/drift/app_database.dart';
import '../../curriculum/data/content_linker.dart';
import '../../curriculum/domain/curriculum.dart';

/// Samples flashcards + trivia source-cards from a [Chapter]'s item pool,
/// resolving curriculum items to real database cards via [ContentLinker].
///
/// Phase 2 reality: most curriculum items resolve to null today because
/// the concept-deck content (Phase 0 work) hasn't been authored. The
/// sampler handles this gracefully:
///   - Resolves what it can from the chapter
///   - Optionally falls back to face-card content from existing decks
///     when chapter resolution yields too few cards
///   - Returns a [SampledContent] describing both what landed and what
///     didn't (for UI "content coming soon" states and diagnostics)
///
/// Sampling order today is deterministic-by-date — same date produces the
/// same sample, so backgrounding/reopening shows the same round. FSRS-due
/// bias (cards) and coverage bias (trivia) will land in a future patch
/// once concept-deck resolution is real.
class ChapterContentSampler {
  ChapterContentSampler(this._db, this._linker);

  final AppDatabase _db;
  final ContentLinker _linker;

  /// Samples [count] cards from [chapter]. When the chapter's resolved
  /// pool is smaller than [count] and [allowFallback] is true, top up
  /// from active face-card decks (least-recently-reviewed first) so the
  /// round can still play during the Phase 0 content gap.
  Future<SampledContent> sampleCards({
    required Chapter chapter,
    required int count,
    required String dateIso,
    bool allowFallback = true,
  }) async => _sample(
      chapter: chapter,
      count: count,
      dateIso: dateIso,
      saltSuffix: 'cards',
      allowFallback: allowFallback,
    );

  /// Samples [count] cards to seed trivia questions from. Same shape as
  /// [sampleCards] but with a different deterministic seed so a single
  /// day's cards-phase and trivia-phase pull different subsets of the
  /// same chapter (rather than asking about the same card twice).
  Future<SampledContent> sampleTrivia({
    required Chapter chapter,
    required int count,
    required String dateIso,
    bool allowFallback = true,
  }) async => _sample(
      chapter: chapter,
      count: count,
      dateIso: dateIso,
      saltSuffix: 'trivia',
      allowFallback: allowFallback,
    );

  Future<SampledContent> _sample({
    required Chapter chapter,
    required int count,
    required String dateIso,
    required String saltSuffix,
    required bool allowFallback,
  }) async {
    final seed = _seedFor(dateIso, chapter.id, saltSuffix);
    final rng = Random(seed);

    // Resolve every chapter item against the card database; collect the
    // hits and remember the misses for diagnostics.
    final resolved = <_ResolvedItem>[];
    final missingItemIds = <String>[];
    for (final itemId in chapter.itemIds) {
      final card = await _resolveItemId(itemId);
      if (card != null) {
        resolved.add(_ResolvedItem(itemId: itemId, card: card));
      } else {
        missingItemIds.add(itemId);
      }
    }

    // Deterministic shuffle, then take the front.
    resolved.shuffle(rng);
    final picked = resolved.take(count).toList();

    // If the chapter resolved fewer cards than asked for and we're allowed
    // to fall back, top up from any active card not already picked. This
    // keeps the round playable during the Phase 0 authoring gap.
    if (picked.length < count && allowFallback) {
      final usedCardIds = picked.map((r) => r.card.id).toSet();
      final pool = await _db.cardsDao.allActiveFaceCards();
      final available = pool.where((c) => !usedCardIds.contains(c.id)).toList()
        ..shuffle(rng);
      final needed = count - picked.length;
      for (final card in available.take(needed)) {
        picked.add(_ResolvedItem(itemId: null, card: card));
      }
    }

    return SampledContent(
      cards: picked.map((r) => r.card).toList(),
      sourceItemIds: picked.map((r) => r.itemId).toList(),
      unresolvedItemIds: missingItemIds,
    );
  }

  Future<LocalCard?> _resolveItemId(String itemId) =>
      _linker.cardForId(itemId);

  /// Deterministic seed: same date + chapter + phase → same shuffle.
  int _seedFor(String dateIso, String chapterId, String saltSuffix) {
    final s = '$dateIso|$chapterId|$saltSuffix';
    var hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }
}

/// Result of a sampling pass. [cards] is what we'll use; the two ID lists
/// are for telemetry / "content coming soon" UI.
class SampledContent {
  const SampledContent({
    required this.cards,
    required this.sourceItemIds,
    required this.unresolvedItemIds,
  });

  /// The cards selected for the round. Same length as [sourceItemIds].
  /// Length may be less than the requested count when the chapter is
  /// content-sparse AND fallback is disabled.
  final List<LocalCard> cards;

  /// Per-card provenance: the curriculum item id this card was sampled
  /// for, or null when the card came from the fallback pool. Same length
  /// as [cards].
  final List<String?> sourceItemIds;

  /// Chapter items that couldn't be resolved to any card. Diagnostic — UI
  /// can use this to show a "X concept cards coming in v1.1" hint, and we
  /// can track it as a content-authoring progress metric.
  final List<String> unresolvedItemIds;

  bool get isEmpty => cards.isEmpty;
  int get resolvedCount => cards.length;
}

class _ResolvedItem {
  const _ResolvedItem({required this.itemId, required this.card});
  final String? itemId;
  final LocalCard card;
}
