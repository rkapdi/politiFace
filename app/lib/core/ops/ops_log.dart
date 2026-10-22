// Problem log (admin console 2a): fire-and-forget reports of what went
// wrong for a user, shown on their timeline in the founders' console.
// Never blocks or breaks a flow; failures to log are swallowed.

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/supabase_config.dart';

class OpsLog {
  OpsLog._();

  /// Test seam: when set, receives the RPC params instead of Supabase.
  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> params)? sinkOverride;

  /// Test seam: the clock the 60-second dedupe window is measured against.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static String? _version;

  // Client-side throttle, in addition to the server's own per-minute caps:
  // a repeat of the same (kind, code, detail message) within 60 seconds is
  // dropped outright, and client_error reports are capped per app run so a
  // crash loop cannot flood the problem log before the server-side cap
  // even sees it.
  static const int _dedupeWindowSeconds = 60;
  static const int _clientErrorCap = 20;
  static final Map<String, DateTime> _recentFingerprints = {};
  static int _clientErrorCount = 0;

  /// Test seam: clears throttle state between tests.
  @visibleForTesting
  static void resetThrottleForTesting() {
    _recentFingerprints.clear();
    _clientErrorCount = 0;
    now = DateTime.now;
  }

  /// "1.3.2 (34)", cached; null when the bundle cannot be read.
  static Future<String?> appVersion() async {
    if (_version != null) return _version;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      _version = null;
    }
    return _version;
  }

  static Future<void> report(
    String kind, {
    String? code,
    Map<String, Object?>? detail,
    String? email,
  }) async {
    try {
      final fingerprint = '$kind|$code|${detail?['message']}';
      final sentAt = now();
      final lastSent = _recentFingerprints[fingerprint];
      if (lastSent != null &&
          sentAt.difference(lastSent).inSeconds < _dedupeWindowSeconds) {
        return;
      }
      if (kind == 'client_error' && _clientErrorCount >= _clientErrorCap) {
        return;
      }

      final params = <String, dynamic>{
        'p_kind': kind,
        'p_client': 'ios',
        'p_code':
            code == null || code.length <= 80 ? code : code.substring(0, 80),
        'p_detail': detail,
        'p_app_version': sinkOverride != null ? null : await appVersion(),
        'p_email': email,
      };

      _recentFingerprints[fingerprint] = sentAt;
      if (kind == 'client_error') _clientErrorCount++;

      final sink = sinkOverride;
      if (sink != null) {
        await sink(params);
        return;
      }
      if (!SupabaseConfig.isConfigured) return;
      await Supabase.instance.client.rpc<void>('log_ops_event', params: params);
    } catch (_) {
      // never let logging break the caller
    }
  }
}
