// App-wide smoke test: the regression net under every change.
//
// Boots the real app (real router, theme and providers) over an in-memory
// database seeded with the real bundled content, on a small-iPhone screen,
// then opens every route the router declares. Any screen that throws while
// building or settling, or lands on an error state ("Could not load...",
// "Failed to load...", the shared error view), fails the test. The route list is read from the
// router itself, so a new screen is covered the day it is added and a
// removed screen drops out on its own.
//
// It does not check what a screen shows; the feature tests do that. It
// catches what they cannot: a change in one feature that breaks another
// screen, a provider that now throws, content that no longer parses.
//
// Layout overflow is NOT checked here: flutter test draws every glyph as a
// full-em square, far wider than the app's real fonts, so rows that fit on
// a phone report overflow in this harness. Check layout on a simulator.
//
// Network is unavailable under flutter test (every HTTP call gets a 400)
// and Supabase is never initialized, so this also proves every screen
// survives being offline and signed out.
//
// Run just this file: flutter test test/smoke

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:politiface/app/politiface_app.dart';
import 'package:politiface/app/providers.dart';
import 'package:politiface/core/audio/sound_service.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/atlas/data/people_seed_service.dart';
import 'package:politiface/features/government/data/government_seed_service.dart';
import 'package:politiface/features/onboarding/presentation/onboarding_screen.dart';
import 'package:politiface/features/session/data/delegation_deck_service.dart';
import 'package:politiface/features/session/data/yaml_seed_service.dart';
import 'package:politiface/features/shared/widgets/state_views.dart';

import '../helpers/fake_sound_service.dart';

/// iPhone SE (3rd gen) in logical pixels, the smallest supported phone, so
/// screens build with the tightest constraints they will meet.
const _phone = Size(375, 667);

/// Routes whose builder needs `state.extra` (an object handed over by the
/// screen that links to them), so a bare URL cannot open them. Their
/// screens are covered by their own feature tests.
const _needsExtra = {'/pulse/bill', '/live', '/fcle/result'};

/// Routes that load from the network and so show their error state when
/// offline, which they always are under flutter test. Each must say why.
const _offlineErrorOk = <String, String>{};

/// The app's error states: the shared view plus the inline messages screens
/// show when a provider fails.
final _errorStates = find.byWidgetPredicate(
  (w) =>
      w is AppErrorView ||
      (w is Text &&
          RegExp(r'^(Could not load|Failed to (load|compute)|Something went wrong)')
              .hasMatch(w.data ?? '')),
);

String _describe(Element e) {
  final w = e.widget;
  return w is AppErrorView ? '${w.title}: ${w.message}' : (w as Text).data!;
}

void main() {
  late AppDatabase db;
  // Opened and closed outside the widget test's fake clock: closing it
  // from inside the test never completes.
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  setUpAll(() {
    // The theme's fonts are fetched at runtime and tests have no network.
    // Their load failures are dropped in [_quietFonts]; the screens fall
    // back to the default font, which is fine for this test.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('first launch opens onboarding', (tester) async {
    final failures = await _quietFonts(() async {
      final app = await _App.start(tester, db, onboarded: false);
      await app.open('/onboarding');
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await app.stop();
      return app.failures;
    });
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('every route opens without throwing', (tester) async {
    late List<String> locations;
    final failures = await _quietFonts(() async {
      final app = await _App.start(tester, db, onboarded: true);
      locations = await app.locations();
      for (final location in locations) {
        await app.open(location);
      }
      await app.stop();
      return app.failures;
    });
    // Guards against the walk silently finding nothing.
    expect(locations, containsAll(['/', '/fcle', '/endless', '/map']));
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });
}

/// The app under test, plus every failure seen while driving it.
class _App {
  _App._(this.tester, this.db, this.router);

  final WidgetTester tester;
  final AppDatabase db;
  final GoRouter router;
  final failures = <String>[];
  void Function(FlutterErrorDetails)? _onError;

  static Future<_App> start(
    WidgetTester tester,
    AppDatabase db, {
    required bool onboarded,
  }) async {
    // See the header: overflow in this harness is mostly the test font.
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is FlutterError &&
          '${details.exception}'.contains('overflowed by')) {
        return;
      }
      reportError?.call(details);
    };

    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await YamlSeedService(db).ensureSeeded();
      await GovernmentSeedService(db).ensureSeeded();
      await PeopleSeedService(db).ensureSeeded();
      await DelegationDeckService(db).ensureSeeded();
      if (onboarded) {
        await db.metaDao.set(OnboardingScreen.doneFlagKey, '1');
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialRouteProvider
              .overrideWithValue(onboarded ? '/' : '/onboarding'),
          soundServiceProvider.overrideWithValue(FakeSoundService()),
        ],
        child: const PolitifaceApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PolitifaceApp)),
    );
    final app = _App._(tester, db, container.read(routerProvider))
      .._onError = reportError;
    await app._settle('boot');
    return app;
  }

  Future<void> open(String location) async {
    router.go(location);
    await _settle(location);
    final shown = _errorStates.evaluate().map(_describe).toSet();
    if (shown.isNotEmpty && !_offlineErrorOk.containsKey(location)) {
      failures.add('$location: shows an error state: ${shown.join(' | ')}');
    }
  }

  /// Every location the router declares, with real ids from the seeded
  /// content filled into path parameters.
  Future<List<String>> locations() async {
    final samples = await tester.runAsync(_sampleIds) ?? const {};
    final out = <String>[];
    void walk(List<RouteBase> routes, String parent) {
      for (final route in routes) {
        if (route is GoRoute) {
          final path = route.path.startsWith('/')
              ? route.path
              : '${parent == '/' ? '' : parent}/${route.path}';
          if (!_needsExtra.contains(path)) {
            out.add(samples[path] ?? path);
          }
          walk(route.routes, path);
        } else if (route is ShellRouteBase) {
          walk(route.routes, parent);
        }
      }
    }

    walk(router.configuration.routes, '/');
    final unfilled = out.where((l) => l.contains(':'));
    if (unfilled.isNotEmpty) {
      failures.add('no sample id for ${unfilled.join(', ')}: '
          'add one to _sampleIds in this test');
    }
    return out.where((l) => !l.contains(':')).toList();
  }

  /// One real id per parameterized route, read from the seeded database so
  /// the detail screens render real content instead of a not-found state.
  Future<Map<String, String>> _sampleIds() async {
    final nodes = await db.select(db.govNodes).get();
    final cards = await db.select(db.localCards).get();
    final politicians = cards.where((c) => c.cardType == 'face');
    final people = await db.select(db.people).get();
    return {
      if (nodes.isNotEmpty) '/node/:id': '/node/${nodes.first.id}',
      if (cards.isNotEmpty)
        '/memory/card/:cardId': '/memory/card/${cards.first.id}',
      if (politicians.isNotEmpty)
        '/politician/:cardId': '/politician/${politicians.first.id}',
      if (people.isNotEmpty) '/person/:id': '/person/${people.first.id}',
    };
  }

  /// Unmounts the app, drains pending work and restores error reporting.
  Future<void> stop() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    // A real database round trip flushes the work screens queued, so
    // teardown can close the database.
    await tester.runAsync(() => db.metaDao.get(OnboardingScreen.doneFlagKey));
    FlutterError.onError = _onError;
  }

  /// Pumps enough frames for async providers to resolve and entry
  /// animations to finish. Not pumpAndSettle: several screens animate
  /// forever.
  Future<void> _settle(String where) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
      final error = tester.takeException();
      if (error != null) failures.add('$where: $error');
    }
  }
}

/// Runs [body] with google_fonts load failures dropped and every other
/// uncaught error forwarded to the test as usual.
Future<T> _quietFonts<T>(Future<T> Function() body) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      handleUncaughtError: (self, parent, zone, error, stack) {
        if ('$error'.contains('allowRuntimeFetching')) return;
        parent.handleUncaughtError(zone, error, stack);
      },
    ),
  );
}
