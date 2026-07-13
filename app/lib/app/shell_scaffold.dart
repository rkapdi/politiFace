import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio/sound_service.dart';

/// Shell widget that hosts the top-level tabs (Home, Learn) with a persistent
/// bottom NavigationBar. Routes outside [StatefulShellRoute] (session,
/// summary, node detail, settings, onboarding) render without this chrome.
class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  @override
  void initState() {
    super.initState();
    // Warm up the sound pools post-frame so the first real play has zero
    // load hit. Reading soundEnabledProvider pulls the persisted preference
    // into the service's cached flag. Both are fire-and-forget and no-op
    // safely when audio is unavailable (e.g. widget tests).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(soundEnabledProvider);
      unawaited(ref.read(soundServiceProvider).init());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            widget.navigationShell.goBranch(
              i,
              // Tapping a tab you're already on pops the branch to its initial
              // route — matches iOS expectations.
              initialLocation: i == widget.navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'Atlas',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Memory',
            ),
          ],
        ),
      );
}
