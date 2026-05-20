import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Shell widget that hosts the top-level tabs (Home, Learn) with a persistent
/// bottom NavigationBar. Routes outside [StatefulShellRoute] (session,
/// summary, node detail, settings, onboarding) render without this chrome.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          navigationShell.goBranch(
            i,
            // Tapping a tab you're already on pops the branch to its initial
            // route — matches iOS expectations.
            initialLocation: i == navigationShell.currentIndex,
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
            label: 'Learn',
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
}
