import 'package:go_router/go_router.dart';

import '../features/endless/presentation/endless_screen.dart';
import '../features/government/presentation/gov_map_screen.dart';
import '../features/government/presentation/node_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/memory/presentation/memory_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/session/presentation/session_screen.dart';
import '../features/session/presentation/summary_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trivia/presentation/trivia_result_screen.dart';
import '../features/trivia/presentation/trivia_screen.dart';
import 'shell_scaffold.dart';

GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const GovMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/memory',
                builder: (context, state) => const MemoryScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes — render without the bottom navigation bar.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/node/:id',
        builder: (context, state) =>
            NodeDetailScreen(nodeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => const SessionScreen(),
      ),
      GoRoute(
        path: '/summary',
        builder: (context, state) => const SummaryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/endless',
        builder: (context, state) => const EndlessScreen(),
      ),
      GoRoute(
        path: '/trivia',
        builder: (context, state) => const TriviaScreen(),
      ),
      GoRoute(
        path: '/trivia/result',
        builder: (context, state) => const TriviaResultScreen(),
      ),
    ],
  );
}
