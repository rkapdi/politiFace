import '../../../core/database/drift/app_database.dart';
import '../domain/curriculum.dart';

/// Resolves a [CurriculumItem.id] → the actual [LocalCard] that backs it
/// in the spaced-repetition layer. Returns null when the card hasn't been
/// authored yet (the Phase 0 concept-deck backlog).
///
/// Resolution rules, in order:
///   1. A concept card whose `externalId` equals the item id (concept decks
///      adopt the `id == curriculum_item_id` convention and light up
///      automatically).
///   2. The item's explicit `card_ids` list — the first active card wins,
///      in listed priority order. This is how a `face_card` item names the
///      exact face the round should drill.
///
/// Returns null when nothing matches (the item's concept card hasn't been
/// authored and it lists no backing face cards). Callers — the
/// [ChapterContentSampler] — then fall back to the broad face-card pool so
/// the round stays playable, and record the miss for diagnostics.
class ContentLinker {
  ContentLinker(this._db);

  final AppDatabase _db;

  /// Returns the card backing this curriculum item, or null if neither a
  /// matching concept card nor any of its [CurriculumItem.cardIds] exist.
  Future<LocalCard?> cardFor(CurriculumItem item) async {
    final byExternalId = await _byExternalId(item.id);
    if (byExternalId != null) return byExternalId;

    // Explicit card_ids — first active match in priority order. id is the
    // primary key, so the per-id lookup is unique; we filter inactive in Dart
    // to avoid pulling drift's boolean-expression operators in here.
    for (final cardId in item.cardIds) {
      final card = await (_db.select(_db.localCards)
            ..where((c) => c.id.equals(cardId)))
          .getSingleOrNull();
      if (card != null && card.isActive) return card;
    }
    return null;
  }

  /// String-id variant for callers that only have a raw item id (and so
  /// can't see its `card_ids`). Resolves by externalId only — prefer
  /// [cardFor] when you have the [CurriculumItem].
  Future<LocalCard?> cardForId(String itemId) => _byExternalId(itemId);

  Future<LocalCard?> _byExternalId(String itemId) =>
      (_db.select(_db.localCards)..where((c) => c.externalId.equals(itemId)))
          .getSingleOrNull();

  /// Bulk variant. Returns a map keyed by curriculum item id; missing
  /// entries mean "no card authored yet."
  Future<Map<String, LocalCard>> cardsFor(List<CurriculumItem> items) async {
    final result = <String, LocalCard>{};
    for (final item in items) {
      final card = await cardFor(item);
      if (card != null) result[item.id] = card;
    }
    return result;
  }

  /// Diagnostic helper: count how many items in [curriculum] currently
  /// resolve to a real card. Useful for content-authoring progress
  /// telemetry ("47 / 71 items have cards"). Stable across calls.
  Future<int> resolvedItemCount(Curriculum curriculum) async {
    var count = 0;
    for (final item in curriculum.allItems) {
      if ((await cardFor(item)) != null) count++;
    }
    return count;
  }
}
