/// Typed models for the parsed `us_civics.yaml` curriculum.
///
/// Pure value types — no Flutter / Drift / Riverpod dependencies. Created
/// once by [CurriculumLoader] and held in memory; mutations to user
/// progress live in Drift via [ChapterProgressService].
///
/// Vocabulary:
///   - [Season] is the player-facing arc (right now just one — "Civic
///     Foundations"). Future locales / topics get new seasons.
///   - [Chapter] is the curated narrative bucket the player walks through
///     day by day (~6 per season).
///   - [Branch] is the content-taxonomy bucket that mirrors the map's
///     existing top-level structure (Foundations, Legislative, Executive,
///     Judicial, State and Local).
///   - [ConceptNode] is a map-renderable sub-node inside a branch
///     (e.g., "The Constitution" inside Foundations).
///   - [CurriculumItem] is a single atomic testable fact. It belongs to
///     exactly one [ConceptNode] (for the map) and exactly one [Chapter]
///     (for the daily round). The chapter/branch axes are independent.
class Curriculum {
  Curriculum({
    required this.version,
    required this.locale,
    required this.season,
    required this.chapters,
    required this.branches,
  })  : _itemsById = _indexItems(branches),
        _chapterByItem = _indexChapterByItem(chapters);

  final int version;
  final String locale;
  final Season season;
  final List<Chapter> chapters;
  final List<Branch> branches;

  /// Flat lookup: curriculum item id → [CurriculumItem]. O(1).
  final Map<String, CurriculumItem> _itemsById;

  /// Reverse index: curriculum item id → owning [Chapter]. O(1).
  /// Used by the question picker to figure out which chapter an item belongs
  /// to (e.g., for cross-chapter FSRS reinforcement weighting).
  final Map<String, Chapter> _chapterByItem;

  /// All items across all branches as a flat iterable. Order matches branch
  /// declaration order in the YAML.
  Iterable<CurriculumItem> get allItems => _itemsById.values;

  /// Total item count — the moat metric. ~80 for US Civics v1.
  int get itemCount => _itemsById.length;

  CurriculumItem? itemById(String id) => _itemsById[id];

  Chapter? chapterById(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  Chapter? chapterForItem(String itemId) => _chapterByItem[itemId];

  Branch? branchById(String id) {
    for (final b in branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Returns the next chapter after [chapterId], or null if it's the last.
  Chapter? chapterAfter(String chapterId) {
    final idx = chapters.indexWhere((c) => c.id == chapterId);
    if (idx < 0 || idx >= chapters.length - 1) return null;
    return chapters[idx + 1];
  }

  static Map<String, CurriculumItem> _indexItems(List<Branch> branches) {
    final map = <String, CurriculumItem>{};
    for (final branch in branches) {
      for (final node in branch.conceptNodes) {
        for (final item in node.items) {
          map[item.id] = item;
        }
      }
    }
    return map;
  }

  static Map<String, Chapter> _indexChapterByItem(List<Chapter> chapters) {
    final map = <String, Chapter>{};
    for (final chapter in chapters) {
      for (final id in chapter.itemIds) {
        map[id] = chapter;
      }
    }
    return map;
  }
}

/// The player-facing arc. Today there is one season ("Civic Foundations");
/// future content adds more.
class Season {
  const Season({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.totalChapters,
    required this.estimatedDays,
  });

  final String id;
  final String title;
  final String subtitle;
  final int totalChapters;
  final int estimatedDays;
}

/// A narratively-ordered chapter inside a [Season]. Pulls items from
/// multiple [Branch]es — chapters narrate a story, branches organize
/// content.
class Chapter {
  const Chapter({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.days,
    required this.itemIds,
  });

  final String id;

  /// 1-based position in the season's chapter list.
  final int order;
  final String title;
  final String subtitle;

  /// Recommended pace: number of daily rounds to fully traverse this
  /// chapter's items. Drives the "Day X of Y" home-screen indicator.
  final int days;

  /// Curriculum item ids this chapter samples from. Each id must resolve
  /// against [Curriculum.itemById] — [CurriculumLoader] validates this.
  final List<String> itemIds;
}

/// A top-level taxonomy bucket. Mirrors the map's existing branch structure
/// (Foundations is the new fifth branch added by Phase 1).
class Branch {
  const Branch({
    required this.id,
    required this.title,
    required this.color,
    required this.conceptNodes,
    this.description,
  });

  final String id;
  final String title;

  /// Editorial-theme palette token. Matches one of:
  /// `ochre`, `civicNavy`, `actionRed`, `civicGreen`, `civicLight`.
  final String color;
  final String? description;
  final List<ConceptNode> conceptNodes;
}

/// A map-renderable sub-node inside a [Branch]. Holds a bundle of related
/// [CurriculumItem]s (typically 3-6) that share a theme.
class ConceptNode {
  const ConceptNode({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<CurriculumItem> items;
}

/// A single atomic testable fact. The unit the question picker samples and
/// the trivia generator turns into a 4-option MCQ.
class CurriculumItem {
  const CurriculumItem({
    required this.id,
    required this.prompt,
    required this.tier,
    required this.sources,
    required this.coverage,
    this.crossLinks = const [],
  });

  final String id;

  /// One-line human-readable description of the fact this item teaches.
  /// Used as the front of the concept flashcard and the basis for the
  /// trivia question stem.
  final String prompt;

  /// Priority signal — drives sampling weight and v1 vs. v1.1 inclusion.
  final CurriculumTier tier;

  /// Which canonical exam sources test this item (USCIS, FCLE, AP, NAEP,
  /// iCivics). Lets us filter by audience later (e.g., "USCIS-prep mode").
  final List<CurriculumSource> sources;

  /// Whether the item is already covered by an existing face-card deck or
  /// needs a brand-new concept flashcard authored. Drives the Phase 0
  /// content backlog.
  final ItemCoverage coverage;

  /// Other concept node ids that should surface this item as a "see also".
  /// Used by the map to draw cross-links between related concepts (e.g.,
  /// Federalism in Foundations + State-and-Local).
  final List<String> crossLinks;
}

/// Curriculum-source priority tier.
enum CurriculumTier {
  /// Appears in 3+ sources. Non-negotiable for v1.
  core,

  /// Appears in 2 sources. Strong v1 fill, v1.1 floor.
  standard,

  /// Appears in 1 source. Specialized; deferred unless we target that
  /// audience explicitly.
  niceToHave,
}

/// Which canonical civics curriculum source tests an item. Lets future
/// modes filter by exam (USCIS-prep, AP-Gov-prep, etc.).
enum CurriculumSource {
  /// USCIS 2008 Naturalization Test (100 questions).
  uscis,

  /// Florida Civic Literacy Exam (FCLE).
  fcle,

  /// AP US Government and Politics (College Board CED).
  apGov,

  /// NAEP Civics Framework (Nation's Report Card).
  naep,

  /// iCivics / representative 8th-grade state standards.
  iCivics,
}

/// Whether content for an item already exists or is part of the Phase 0
/// concept-deck authoring backlog.
enum ItemCoverage {
  /// An existing face-card deck already teaches this. No new authoring.
  faceCard,

  /// Needs a brand-new concept flashcard authored (Phase 0 work).
  concept,

  /// Partial face-card coverage plus supplementary concept content needed.
  mixed,
}
