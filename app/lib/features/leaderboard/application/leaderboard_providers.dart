// lib/features/leaderboard/application/leaderboard_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../app/providers.dart';
import '../../../core/sync/supabase_config.dart';
import '../data/leaderboard_api.dart';

final leaderboardApiProvider = Provider<LeaderboardApi?>((ref) =>
    SupabaseConfig.isConfigured
        ? SupabaseLeaderboardApi(Supabase.instance.client)
        : null,);

/// Cohorts the signed-in user belongs to, newest joined first. Empty when
/// unconfigured or signed out.
final myCohortsProvider = FutureProvider<List<CohortInfo>>((ref) async {
  ref.watch(authStateProvider);
  final api = ref.watch(leaderboardApiProvider);
  final auth = ref.watch(authServiceProvider);
  if (api == null || auth == null || !auth.isSignedIn) return const [];
  return api.myCohorts();
});

/// The class the student last picked on the leaderboard, persisted in
/// AppMeta so Home and the board agree after any amount of navigation.
/// Null until a student with several classes makes a pick; consumers fall
/// back to the newest-joined cohort (list.first) when the stored id is
/// null or no longer a membership.
final selectedCohortIdProvider =
    AsyncNotifierProvider<SelectedCohortId, String?>(SelectedCohortId.new);

class SelectedCohortId extends AsyncNotifier<String?> {
  static const metaKey = 'class.selected_cohort_id';

  @override
  Future<String?> build() =>
      ref.watch(databaseProvider).metaDao.get(metaKey);

  Future<void> select(String cohortId) async {
    // Let the initial load settle first or its completion would overwrite
    // a pick made while it was still in flight.
    await future;
    state = AsyncData(cohortId);
    await ref.read(databaseProvider).metaDao.set(metaKey, cohortId);
  }
}

final leaderboardEntriesProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, cohortId) async {
    final api = ref.watch(leaderboardApiProvider);
    if (api == null) return const [];
    return api.entries(cohortId);
  },
);
