import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/state_views.dart';

/// Library-style detail page for a single politician (card).
///
/// Atlas converts from "tap to study" into "tap to learn about this
/// person" — same widget powers locked + unlocked cards. The "study this
/// node" CTA stays available through the round and NodeDetailScreen.
///
/// Content sources:
///   - card fields (name, title, party, jurisdiction, photo, source)
///     from LocalCards
///   - Wikipedia bio via [politicianBioProvider] (cached, async)
///   - "Also appears in" — query LocalCards by normalized name across
///     all decks
class PoliticianDetailScreen extends ConsumerWidget {
  const PoliticianDetailScreen({required this.cardId, super.key});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(_cardByIdProvider(cardId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/map');
            }
          },
        ),
        title: const Text('Politician'),
      ),
      body: cardAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load',
          message: '$e',
          onRetry: () => ref.invalidate(_cardByIdProvider(cardId)),
        ),
        data: (card) {
          if (card == null) {
            return AppEmptyView(
              icon: Icons.help_outline,
              title: 'Card not found',
              body: 'This card no longer exists in the local database.',
              action: FilledButton(
                onPressed: () => context.go('/map'),
                child: const Text('Back to Atlas'),
              ),
            );
          }
          return _DetailBody(card: card, theme: theme);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.card, required this.theme});

  final LocalCard card;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bioAsync = ref.watch(politicianBioProvider(card.id));
    final alsoAsync = ref.watch(_alsoAppearsInProvider(card.politicianName));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header — portrait + name + title ─────────────────────────
          Center(
            child: CardAvatar(
              name: card.politicianName,
              radius: 60,
              photoUrl: card.photoUrl,
              lqipBase64: card.lqipBase64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            card.politicianName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            card.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          _FactStrip(card: card),
          const SizedBox(height: 14),

          // ── Memory stats (Anki-style: curve + FSRS stats + history) ──
          Center(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/memory/card/${card.id}'),
              icon: const Icon(Icons.show_chart_rounded, size: 18),
              label: const Text(
                'MY MEMORY OF THIS CARD',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Bio (Wikipedia lead paragraph) ──────────────────────────
          const _SectionHeader(label: 'BIOGRAPHY'),
          const SizedBox(height: 10),
          _BioSection(bioAsync: bioAsync),
          const SizedBox(height: 24),

          // ── Also appears in (deck membership across the app) ────────
          const _SectionHeader(label: 'ALSO IN'),
          const SizedBox(height: 10),
          alsoAsync.when(
            loading: () => const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Couldn\'t load other decks: $e',
              style: theme.textTheme.bodySmall,
            ),
            data: (decks) {
              if (decks.isEmpty) {
                return Text(
                  'Only appears in the current deck.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final deck in decks) _DeckChip(deck: deck),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Source link ─────────────────────────────────────────────
          if (card.sourceUrl.isNotEmpty)
            _LinkRow(
              icon: Icons.link_rounded,
              label: 'Official source',
              url: card.sourceUrl,
            ),
          // ── Wikipedia link (only when bio has loaded) ───────────────
          bioAsync.maybeWhen(
            data: (bio) {
              final url = bio?.wikipediaUrl;
              if (url == null || url.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _LinkRow(
                  icon: Icons.public_rounded,
                  label: 'Wikipedia',
                  url: url,
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.card});
  final LocalCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <(String, String)>[];
    if ((card.party ?? '').isNotEmpty) facts.add(('PARTY', card.party!));
    if ((card.jurisdiction ?? '').isNotEmpty) {
      facts.add(('JURISDICTION', card.jurisdiction!));
    }
    if (facts.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 26,
              color: theme.colorScheme.outlineVariant,
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
          Column(
            children: [
              Text(
                facts[i].$1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                facts[i].$2,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BioSection extends StatelessWidget {
  const _BioSection({required this.bioAsync});

  final AsyncValue<PoliticianBio?> bioAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return bioAsync.when(
      loading: () => Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading bio…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      error: (e, _) => Text(
        'Bio unavailable.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      data: (bio) {
        final extract = bio?.bioExtract;
        if (extract == null || extract.isEmpty) {
          final reason = bio?.lastErrorMessage ?? 'Not yet fetched.';
          return Text(
            'Bio not available yet. ($reason)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        return Text(
          extract,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        );
      },
    );
  }
}

class _DeckChip extends StatelessWidget {
  const _DeckChip({required this.deck});
  final LocalDeck deck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: theme.colorScheme.outline, width: 1.2),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(
        deck.name,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: EditorialPalette.civicNavy),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: EditorialPalette.civicNavy,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

// ── Providers local to this screen ──────────────────────────────────────

final _cardByIdProvider = FutureProvider.family<LocalCard?, String>(
  (ref, cardId) async {
    final db = ref.watch(databaseProvider);
    return db.cardsDao.cardById(cardId);
  },
);

/// Returns the decks (other than the politician's primary deck) that
/// contain a card with the same politicianName. Used by the "Also in"
/// section to surface cross-deck cameos.
final _alsoAppearsInProvider =
    FutureProvider.family<List<LocalDeck>, String>((ref, name) async {
  final db = ref.watch(databaseProvider);
  final allCards = await db.cardsDao.allActiveCards();
  final matches = allCards.where((c) => c.politicianName == name).toList();
  if (matches.length <= 1) return const [];
  final deckIds = matches.map((c) => c.deckId).toSet();
  final allDecks = await db.decksDao.allDecks();
  return allDecks.where((d) => deckIds.contains(d.id)).toList();
});
