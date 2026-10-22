// lib/features/account/application/account_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../app/providers.dart';
import '../../../core/sync/supabase_config.dart';
import '../data/profile_api.dart';

final profileApiProvider = Provider<ProfileApi?>(
  (ref) => SupabaseConfig.isConfigured
      ? SupabaseProfileApi(Supabase.instance.client)
      : null,
);

/// The signed-in user's own account-management fields (handle, school,
/// avatar_id). Null when unconfigured, signed out, or the profile row has
/// not been created yet.
final myAccountProvider = FutureProvider<ProfileUpdate?>((ref) async {
  ref.watch(authStateProvider);
  final api = ref.watch(profileApiProvider);
  final auth = ref.watch(authServiceProvider);
  if (api == null || auth == null || !auth.isSignedIn) return null;
  return api.fetchMyProfile();
});
