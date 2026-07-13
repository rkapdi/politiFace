// lib/features/decks/application/deck_providers.dart
//
// State for the deck browser: curated and delegation deck lists, the
// home-state pin, and the single write path for subscription toggles.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../atlas/application/people_providers.dart';

/// Bumped on every subscription toggle so deck lists refetch.
final deckSubscriptionTickProvider = StateProvider<int>((ref) => 0);

/// Deck id for a state's delegation deck ('FL' -> 'deck_delegation-fl').
String delegationDeckId(String stateCode) =>
    'deck_delegation-${stateCode.toLowerCase()}';

class DeckBrowserData {
  const DeckBrowserData({
    required this.curated,
    required this.delegations,
    required this.homeState,
  });

  final List<LocalDeck> curated;

  /// Delegation decks, alphabetical, with the home-state deck pinned first.
  final List<LocalDeck> delegations;

  /// Two-letter home state code, or null when the user never picked one.
  final String? homeState;
}

final deckBrowserProvider = FutureProvider<DeckBrowserData>((ref) async {
  ref.watch(deckSubscriptionTickProvider);
  final db = ref.watch(databaseProvider);
  final curated = await db.decksDao.decksByCategory('curated');
  final delegations = await db.decksDao.decksByCategory('delegation');
  final homeState = await db.metaDao.get(kHomeStateMetaKey);
  if (homeState != null) {
    final homeId = delegationDeckId(homeState);
    final idx = delegations.indexWhere((d) => d.id == homeId);
    if (idx > 0) {
      final home = delegations.removeAt(idx);
      delegations.insert(0, home);
    }
  }
  return DeckBrowserData(
    curated: curated,
    delegations: delegations,
    homeState: homeState,
  );
});

/// The delegation deck for a two-letter state code, or null before the
/// seeder has run. Refreshes on subscription toggles.
final delegationDeckForStateProvider =
    FutureProvider.family<LocalDeck?, String>((ref, stateCode) {
  ref.watch(deckSubscriptionTickProvider);
  return ref
      .watch(databaseProvider)
      .decksDao
      .deckById(delegationDeckId(stateCode));
});

/// Flip a deck's subscription and refresh every consumer. The session
/// controller is intentionally NOT invalidated here: the next session
/// build reads fresh subscription-filtered queries, so a toggle can never
/// strand an in-flight session.
Future<void> setDeckSubscribed(
  WidgetRef ref, {
  required String deckId,
  required bool subscribed,
}) async {
  await ref
      .read(databaseProvider)
      .decksDao
      .setSubscribed(deckId: deckId, subscribed: subscribed);
  ref.read(deckSubscriptionTickProvider.notifier).state++;
  ref.read(sessionTickProvider.notifier).state++;
}
