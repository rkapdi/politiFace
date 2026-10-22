// lib/features/leaderboard/data/leaderboard_api.dart
//
// Class leaderboards, read-only from the client. Scores are
// server-authoritative (+1 per correct answer, written only by the grading
// RPCs), so this layer just reads rows RLS already scopes: a member sees
// their own cohorts and only those. Handles are the pseudonymous generated
// ones; no real names exist anywhere in the system.

import 'package:supabase_flutter/supabase_flutter.dart';

class CohortInfo {
  const CohortInfo({
    required this.id,
    required this.name,
    required this.role,
    this.term,
    this.rosterName,
  });

  final String id;
  final String name;
  final String role; // student | faculty
  final String? term;

  /// The name the professor knows this member by in this class, or null
  /// until set. Faculty-of-this-cohort visibility only; leaderboards always
  /// show the generated handle instead.
  final String? rosterName;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.handle,
    required this.score,
    required this.rank,
    this.avatarId = 0,
  });

  final String userId;
  final String handle;
  final int score;

  /// Competition ranking: ties share a rank (1, 2, 2, 4).
  final int rank;

  /// The pseudonymous avatar chosen on the account screen. Defaults to 0
  /// (a valid avatar) when a row predates avatar_id or the caller does not
  /// have it on hand.
  final int avatarId;
}

/// Sorts descending and assigns competition ranks. Pure; unit-tested.
List<LeaderboardEntry> rankEntries(
  List<({String userId, String handle, int score, int avatarId})> rows,
) {
  final sorted = [...rows]..sort((a, b) => b.score.compareTo(a.score));
  final entries = <LeaderboardEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final rank = (i > 0 && sorted[i].score == sorted[i - 1].score)
        ? entries[i - 1].rank
        : i + 1;
    entries.add(
      LeaderboardEntry(
        userId: sorted[i].userId,
        handle: sorted[i].handle,
        score: sorted[i].score,
        rank: rank,
        avatarId: sorted[i].avatarId,
      ),
    );
  }
  return entries;
}

abstract class LeaderboardApi {
  Future<List<CohortInfo>> myCohorts();

  Future<List<LeaderboardEntry>> entries(String cohortId);

  /// Joins by class code via the join_cohort RPC; returns the cohort id.
  /// [rosterName] is the name the professor knows the student by, required
  /// so faculty reports are meaningful the moment a student joins.
  Future<String> joinCohort(String code, String rosterName);

  /// Updates the roster name for a class already joined, via
  /// set_roster_name. Faculty-only visibility; never touches the handle
  /// leaderboards show.
  Future<void> setRosterName(String cohortId, String name);
}

class SupabaseLeaderboardApi implements LeaderboardApi {
  SupabaseLeaderboardApi(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CohortInfo>> myCohorts() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('cohort_members')
        .select('cohort_id, role, joined_at, cohorts(name, term)')
        .eq('user_id', uid)
        .order('joined_at', ascending: false);
    final seen = <String>{};
    final cohorts = <CohortInfo>[];
    for (final r in rows) {
      final cohortId = r['cohort_id'] as String;
      // Defensive dedupe by cohort_id (one membership row per cohort).
      if (!seen.add(cohortId)) continue;
      // roster_name is column-revoked (faculty-only via reports); read the
      // caller's OWN name through the definer RPC for the edit tile.
      final ownName = await _client.rpc<dynamic>(
        'my_roster_name',
        params: {'p_cohort': cohortId},
      );
      cohorts.add(
        CohortInfo(
          id: cohortId,
          role: r['role'] as String,
          name: (r['cohorts'] as Map?)?['name'] as String? ?? 'My class',
          term: (r['cohorts'] as Map?)?['term'] as String?,
          rosterName:
              (ownName is String && ownName.isNotEmpty) ? ownName : null,
        ),
      );
    }
    return cohorts;
  }

  @override
  Future<List<LeaderboardEntry>> entries(String cohortId) async {
    final rows = await _client
        .from('leaderboard')
        .select('user_id, score, profiles(handle, avatar_id)')
        .eq('cohort_id', cohortId)
        .order('score', ascending: false)
        .limit(200);
    return rankEntries([
      for (final r in rows)
        (
          userId: r['user_id'] as String,
          handle: (r['profiles'] as Map?)?['handle'] as String? ?? 'anonymous',
          score: r['score'] as int,
          avatarId:
              ((r['profiles'] as Map?)?['avatar_id'] as num?)?.toInt() ?? 0,
        ),
    ]);
  }

  @override
  Future<String> joinCohort(String code, String rosterName) async {
    final res = await _client.rpc<dynamic>(
      'join_cohort',
      params: {
        'p_code': code.trim(),
        'p_roster_name': rosterName.trim(),
      },
    );
    return res as String;
  }

  @override
  Future<void> setRosterName(String cohortId, String name) async {
    await _client.rpc<dynamic>(
      'set_roster_name',
      params: {
        'p_cohort': cohortId,
        'p_name': name.trim(),
      },
    );
  }
}
