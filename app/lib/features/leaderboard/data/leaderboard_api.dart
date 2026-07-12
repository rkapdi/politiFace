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
  });

  final String id;
  final String name;
  final String role; // student | faculty
  final String? term;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.handle,
    required this.score,
    required this.rank,
  });

  final String userId;
  final String handle;
  final int score;

  /// Competition ranking: ties share a rank (1, 2, 2, 4).
  final int rank;
}

/// Sorts descending and assigns competition ranks. Pure; unit-tested.
List<LeaderboardEntry> rankEntries(
  List<({String userId, String handle, int score})> rows,
) {
  final sorted = [...rows]..sort((a, b) => b.score.compareTo(a.score));
  final entries = <LeaderboardEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final rank = (i > 0 && sorted[i].score == sorted[i - 1].score)
        ? entries[i - 1].rank
        : i + 1;
    entries.add(LeaderboardEntry(
      userId: sorted[i].userId,
      handle: sorted[i].handle,
      score: sorted[i].score,
      rank: rank,
    ),);
  }
  return entries;
}

abstract class LeaderboardApi {
  Future<List<CohortInfo>> myCohorts();

  Future<List<LeaderboardEntry>> entries(String cohortId);

  /// Joins by class code via the join_cohort RPC; returns the cohort id.
  Future<String> joinCohort(String code);
}

class SupabaseLeaderboardApi implements LeaderboardApi {
  SupabaseLeaderboardApi(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CohortInfo>> myCohorts() async {
    final rows = await _client
        .from('cohort_members')
        .select('cohort_id, role, joined_at, cohorts(name, term)')
        .order('joined_at', ascending: false);
    return [
      for (final r in rows)
        CohortInfo(
          id: r['cohort_id'] as String,
          role: r['role'] as String,
          name: (r['cohorts'] as Map?)?['name'] as String? ?? 'My class',
          term: (r['cohorts'] as Map?)?['term'] as String?,
        ),
    ];
  }

  @override
  Future<List<LeaderboardEntry>> entries(String cohortId) async {
    final rows = await _client
        .from('leaderboard')
        .select('user_id, score, profiles(handle)')
        .eq('cohort_id', cohortId)
        .order('score', ascending: false)
        .limit(200);
    return rankEntries([
      for (final r in rows)
        (
          userId: r['user_id'] as String,
          handle: (r['profiles'] as Map?)?['handle'] as String? ?? 'anonymous',
          score: r['score'] as int,
        ),
    ]);
  }

  @override
  Future<String> joinCohort(String code) async {
    final res = await _client
        .rpc<dynamic>('join_cohort', params: {'p_code': code.trim()});
    return res as String;
  }
}
