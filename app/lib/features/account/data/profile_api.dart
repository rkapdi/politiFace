// lib/features/account/data/profile_api.dart
//
// Thin seam over the two account-management RPCs (see supabase/migrations/
// 20260724000500_account_management.sql): update_my_profile and
// delete_my_account, plus a direct read of the caller's own profile row.
// Kept separate from AuthService (which owns sign-in/out and the
// generated-handle bootstrap) so tests fake the network here instead of
// touching Supabase, the same seam pattern as PushTokenApi.

import 'package:supabase_flutter/supabase_flutter.dart';

/// The account-management fields of the caller's own profile. All three
/// are optional inputs on update (server updates only what is passed) but
/// always come back populated on read.
class ProfileUpdate {
  const ProfileUpdate({
    required this.handle,
    required this.school,
    required this.avatarId,
  });

  final String? handle;
  final String? school;
  final int avatarId;
}

abstract class ProfileApi {
  /// Reads the signed-in caller's own profile fields, or null if signed
  /// out or the profile row has not been created yet.
  Future<ProfileUpdate?> fetchMyProfile();

  /// Updates only the fields passed via update_my_profile; the server
  /// leaves anything null untouched. Throws PostgrestException with the
  /// server's exact message on validation failure (bad handle format, a
  /// handle already taken).
  Future<ProfileUpdate> updateProfile({
    String? handle,
    String? school,
    int? avatarId,
  });

  /// Permanently erases the signed-in account and everything derived from
  /// it via delete_my_account. Irreversible.
  Future<void> deleteAccount();
}

class SupabaseProfileApi implements ProfileApi {
  SupabaseProfileApi(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileUpdate?> fetchMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select('handle, school, avatar_id')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return ProfileUpdate(
      handle: row['handle'] as String?,
      school: row['school'] as String?,
      avatarId: (row['avatar_id'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<ProfileUpdate> updateProfile({
    String? handle,
    String? school,
    int? avatarId,
  }) async {
    final res = await _client.rpc<dynamic>(
      'update_my_profile',
      params: {
        'p_handle': handle,
        'p_school': school,
        'p_avatar_id': avatarId,
      },
    );
    final json = Map<String, dynamic>.from(res as Map);
    return ProfileUpdate(
      handle: json['handle'] as String?,
      school: json['school'] as String?,
      avatarId: (json['avatar_id'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<dynamic>('delete_my_account');
  }
}
