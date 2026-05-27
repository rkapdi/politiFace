import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/drift/app_database.dart';
import '../features/curriculum/data/chapter_progress_service.dart';
import '../features/curriculum/data/content_linker.dart';
import '../features/curriculum/data/curriculum_loader.dart';
import '../features/curriculum/domain/curriculum.dart';
import '../features/daily_challenge/data/daily_challenge_service.dart';
import '../features/government/data/node_unlock_service.dart';
import '../features/profile/data/profile_service.dart';
import '../features/session/data/card_review_repository.dart';
import '../features/session/data/pending_session_store.dart';
import '../features/session/domain/fsrs_algorithm.dart';
import 'router.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden in ProviderScope (set in main.dart).',
  );
});

final fsrsProvider = Provider<FSRS>((ref) => const FSRS());

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(databaseProvider));
});

final cardReviewRepositoryProvider = Provider<CardReviewRepository>((ref) {
  return CardReviewRepository(
    ref.watch(databaseProvider),
    ref.watch(fsrsProvider),
    ref.watch(profileServiceProvider),
  );
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  // Watching the session controller forces a refetch after every review.
  ref.watch(sessionTickProvider);
  return ref.watch(profileServiceProvider).load();
});

/// Bumped by SessionController after each grade so [profileProvider] refetches.
final sessionTickProvider = StateProvider<int>((ref) => 0);

final nodeUnlockServiceProvider = Provider<NodeUnlockService>((ref) {
  return NodeUnlockService(ref.watch(databaseProvider));
});

final dailyChallengeServiceProvider = Provider<DailyChallengeService>((ref) {
  return DailyChallengeService(ref.watch(databaseProvider));
});

final pendingSessionStoreProvider = Provider<PendingSessionStore>((ref) {
  return PendingSessionStore(ref.watch(databaseProvider));
});

/// When non-null, SessionController loads the daily challenge cards for this
/// YYYY-MM-DD date instead of the global FSRS-driven queue.
final activeDailyChallengeDateProvider = StateProvider<String?>((_) => null);

/// Today's challenge state (cards + grades if played). Refetches via tick.
final dailyChallengeTodayProvider =
    FutureProvider<DailyChallenge?>((ref) async {
  ref.watch(sessionTickProvider);
  return ref.watch(dailyChallengeServiceProvider).challengeFor();
});

/// Initial route, set in main() based on the onboarding flag.
final initialRouteProvider = Provider<String>((ref) => '/');

final routerProvider = Provider<GoRouter>((ref) {
  return buildRouter(initialLocation: ref.read(initialRouteProvider));
});

// Null = global session (FSRS-driven across all decks).
// Set by NodeDetailScreen before navigating to /session.
final activeSessionDeckIdProvider = StateProvider<String?>((ref) => null);

/// Whether the current card's answer is revealed. Resets to false when
/// SessionController advances to the next card.
final cardRevealedProvider = StateProvider<bool>((ref) => false);

// The Learn tab now renders a single OSINT-style progression tree
// (OrgChartMap). The previous Path / System toggle and its provider have
// been retired.

// ── Curriculum (chapter-aware daily round) ──────────────────────────────────

final curriculumLoaderProvider = Provider<CurriculumLoader>((_) {
  return CurriculumLoader();
});

/// Parsed `us_civics.yaml`. Loaded once per app launch; cached for the
/// lifetime of the Riverpod scope.
final curriculumProvider = FutureProvider<Curriculum>((ref) async {
  return ref.watch(curriculumLoaderProvider).load();
});

final chapterProgressServiceProvider =
    Provider<ChapterProgressService>((ref) {
  return ChapterProgressService(ref.watch(databaseProvider));
});

final contentLinkerProvider = Provider<ContentLinker>((ref) {
  return ContentLinker(ref.watch(databaseProvider));
});

/// The user's current in-progress chapter entry, or null when the season is
/// done. Returns null while [curriculumProvider] is still loading.
///
/// Drives the home-screen "Today's Round: Chapter X · Day Y of Z" CTA.
/// Refetches when [sessionTickProvider] bumps (so completing a round
/// immediately reflects in the UI).
final currentChapterProgressProvider =
    FutureProvider<ChapterProgressEntry?>((ref) async {
  ref.watch(sessionTickProvider);
  final curriculum = await ref.watch(curriculumProvider.future);
  return ref.watch(chapterProgressServiceProvider).currentProgress(curriculum);
});
