import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/drift/app_database.dart';
import '../features/atlas/data/branch_info_loader.dart';
import '../features/atlas/data/wikipedia_bio_service.dart';
import '../features/curriculum/data/chapter_progress_service.dart';
import '../features/curriculum/data/content_linker.dart';
import '../features/curriculum/data/curriculum_loader.dart';
import '../features/curriculum/domain/curriculum.dart';
import '../features/round/application/daily_round_controller.dart';
import '../features/round/data/chapter_content_sampler.dart';
import '../features/round/domain/round_state.dart';
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

/// All chapter entries for the active season (in-progress + completed),
/// ordered by start time. Drives the Season Spine widget on home.
final seasonProgressProvider =
    FutureProvider<List<ChapterProgressEntry>>((ref) async {
  ref.watch(sessionTickProvider);
  final curriculum = await ref.watch(curriculumProvider.future);
  return ref
      .watch(chapterProgressServiceProvider)
      .seasonProgress(curriculum.season.id);
});

// ── Atlas branch info (library blurbs) ──────────────────────────────────────

final branchInfoLibraryProvider = FutureProvider<BranchInfoLibrary>((ref) {
  return BranchInfoLoader().load();
});

// ── Wikipedia bio service + per-card bio stream ─────────────────────────────

final wikipediaBioServiceProvider = Provider<WikipediaBioService>((ref) {
  return WikipediaBioService(ref.watch(databaseProvider));
});

/// Reactive bio for a single card. Subscribes to PoliticianBios row
/// updates so the screen rebuilds when a fetch completes. Also triggers
/// `ensureBio` once on first watch — fire-and-forget.
final politicianBioProvider =
    StreamProvider.family<PoliticianBio?, String>((ref, cardId) {
  final service = ref.watch(wikipediaBioServiceProvider);
  // Fire-and-forget — DB watch picks up the row when fetch lands.
  unawaited(service.ensureBio(cardId));
  return ref.watch(databaseProvider).politicianBiosDao.watch(cardId);
});

// ── Daily Round (chapter-aware ritual) ──────────────────────────────────────

final chapterContentSamplerProvider = Provider<ChapterContentSampler>((ref) {
  return ChapterContentSampler(
    ref.watch(databaseProvider),
    ref.watch(contentLinkerProvider),
  );
});

/// The active round for today. Loads existing (mid-flight) or creates a new
/// one on first read for the current date.
final dailyRoundControllerProvider =
    AsyncNotifierProvider<DailyRoundController, DailyRoundState>(() {
  return DailyRoundController();
});

/// Lightweight check: has today's round been completed yet? Reads the
/// `daily_rounds` DAO directly so home can render a "Played" badge
/// without triggering the heavier round-controller build (which would
/// sample + persist a fresh round just from visiting home).
final todayRoundPlayedProvider = FutureProvider<bool>((ref) async {
  ref.watch(sessionTickProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final today = '${now.year}-${two(now.month)}-${two(now.day)}';
  final row = await db.dailyRoundsDao.get(
    userId: ChapterProgressService.defaultUserId,
    dateIso: today,
  );
  return row?.completedAt != null;
});
