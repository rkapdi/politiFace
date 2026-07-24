// lib/features/notifications/data/push_service.dart
//
// APNs device-token registration. Bridges the native AppDelegate's remote-
// notification token and silent-push callback (see AppDelegate.swift) to
// the server's push_tokens RPCs (register_push_token / unregister_push_token,
// supabase/migrations/20260724000200_push_tokens.sql).
//
// The server sends only silent, content-available pushes (never alert
// text); its sole job is to wake the phone so WashingtonWatchService.check()
// can run its own fetch-and-decide, exactly as the BGAppRefresh path
// already does (see PushChannelBridge, main.dart). That fallback stays
// wired regardless: this service only ever adds a faster path to the same
// check, never a required one.
//
// No Firebase, no third-party push SDK: see AppDelegate.swift for why
// flutter_apns_only (the natural off-the-shelf fit) was passed over.

import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../core/database/drift/app_database.dart';
import '../../../core/sync/supabase_config.dart';
import '../../settings/data/settings_service.dart';
import 'notification_service.dart';

/// Seam over the two push_tokens RPCs so tests fake the network instead of
/// touching Supabase.
abstract class PushTokenApi {
  Future<void> register({required String token, required String environment});
  Future<void> unregister(String token);
}

class SupabasePushTokenApi implements PushTokenApi {
  SupabasePushTokenApi(this._client);
  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required String environment,
  }) =>
      _client.rpc(
        'register_push_token',
        params: {'p_token': token, 'p_environment': environment},
      );

  @override
  Future<void> unregister(String token) =>
      _client.rpc('unregister_push_token', params: {'p_token': token});
}

/// Seam over the native APNs bridge so tests never touch a platform
/// channel. [onTokenRefresh] emits every token AppDelegate reports after
/// the first (a reinstall, an OS-level token rotation).
abstract class ApnsTokenSource {
  Future<String?> currentToken();
  Stream<String> get onTokenRefresh;
}

/// Owns the single native push MethodChannel (see AppDelegate.swift): the
/// APNs device token in one direction, the silent-push wake signal in the
/// other. A thin singleton, like [NotificationService], so exactly one
/// MethodCallHandler is ever registered on the channel.
class PushChannelBridge {
  PushChannelBridge._();
  static final PushChannelBridge instance = PushChannelBridge._();

  static const _channel = MethodChannel('app.politiface/push');
  final _tokenController = StreamController<String>.broadcast();
  bool _handlerSet = false;

  /// Set by main.dart at startup so a background silent push runs the same
  /// check the workmanager BGAppRefresh path runs. Left null before
  /// startup wires it (a push landing in that narrow cold-start window is
  /// a rare race; the belt-and-braces foreground check in main.dart's
  /// bootstrap covers it) and in tests, which never touch this bridge.
  Future<bool> Function()? onSilentPush;

  Stream<String> get onTokenRefresh {
    _ensureHandler();
    return _tokenController.stream;
  }

  Future<String?> currentToken() async {
    _ensureHandler();
    final token = await _channel.invokeMethod<String>('getApnsToken');
    return (token == null || token.isEmpty) ? null : token;
  }

  void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler(_onCall);
  }

  Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'apnsToken':
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) _tokenController.add(token);
        return null;
      case 'silentPush':
        final handler = onSilentPush;
        if (handler == null) return false;
        try {
          return await handler();
        } catch (_) {
          return false;
        }
      default:
        return null;
    }
  }
}

class PlatformApnsTokenSource implements ApnsTokenSource {
  const PlatformApnsTokenSource();

  @override
  Future<String?> currentToken() => PushChannelBridge.instance.currentToken();

  @override
  Stream<String> get onTokenRefresh =>
      PushChannelBridge.instance.onTokenRefresh;
}

/// Registers / unregisters this device's APNs token with the server,
/// scoped to the signed-in session and the Washington Watch master switch
/// (silent pushes only ever wake Washington Watch, so there's no reason to
/// hold a token when that pref is off).
class PushService {
  PushService({
    required AppDatabase db,
    required PushTokenApi api,
    ApnsTokenSource? tokenSource,
    SettingsService? settings,
    Future<bool> Function()? requestPermission,
    bool? configured,
    bool releaseMode = kReleaseMode,
  })  : _db = db,
        _api = api,
        _tokenSource = tokenSource ?? const PlatformApnsTokenSource(),
        _settings = settings ?? SettingsService(db),
        _requestPermission =
            requestPermission ?? NotificationService.instance.requestPermission,
        _configured = configured ?? SupabaseConfig.isConfigured,
        environment = releaseMode ? 'production' : 'sandbox';

  final AppDatabase _db;
  final PushTokenApi _api;
  final ApnsTokenSource _tokenSource;
  final SettingsService _settings;
  final Future<bool> Function() _requestPermission;
  final bool _configured;

  /// 'sandbox' for debug builds, 'production' for release. Matches the
  /// `environment` check constraint on push_tokens.
  final String environment;

  static const _kLastToken = 'push.last_token';

  StreamSubscription<String>? _refreshSub;

  /// Backend configured, and the Washington Watch master switch on. Signed-
  /// in-ness is the caller's job (onSignedIn / onSignedOut below).
  Future<bool> _eligible() async {
    if (!_configured) return false;
    return _settings.washingtonNotifEnabled();
  }

  /// Call when a session becomes signed-in (a fresh sign-in, or already
  /// signed in at cold start). No-op when not eligible. Also starts
  /// listening for token refreshes so a later rotation re-registers
  /// automatically.
  Future<void> onSignedIn() async {
    if (!await _eligible()) return;
    await _requestPermission();
    final token = await _tokenSource.currentToken();
    if (token != null) await _registerToken(token);
    _refreshSub ??= _tokenSource.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _onTokenRefresh(String token) async {
    if (!await _eligible()) return;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    await _api.register(token: token, environment: environment);
    await _db.metaDao.set(_kLastToken, token);
  }

  /// Call on sign-out: best-effort unregisters the last known token so the
  /// server stops holding a handle tied to no active session.
  Future<void> onSignedOut() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (!_configured) return;
    final last = await _db.metaDao.get(_kLastToken);
    if (last == null) return;
    try {
      await _api.unregister(last);
    } catch (_) {
      // Best-effort: a stale row is harmless (owner-only via RLS, never
      // surfaced), and the next sign-in's register call overwrites it
      // anyway.
    }
    await _db.metaDao.remove(_kLastToken);
  }
}
