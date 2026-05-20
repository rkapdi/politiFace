import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class PolitifaceApp extends ConsumerWidget {
  const PolitifaceApp({super.key});

  static const _seed = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Politiface',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
