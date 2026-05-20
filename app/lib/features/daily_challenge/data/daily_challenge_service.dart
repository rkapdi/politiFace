import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/drift/app_database.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.date,
    required this.cardIds,
    required this.shareText,
    required this.grades,
  });

  final String date; // YYYY-MM-DD
  final List<String> cardIds;
  final String? shareText;
  final List<int>? grades; // FSRSGrade.value for each card, null if not played

  bool get isPlayed => shareText != null && grades != null;
}

class DailyChallengeService {
  DailyChallengeService(this._db);
  final AppDatabase _db;

  static const challengeSize = 5;

  /// Returns the challenge for [date] (defaults to today). Cached in
  /// `daily_challenge_caches`. If the cache is empty, picks 5 cards
  /// deterministically from active LocalCards.
  Future<DailyChallenge?> challengeFor({DateTime? when}) async {
    final date = _dateKey(when ?? DateTime.now());
    final cached = await _read(date);
    if (cached != null) return cached;
    final ids = await _pickCardIds(date);
    if (ids.isEmpty) return null;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.into(_db.dailyChallengeCaches).insertOnConflictUpdate(
          DailyChallengeCachesCompanion.insert(
            challengeDate: date,
            cardIds: jsonEncode(ids),
            cachedAt: nowSeconds,
          ),
        );
    return DailyChallenge(
      date: date,
      cardIds: ids,
      shareText: null,
      grades: null,
    );
  }

  /// Persist the user's grades for [date] and return the share text.
  Future<String> recordResult({
    required String date,
    required List<int> grades,
  }) async {
    final shareText = _buildShareText(date: date, grades: grades);
    final cached = await _read(date);
    final cardIds = cached?.cardIds ?? const <String>[];
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _db.into(_db.dailyChallengeCaches).insertOnConflictUpdate(
          DailyChallengeCachesCompanion.insert(
            challengeDate: date,
            cardIds: jsonEncode(cardIds),
            shareTemplate: Value(jsonEncode({
              'grades': grades,
              'share': shareText,
            })),
            cachedAt: nowSeconds,
          ),
        );
    return shareText;
  }

  Future<DailyChallenge?> _read(String date) async {
    final row = await (_db.select(_db.dailyChallengeCaches)
          ..where((t) => t.challengeDate.equals(date)))
        .getSingleOrNull();
    if (row == null) return null;
    final ids = (jsonDecode(row.cardIds) as List).cast<String>();
    if (row.shareTemplate == null) {
      return DailyChallenge(
        date: row.challengeDate,
        cardIds: ids,
        shareText: null,
        grades: null,
      );
    }
    final result = jsonDecode(row.shareTemplate!) as Map<String, dynamic>;
    return DailyChallenge(
      date: row.challengeDate,
      cardIds: ids,
      shareText: result['share'] as String?,
      grades: (result['grades'] as List?)?.cast<int>(),
    );
  }

  Future<List<String>> _pickCardIds(String date) async {
    final cards = await (_db.select(_db.localCards)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
    if (cards.isEmpty) return const [];
    if (cards.length <= challengeSize) {
      return cards.map((c) => c.id).toList();
    }
    // Deterministic seed from date: rotate through ids by a date hash.
    final seed = date.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final picked = <String>[];
    final used = <int>{};
    var idx = seed % cards.length;
    while (picked.length < challengeSize && used.length < cards.length) {
      if (!used.contains(idx)) {
        used.add(idx);
        picked.add(cards[idx].id);
      }
      idx = (idx + 7) % cards.length; // 7 is coprime with most small lengths
    }
    return picked;
  }

  /// Wordle-style share text. Emojis chosen for clear scan-readability.
  static String _buildShareText({
    required String date,
    required List<int> grades,
  }) {
    final grid = grades.map(_emojiForGrade).join();
    final correct = grades.where((g) => g >= 1).length;
    return 'Politiface Daily — $date\n$correct/${grades.length}\n$grid';
  }

  static String _emojiForGrade(int g) {
    switch (g) {
      case 0: // again
        return '🟥';
      case 1: // hard
        return '🟧';
      case 2: // good
        return '🟩';
      case 3: // easy
        return '🟦';
      default:
        return '⬛';
    }
  }

  static String _dateKey(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
