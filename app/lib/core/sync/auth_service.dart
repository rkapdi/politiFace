// lib/core/sync/auth_service.dart
//
// Pseudonymous accounts on Supabase Auth, email OTP flow (no passwords, no
// third-party identity yet; Sign in with Apple is a follow-up that needs the
// entitlement + portal setup). Data minimization: the email lives ONLY in
// auth.users on the server; the app-visible profile is a generated handle.

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sends a 6-digit code (and magic link) to [email].
  Future<void> requestOtp(String email) =>
      _client.auth.signInWithOtp(email: email.trim());

  /// Verifies the emailed code, then makes sure a pseudonymous profile row
  /// exists so RLS-joined features (leaderboards, cohorts) work immediately.
  Future<void> verifyOtp({required String email, required String code}) async {
    await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: code.trim(),
    );
    await ensureProfile();
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Handle shown on leaderboards. Never derived from the email.
  Future<String?> profileHandle() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select('handle')
        .eq('id', user.id)
        .maybeSingle();
    return row?['handle'] as String?;
  }

  Future<void> ensureProfile() async {
    final user = currentUser;
    if (user == null) return;
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    // Retry a few times in case the generated handle collides.
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await _client.from('profiles').insert({
          'id': user.id,
          'handle': generateHandle(),
        });
        return;
      } on PostgrestException catch (e) {
        final isUniqueViolation = e.code == '23505';
        if (!isUniqueViolation || attempt == 3) rethrow;
      }
    }
  }

  /// civic-flavored, neutral, collision-resistant enough with the retry loop.
  static String generateHandle({Random? random}) {
    const adjectives = [
      'civic', 'keen', 'steady', 'bright', 'quiet', 'swift',
      'sturdy', 'plain', 'bold', 'candid', 'earnest', 'lively',
    ];
    const nouns = [
      'quill', 'gavel', 'ledger', 'compass', 'lantern', 'archway',
      'beacon', 'bridge', 'anchor', 'summit', 'meridian', 'harbor',
    ];
    final r = random ?? Random.secure();
    final a = adjectives[r.nextInt(adjectives.length)];
    final n = nouns[r.nextInt(nouns.length)];
    final d = r.nextInt(10000).toString().padLeft(4, '0');
    return '${a}_${n}_$d';
  }
}
