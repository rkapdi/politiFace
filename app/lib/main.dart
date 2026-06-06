import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/politiface_app.dart';
import 'app/providers.dart';
import 'core/database/drift/app_database.dart';
import 'features/government/data/government_seed_service.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/session/data/yaml_seed_service.dart';

/// Sentry DSN. Empty → SDK no-ops (no crash reports sent). Drop in a real DSN
/// (from sentry.io project settings) to start receiving production crashes.
/// Best supplied via --dart-define=SENTRY_DSN=... so it doesn't sit in git.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  await SentryFlutter.init(
    (opts) {
      opts.dsn = _sentryDsn;
      opts.tracesSampleRate = 0.1; // only 10% of transactions
      opts.sendDefaultPii = false; // never attach personal info
    },
    appRunner: _bootstrap,
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await YamlSeedService(db).ensureSeeded();
  await GovernmentSeedService(db).ensureSeeded();
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
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialRouteProvider.overrideWithValue('/'),
      ],
      child: const PolitifaceApp(),
    ),
  );
}
