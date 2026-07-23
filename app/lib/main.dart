import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/politiface_app.dart';
import 'app/providers.dart';
import 'core/database/drift/app_database.dart';
import 'core/sync/restore_service.dart';
import 'core/sync/supabase_config.dart';
import 'core/sync/sync_engine.dart';
import 'features/atlas/data/people_seed_service.dart';
import 'features/curriculum/data/curriculum_loader.dart';
import 'features/government/data/government_seed_service.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/session/data/delegation_deck_service.dart';
import 'features/session/data/yaml_seed_service.dart';
import 'features/settings/data/settings_service.dart';

/// Sentry DSN. Empty → SDK no-ops (no crash reports sent). Builds you compile
/// yourself contain no DSN; official builds inject one via
/// --dart-define=SENTRY_DSN=... (see codemagic.yaml).
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();

  // Backend config follows the Sentry DSN pattern: builds without the
  // --dart-define values never initialize Supabase, so auth and sync no-op
  // and the app stays fully offline, exactly like v1.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // Accepts either key format: the new sb_publishable_... keys or a
      // legacy anon key. Both are public client credentials; RLS guards.
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Crash reporting is on by default (anonymous, no personal info) and
  // honors the explicit off switch in Settings → Privacy → Crash reports.
  // The flag is read here (not via SettingsService providers) because Sentry
  // must wrap the app from startup; changes take effect on the next launch.
  final crashReportsEnabled =
      (await db.metaDao.get(SettingsService.kCrashReports)) != '0';

  if (crashReportsEnabled && _sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (opts) {
        opts.dsn = _sentryDsn;
        opts.tracesSampleRate = 0.1; // only 10% of transactions
        opts.sendDefaultPii = false; // never attach personal info
      },
      appRunner: () => _bootstrap(db),
    );
  } else {
    await _bootstrap(db);
  }
}

Future<void> _bootstrap(AppDatabase db) async {
  await YamlSeedService(db).ensureSeeded();
  await GovernmentSeedService(db).ensureSeeded();
  await PeopleSeedService(db).ensureSeeded();
  await DelegationDeckService(db).ensureSeeded();
  await NotificationService.instance.init();
  // Sync the daily-reminder toggle with the OS authorization state. If the
  // user revoked notifications in iOS Settings since last launch, flip our
  // toggle off so the UI doesn't lie. If still authorized and the toggle is
  // on, re-arm the schedule (it would otherwise be lost on reinstall).
  if ((await db.metaDao.get('settings.daily_reminder')) == '1') {
    final stillAuthorized = await NotificationService.instance.isAuthorized();
    if (stillAuthorized) {
      await NotificationService.instance.scheduleDailyReminder();
    } else {
      await db.metaDao.set('settings.daily_reminder', '0');
      await NotificationService.instance.cancel();
    }
  }
  // Drain events queued in a previous run (delivers only when a user is
  // signed in; no-ops otherwise). Fire-and-forget: launch never waits on
  // the network.
  if (SupabaseConfig.isConfigured) {
    final client = Supabase.instance.client;
    final engine = SyncEngine(db, SupabaseTransport(client));
    unawaited(engine.flush());
    // Cross-device restore on cold start: only when already signed in, at
    // most once per 6 hours (AppMeta 'sync.last_pull'). Fire-and-forget and
    // internally fail-safe, so launch never waits or breaks on it.
    unawaited(
      RestoreService(
        db: db,
        api: SupabaseRestoreApi(client),
        sync: engine,
        loadCurriculum: () => CurriculumLoader().load(),
      ).maybeRestoreOnColdStart(),
    );
  }

  // First launch opens the onboarding sequence; a --dart-define lets
  // QA/deep-link builds open straight onto any route instead
  // (e.g. INITIAL_ROUTE=/pulse), and takes precedence.
  const envRoute = String.fromEnvironment('INITIAL_ROUTE');
  final onboarded = (await db.metaDao.get(OnboardingScreen.doneFlagKey)) == '1';
  final initialRoute =
      envRoute.isNotEmpty ? envRoute : (onboarded ? '/' : '/onboarding');

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialRouteProvider.overrideWithValue(initialRoute),
      ],
      child: const PolitifaceApp(),
    ),
  );
}
