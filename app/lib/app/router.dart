import 'package:go_router/go_router.dart';

import '../features/atlas/presentation/atlas_screen.dart';
import '../features/atlas/presentation/congress_directory_screen.dart';
import '../features/atlas/presentation/executive_orders_screen.dart';
import '../features/atlas/presentation/person_screen.dart';
import '../features/atlas/presentation/politician_detail_screen.dart';
import '../features/atlas/presentation/recent_laws_screen.dart';
import '../features/atlas/presentation/vocabulary_screen.dart';
import '../features/decks/presentation/deck_browser_screen.dart';
import '../features/endless/presentation/endless_result_screen.dart';
import '../features/endless/presentation/endless_review_screen.dart';
import '../features/endless/presentation/endless_screen.dart';
import '../features/fcle/domain/mock_engine.dart';
import '../features/fcle/presentation/fcle_blueprint_screen.dart';
import '../features/fcle/presentation/fcle_hub_screen.dart';
import '../features/fcle/presentation/mock_exam_screen.dart';
import '../features/fcle/presentation/mock_result_screen.dart';
import '../features/fcle/presentation/practice_screen.dart';
import '../features/government/presentation/node_detail_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/memory/presentation/card_retention_detail_screen.dart';
import '../features/memory/presentation/memory_screen.dart';
import '../features/pulse/presentation/pulse_screen.dart';
import '../features/round/presentation/daily_round_screen.dart';
import '../features/round/presentation/round_review_screen.dart';
import '../features/session/presentation/session_screen.dart';
import '../features/session/presentation/summary_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trivia/presentation/trivia_result_screen.dart';
import '../features/trivia/presentation/trivia_review_screen.dart';
import '../features/trivia/presentation/trivia_screen.dart';
import 'shell_scaffold.dart';

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
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
                  builder: (context, state) => const AtlasScreen(),
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
          path: '/node/:id',
          builder: (context, state) =>
              NodeDetailScreen(nodeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/politician/:cardId',
          builder: (context, state) =>
              PoliticianDetailScreen(cardId: state.pathParameters['cardId']!),
        ),
        GoRoute(
          path: '/session',
          builder: (context, state) => const SessionScreen(),
        ),
        GoRoute(
          path: '/round',
          builder: (context, state) => const DailyRoundScreen(),
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
          path: '/decks',
          builder: (context, state) => const DeckBrowserScreen(),
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
        GoRoute(
          path: '/trivia/review',
          builder: (context, state) => TriviaReviewScreen(
            runId: state.uri.queryParameters['runId'],
          ),
        ),
        GoRoute(
          path: '/round/review',
          builder: (context, state) => RoundReviewScreen(
            runId: state.uri.queryParameters['runId'],
          ),
        ),
        GoRoute(
          path: '/endless/result',
          builder: (context, state) => const EndlessResultScreen(),
        ),
        GoRoute(
          path: '/endless/review',
          builder: (context, state) => EndlessReviewScreen(
            runId: state.uri.queryParameters['runId'],
          ),
        ),
        GoRoute(
          path: '/memory/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/atlas/congress',
          builder: (context, state) => const CongressDirectoryScreen(),
        ),
        GoRoute(
          path: '/person/:id',
          builder: (context, state) =>
              PersonScreen(personId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/atlas/orders',
          builder: (context, state) => const ExecutiveOrdersScreen(),
        ),
        GoRoute(
          path: '/atlas/laws',
          builder: (context, state) => const RecentLawsScreen(),
        ),
        GoRoute(
          path: '/atlas/vocabulary',
          builder: (context, state) => const VocabularyScreen(),
        ),
        GoRoute(
          path: '/pulse',
          builder: (context, state) => const PulseScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/fcle',
          builder: (context, state) => const FcleHubScreen(),
        ),
        GoRoute(
          path: '/fcle/mock',
          builder: (context, state) => const MockExamScreen(),
        ),
        GoRoute(
          path: '/fcle/result',
          builder: (context, state) =>
              MockResultScreen(result: state.extra! as MockResult),
        ),
        GoRoute(
          path: '/fcle/blueprint',
          builder: (context, state) => const FcleBlueprintScreen(),
        ),
        GoRoute(
          path: '/fcle/practice',
          builder: (context, state) => PracticeScreen(
            domainCode: state.uri.queryParameters['domain'] ?? '',
            objective: state.uri.queryParameters['objective'],
          ),
        ),
        GoRoute(
          path: '/memory/card/:cardId',
          builder: (context, state) => CardRetentionDetailScreen(
            cardId: state.pathParameters['cardId']!,
          ),
        ),
      ],
    );
