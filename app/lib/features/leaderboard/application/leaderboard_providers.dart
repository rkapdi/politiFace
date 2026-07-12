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

final leaderboardEntriesProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, cohortId) async {
    final api = ref.watch(leaderboardApiProvider);
    if (api == null) return const [];
    return api.entries(cohortId);
  },
);
