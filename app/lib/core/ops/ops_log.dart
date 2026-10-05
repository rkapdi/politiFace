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

  static String? _version;

  static Future<String?> _appVersion() async {
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
      final params = <String, dynamic>{
        'p_kind': kind,
        'p_client': 'ios',
        'p_code':
            code == null || code.length <= 80 ? code : code.substring(0, 80),
        'p_detail': detail,
        'p_app_version': sinkOverride != null ? null : await _appVersion(),
        'p_email': email,
      };
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
