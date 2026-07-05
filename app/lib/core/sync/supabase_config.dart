// lib/core/sync/supabase_config.dart
//
// Backend endpoint configuration. Follows the Sentry DSN pattern: builds you
// compile yourself have no backend and every sync/auth feature no-ops;
// official builds inject values via --dart-define (see codemagic.yaml).
// The anon key is a public client credential by design (RLS is the guard).

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// False in local/dev builds: the app stays fully offline, exactly like v1.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
