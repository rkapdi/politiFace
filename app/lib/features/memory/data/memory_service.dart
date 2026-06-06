import '../../../core/database/drift/app_database.dart';
import '../../session/domain/mastery.dart';

class OrbitalCard {
  const OrbitalCard({
    required this.id,
    required this.politicianName,
    required this.title,
    required this.stability,
    required this.difficulty,
    required this.lastReviewedAtUnix,
    required this.level,
  });

  final String id;
  final String politicianName;
  final String title;
  final double stability;
  final double difficulty;
  final int lastReviewedAtUnix;
  final int level; // 1..5
}

class MemoryStats {
  const MemoryStats({
    required this.totalReviewed,
    required this.totalCardsInPool,
    required this.masteredCount,
    required this.avgStabilityDays,
    required this.tierDistribution,
    required this.topCards,
    required this.orbits,
    required this.brainStrength,
  });

  /// Cards with reviewCount >= 1 (excluding still-new cards).
  final int totalReviewed;

  /// Total active cards in the deck pool — the denominator for coverage.
  /// Unreviewed cards count as mastery 0 toward the brain-strength score,
  /// so finishing a chapter actually moves the needle.
  final int totalCardsInPool;

  /// Cards at mastery level 5 (stability ≥ 30 days).
  final int masteredCount;

  /// Average stability across reviewed cards, in days. 0 if none reviewed.
  final double avgStabilityDays;

  /// Count of cards at each mastery tier 1..5. Index 0 is always 0 (level 0
  /// = unreviewed). Length 6.
  final List<int> tierDistribution;

  /// Cards sorted by stability descending, top N.
  final List<TopCardEntry> topCards;

  /// Every reviewed card with enough state to plot it in the Memory Field
  /// orbital visualization and compute its live retrievability.
  final List<OrbitalCard> orbits;

  /// 0..100 — a single "your political brain" score. Weighted average of
  /// mastery levels across the *whole* active pool (unreviewed cards count
  /// as 0). Means real growth from both depth (mastering known cards) AND
  /// breadth (encountering new ones). Drives the Memory-tab hero header.
  final double brainStrength;

  BrainStage get brainStage {
    if (brainStrength >= 75) return BrainStage.mastered;
    if (brainStrength >= 50) return BrainStage.solidifying;
    if (brainStrength >= 25) return BrainStage.crystallizing;
    return BrainStage.forming;
  }
}

/// Maturation stages for the brain-strength indicator. Each describes a
/// different point in the FSRS curve: synapses forming → memories
/// crystallizing → recall solidifying → long-term mastery.
enum BrainStage {
  forming(
    label: 'Forming',
    copy: 'Your political brain is wiring up. Keep practicing — synapses are firing.',
  ),
  crystallizing(
    label: 'Crystallizing',
    copy: 'Memories are taking shape. Each review locks the structure in tighter.',
  ),
  solidifying(
    label: 'Solidifying',
    copy: 'Recall is getting durable. The civic map is etching itself into long-term memory.',
  ),
  mastered(
    label: 'Mastered',
    copy: 'Your political brain is rock solid. Recall happens without effort.',
  );

  const BrainStage({required this.label, required this.copy});
  final String label;
  final String copy;
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

  /// Cards a few reviews away from ★5 mastery — the strongest "almost there"
  /// motivators for the home screen.
  Future<List<TopCardEntry>> approachingMastery({int limit = 3}) async {
    final allStates = await _db.select(_db.cardMemoryStates).get();
    final candidates = allStates
        .where((s) => !s.isNew)
        .where((s) {
          final lvl = masteryLevelFromStability(
            isNewCard: false,
            stability: s.stability,
          );
          // Strong but not yet mastered: tiers 3 and 4. (Skip ★1-2 — too far
          // from the milestone to feel motivating.)
          return lvl == 3 || lvl == 4;
        })
        .toList()
      ..sort((a, b) => b.stability.compareTo(a.stability));
    final slice = candidates.take(limit).toList();
    final cardIds = slice.map((s) => s.cardId).toList();
    final cards = await _db.cardsDao.cardsByIds(cardIds);
    final byId = {for (final c in cards) c.id: c};
    return [
      for (final s in slice)
        if (byId[s.cardId] != null)
          TopCardEntry(
            politicianName: byId[s.cardId]!.politicianName,
            title: byId[s.cardId]!.title,
            photoUrl: byId[s.cardId]!.photoUrl,
            stability: s.stability,
            level: masteryLevelFromStability(
              isNewCard: false,
              stability: s.stability,
            ),
          ),
    ];
  }

  Future<MemoryStats> load({int topN = 8}) async {
    // Pull every memory state, filter to reviewed cards.
    final allStates = await _db.select(_db.cardMemoryStates).get();
    final reviewed = allStates.where((s) => !s.isNew).toList();
    final activeCardCount = await _db.cardsDao.activeCardCount();

    final tierCounts = List<int>.filled(6, 0);
    var totalStability = 0.0;
    var mastered = 0;
    var masterySum = 0;
    for (final s in reviewed) {
      final level = masteryLevelFromStability(
        isNewCard: false,
        stability: s.stability,
      );
      tierCounts[level]++;
      totalStability += s.stability;
      masterySum += level;
      if (level == 5) mastered++;
    }
    final avg = reviewed.isEmpty ? 0.0 : totalStability / reviewed.length;
    // Brain strength = weighted average mastery against the FULL pool.
    // Unreviewed cards contribute 0 toward the numerator but still count
    // in the denominator so a fresh user starts near zero and the score
    // grows from both encountering cards (depth+1) and mastering them.
    final brainStrength = activeCardCount == 0
        ? 0.0
        : (masterySum / (activeCardCount * 5)) * 100.0;

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

    // Orbital entries — needs card metadata for every reviewed card, not just
    // top N. One extra cardsByIds call covers the rest.
    final allReviewedIds = reviewed.map((s) => s.cardId).toList();
    final allCards = await _db.cardsDao.cardsByIds(allReviewedIds);
    final allById = {for (final c in allCards) c.id: c};
    final orbits = <OrbitalCard>[];
    for (final s in reviewed) {
      final c = allById[s.cardId];
      if (c == null) continue;
      orbits.add(OrbitalCard(
        id: s.cardId,
        politicianName: c.politicianName,
        title: c.title,
        stability: s.stability,
        difficulty: s.difficulty,
        lastReviewedAtUnix: s.lastReviewedAt,
        level: masteryLevelFromStability(
          isNewCard: false,
          stability: s.stability,
        ),
      ));
    }

    return MemoryStats(
      totalReviewed: reviewed.length,
      totalCardsInPool: activeCardCount,
      masteredCount: mastered,
      avgStabilityDays: avg,
      tierDistribution: tierCounts,
      topCards: topCards,
      orbits: orbits,
      brainStrength: brainStrength,
    );
  }
}
