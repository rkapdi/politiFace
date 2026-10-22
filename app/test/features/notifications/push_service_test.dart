import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/notifications/data/push_service.dart';
import 'package:politiface/features/settings/data/settings_service.dart';

class RegisterCall {
  RegisterCall({required this.token, required this.environment});
  final String token;
  final String environment;
}

/// Fakes the two push_tokens RPCs so tests never touch Supabase.
class FakePushTokenApi implements PushTokenApi {
  final registered = <RegisterCall>[];
  final unregistered = <String>[];

  @override
  Future<void> register({
    required String token,
    required String environment,
  }) async {
    registered.add(RegisterCall(token: token, environment: environment));
  }

  @override
  Future<void> unregister(String token) async {
    unregistered.add(token);
  }
}

/// Fakes the native APNs bridge so tests never touch a platform channel.
class FakeApnsTokenSource implements ApnsTokenSource {
  FakeApnsTokenSource({String? initialToken}) : _current = initialToken;
  String? _current;
  final _controller = StreamController<String>.broadcast();

  @override
  Future<String?> currentToken() async => _current;

  @override
  Stream<String> get onTokenRefresh => _controller.stream;

  Future<void> refresh(String token) async {
    _current = token;
    _controller.add(token);
    // Let the listener's async handler run before the caller asserts.
    await Future<void>.delayed(Duration.zero);
  }

  void dispose() => _controller.close();
}

void main() {
  late AppDatabase db;
  late SettingsService settings;
  late FakePushTokenApi api;
  late FakeApnsTokenSource tokenSource;
  var permissionRequests = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsService(db);
    api = FakePushTokenApi();
    tokenSource = FakeApnsTokenSource(initialToken: 'a' * 64);
    permissionRequests = 0;
  });

  tearDown(() {
    tokenSource.dispose();
    return db.close();
  });

  PushService service({
    bool configured = true,
    bool releaseMode = false,
  }) =>
      PushService(
        db: db,
        api: api,
        tokenSource: tokenSource,
        settings: settings,
        configured: configured,
        releaseMode: releaseMode,
        requestPermission: () async {
          permissionRequests++;
          return true;
        },
      );

  test(
      'registers on sign-in when configured and the Washington Watch '
      'pref is on (default)', () async {
    await service().onSignedIn();

    expect(api.registered, hasLength(1));
    expect(api.registered.single.token, 'a' * 64);
    expect(permissionRequests, 1);
    expect(await db.metaDao.get('push.last_token'), 'a' * 64);
  });

  test('does not register when the Washington Watch pref is off', () async {
    await settings.setWashingtonNotifEnabled(false);

    await service().onSignedIn();

    expect(api.registered, isEmpty);
    expect(permissionRequests, 0);
  });

  test('does not register when the backend is not configured', () async {
    await service(configured: false).onSignedIn();

    expect(api.registered, isEmpty);
    expect(permissionRequests, 0);
  });

  test('sign-out unregisters the last registered token', () async {
    final svc = service();
    await svc.onSignedIn();

    await svc.onSignedOut();

    expect(api.unregistered, ['a' * 64]);
    expect(await db.metaDao.get('push.last_token'), isNull);
  });

  test('sign-out is a no-op when nothing was ever registered', () async {
    await service().onSignedOut();

    expect(api.unregistered, isEmpty);
  });

  test('sign-out is a no-op when the backend is not configured', () async {
    await service(configured: false).onSignedOut();

    expect(api.unregistered, isEmpty);
  });

  test('a token refresh while eligible re-registers the new token', () async {
    final svc = service();
    await svc.onSignedIn();
    expect(api.registered, hasLength(1));

    await tokenSource.refresh('b' * 64);

    expect(api.registered, hasLength(2));
    expect(api.registered.last.token, 'b' * 64);
    expect(await db.metaDao.get('push.last_token'), 'b' * 64);
  });

  test('a token refresh after the pref is turned off does not re-register',
      () async {
    final svc = service();
    await svc.onSignedIn();
    await settings.setWashingtonNotifEnabled(false);

    await tokenSource.refresh('b' * 64);

    expect(api.registered, hasLength(1)); // only the sign-in registration
  });

  test('environment is sandbox in debug builds', () async {
    await service().onSignedIn();

    expect(api.registered.single.environment, 'sandbox');
  });

  test('environment is production in release builds', () async {
    await service(releaseMode: true).onSignedIn();

    expect(api.registered.single.environment, 'production');
  });

  test(
      'sign-in with no token yet available registers nothing but still '
      'requests permission', () async {
    final noToken = FakeApnsTokenSource();
    addTearDown(noToken.dispose);

    await PushService(
      db: db,
      api: api,
      tokenSource: noToken,
      settings: settings,
      configured: true,
      requestPermission: () async {
        permissionRequests++;
        return true;
      },
    ).onSignedIn();

    expect(api.registered, isEmpty);
    expect(permissionRequests, 1);
  });
}
