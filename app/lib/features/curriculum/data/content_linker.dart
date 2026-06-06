import '../../../core/database/drift/app_database.dart';
import '../domain/curriculum.dart';

/// Resolves a [CurriculumItem.id] → the actual [LocalCard] that backs it
/// in the spaced-repetition layer. Returns null when the card hasn't been
/// authored yet (the Phase 0 concept-deck backlog).
///
/// **Phase 1 status**: stub. Returns null for every item. The YAML today
/// only tags coverage type (`face_card` vs `concept`) but doesn't name
/// the specific deck or card that covers a `face_card` item. Phase 1.5
/// or Phase 2 should extend the curriculum YAML schema with explicit
/// `face_card_deck` / `face_card_ids` fields on each face-card item, then
/// flesh out [cardFor] to actually look them up.
///
/// The interface is locked in now so Phase 2 ([DailyRoundController]) can
/// consume it. Sampling logic in Phase 2 will skip items whose card lookup
/// returns null — they're invisible to the round generator until authored.
class ContentLinker {
  ContentLinker(this._db);

  final AppDatabase _db;

  /// Returns the card backing this curriculum item, or null if not yet
  /// authored / wired up.
  Future<LocalCard?> cardFor(CurriculumItem item) => cardForId(item.id);

  /// String-id variant. Useful for samplers that already have raw item
  /// ids and don't want to round-trip through [Curriculum.itemById].
  /// Same resolution rules as [cardFor].
  Future<LocalCard?> cardForId(String itemId) async {
    // First pass: exact match on LocalCards.externalId. Currently no
    // existing card uses curriculum_item_id as its external id; this is
    // here so that future concept decks can adopt the convention and
    // light up automatically when they ship.
    final byExternalId = await (_db.select(_db.localCards)
          ..where((c) => c.externalId.equals(itemId)))
        .getSingleOrNull();
    if (byExternalId != null) return byExternalId;

    // Second pass (future): explicit face_card_ids field on the
    // curriculum item. Not parsed yet.
    return null;
  }

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
