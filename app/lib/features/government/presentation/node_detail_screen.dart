import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/application/session_controller.dart';
import '../../shared/widgets/state_views.dart';
import '../application/node_detail_data.dart';

class NodeDetailScreen extends ConsumerWidget {
  const NodeDetailScreen({super.key, required this.nodeId});
  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nodeDetailProvider(nodeId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Node'),
        leading: IconButton(
          tooltip: 'Back to map',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/map'),
        ),
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load node',
          message: '$e',
          onRetry: () => ref.invalidate(nodeDetailProvider(nodeId)),
        ),
        data: (detail) {
          if (detail == null) {
            return const AppEmptyView(
              icon: Icons.search_off,
              title: 'Node not found',
              body: 'This node might have been removed.',
            );
          }
          return _NodeView(detail: detail);
        },
      ),
    );
  }
}

class _NodeView extends ConsumerWidget {
  const _NodeView({required this.detail});
  final NodeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = detail.node;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(n.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          n.nodeType.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        if (n.description != null && n.description!.isNotEmpty)
          Text(n.description!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Text('Decks', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.decks.isEmpty)
          _EmptyDecks(theme: theme)
        else
          ...detail.decks.map((d) => _DeckTile(
                deck: d,
                onTap: () {
                  ref.read(activeSessionDeckIdProvider.notifier).state = d.id;
                  ref.invalidate(sessionControllerProvider);
                  context.go('/session');
                },
              )),
      ],
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck, required this.onTap});
  final LocalDeck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(deck.name),
        subtitle: Text('${deck.cardCount} cards'),
        trailing: FilledButton(
          onPressed: onTap,
          child: const Text('Start'),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _EmptyDecks extends StatelessWidget {
  const _EmptyDecks({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No decks yet for this node. Content coming soon.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
