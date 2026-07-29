// lib/features/class_inbox/presentation/class_inbox_screen.dart
//
// Read-only class inbox: every message a professor has sent, grouped by
// class, newest class first, newest message first within a class. Reached
// from the class leaderboard's "Class messages" tile and from tapping the
// visible alert push the class-announce Edge Function sends (see
// NotificationService.onSelectRoute in main.dart, and the "route": "/class"
// field that push carries).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/class_inbox_providers.dart';
import '../data/class_inbox_api.dart';

class ClassInboxScreen extends ConsumerWidget {
  const ClassInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    ref.watch(authStateProvider);

    Widget body;
    if (auth == null) {
      body = const _CenteredNote(
        icon: Icons.wifi_off,
        text: 'Class messages are not available in this build.',
      );
    } else if (!auth.isSignedIn) {
      body = const _CenteredNote(
        icon: Icons.person_outline,
        text: 'Sign in and join a class to see messages from your '
            'professor here.',
      );
    } else {
      body = const ClassInboxBody();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class messages'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(classInboxProvider),
        child: body,
      ),
    );
  }
}

/// The signed-in inbox view: loading, error, empty, and data states over
/// [classInboxProvider]. Public (not the usual leading-underscore private
/// widget) so it can be pumped directly in widget tests without threading
/// a signed-in auth state through [ClassInboxScreen], mirroring
/// JoinCohortView in leaderboard_screen.dart.
class ClassInboxBody extends ConsumerWidget {
  const ClassInboxBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(classInboxProvider);
    return inbox.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _CenteredNote(
        icon: Icons.wifi_off,
        text: 'Could not load your messages. Pull to retry.',
      ),
      data: (groups) => groups.isEmpty
          ? const _CenteredNote(
              icon: Icons.mail_outline,
              text: 'No messages yet. Your professor can send reminders '
                  'here.',
            )
          : _InboxList(groups: groups),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.groups});

  final List<ClassInboxGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final group in groups) ...[
          Text(
            group.term == null
                ? group.className
                : '${group.className} · ${group.term}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final message in group.messages) _MessageTile(message: message),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final ClassAnnouncement message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            formatRelativeTime(message.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 64),
        Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
