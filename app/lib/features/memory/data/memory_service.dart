import '../../../core/database/drift/app_database.dart';
import '../../session/domain/mastery.dart';

class MemoryStats {
  const MemoryStats({
    required this.totalReviewed,
    required this.masteredCount,
    required this.avgStabilityDays,
    required this.tierDistribution,
    required this.topCards,
  });

  /// Cards with reviewCount >= 1 (excluding still-new cards).
  final int totalReviewed;

  /// Cards at mastery level 5 (stability ≥ 30 days).
  final int masteredCount;

  /// Average stability across reviewed cards, in days. 0 if none reviewed.
  final double avgStabilityDays;

  /// Count of cards at each mastery tier 1..5. Index 0 is always 0 (level 0
  /// = unreviewed). Length 6.
  final List<int> tierDistribution;

  /// Cards sorted by stability descending, top N.
  final List<TopCardEntry> topCards;
}

class TopCardEntry {
  const TopCardEntry({
    required this.politicianName,
    required this.title,
    required this.photoUrl,
    required this.stability,
    required this.level,
  });

  final String politicianName;
  final String title;
  final String? photoUrl;
  final double stability;
  final int level;
}

class MemoryService {
  MemoryService(this._db);
  final AppDatabase _db;

  Future<MemoryStats> load({int topN = 8}) async {
    // Pull every memory state, filter to reviewed cards.
    final allStates = await _db.select(_db.cardMemoryStates).get();
    final reviewed = allStates.where((s) => !s.isNew).toList();

    final tierCounts = List<int>.filled(6, 0);
    var totalStability = 0.0;
    var mastered = 0;
    for (final s in reviewed) {
      final level = masteryLevelFromStability(
        isNewCard: false,
        stability: s.stability,
      );
      tierCounts[level]++;
      totalStability += s.stability;
      if (level == 5) mastered++;
    }
    final avg = reviewed.isEmpty ? 0.0 : totalStability / reviewed.length;

    // Top by stability — pull card metadata for the strongest N.
    final top = [...reviewed]
      ..sort((a, b) => b.stability.compareTo(a.stability));
    final topSlice = top.take(topN).toList();
    final cardIds = topSlice.map((s) => s.cardId).toList();
    final cards = await _db.cardsDao.cardsByIds(cardIds);
    final byId = {for (final c in cards) c.id: c};
    final topCards = <TopCardEntry>[];
    for (final s in topSlice) {
      final c = byId[s.cardId];
      if (c == null) continue;
      topCards.add(TopCardEntry(
        politicianName: c.politicianName,
        title: c.title,
        photoUrl: c.photoUrl,
        stability: s.stability,
        level: masteryLevelFromStability(
          isNewCard: false,
          stability: s.stability,
        ),
      ));
    }

    return MemoryStats(
      totalReviewed: reviewed.length,
      masteredCount: mastered,
      avgStabilityDays: avg,
      tierDistribution: tierCounts,
      topCards: topCards,
    );
  }
}
