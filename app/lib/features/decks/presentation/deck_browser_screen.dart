// lib/features/decks/presentation/deck_browser_screen.dart
//
// The deck browser: curated decks (always in rotation this release) and
// per-state delegation decks the user can subscribe to. Toggling a deck
// off pauses it; FSRS state is never deleted. A Study affordance opens a
// deck-scoped session whether or not the deck is subscribed
// (try before committing to the daily rotation).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/application/session_controller.dart';
import '../application/deck_providers.dart';

const kDeckPausedSnackBar =
    'Paused. Your progress is saved and these cards return when you turn the deck back on.';
const kDeckAddedSnackBar =
    'Added to your rotation. New faces will appear in your daily reviews.';

class DeckBrowserScreen extends ConsumerWidget {
  const DeckBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(deckBrowserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Decks')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load decks.')),
        data: (view) => ListView(
          children: [
            _SectionHeader(text: 'Core decks', theme: theme),
            for (final deck in view.curated)
              ListTile(
                title: Text(deck.name),
                subtitle: Text('Always in rotation · ${deck.cardCount} cards'),
              ),
            const Divider(height: 32),
            _SectionHeader(text: 'State delegations', theme: theme),
            for (final deck in view.delegations)
              _DelegationRow(
                deck: deck,
                isHomeState: view.homeState != null &&
                    deck.id == delegationDeckId(view.homeState!),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _DelegationRow extends ConsumerWidget {
  const _DelegationRow({required this.deck, required this.isHomeState});

  final LocalDeck deck;
  final bool isHomeState;

  void _study(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(activeSessionDeckIdProvider.notifier).state = deck.id;
    ref.read(activeSessionCardIdsProvider.notifier).state = null;
    ref.invalidate(sessionControllerProvider);
    context.push('/session');
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    HapticFeedback.selectionClick();
    await setDeckSubscribed(ref, deckId: deck.id, subscribed: value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? kDeckAddedSnackBar : kDeckPausedSnackBar),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      // Tapping an unsubscribed row previews the deck in a study session.
      onTap: deck.isSubscribed ? null : () => _study(context, ref),
      title: Row(
        children: [
          Flexible(child: Text(deck.name)),
          if (isHomeState) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Your state',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('${deck.cardCount} members'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _study(context, ref),
            child: const Text('Study'),
          ),
          Switch(
            value: deck.isSubscribed,
            onChanged: (v) => _toggle(context, ref, v),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
