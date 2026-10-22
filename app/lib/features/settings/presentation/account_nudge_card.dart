// lib/features/settings/presentation/account_nudge_card.dart
//
// One dismissible nudge toward the optional account, shown on the session
// summary screen. Never a wall: it renders only on backend-configured
// builds, only while signed out, and disappears forever once dismissed
// (AppMeta 'nudge.account_dismissed'). Signing in stays optional everywhere.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'account_section.dart';

/// Whether the nudge should render: configured build + signed out + never
/// dismissed. Auth changes flip it off live (it watches authStateProvider).
final accountNudgeVisibleProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final auth = ref.watch(authServiceProvider);
  if (auth == null) return false;
  ref.watch(authStateProvider);
  if (auth.isSignedIn) return false;
  final dismissed = await ref
      .watch(databaseProvider)
      .metaDao
      .get(AccountNudgeCard.dismissedMetaKey);
  return dismissed == null;
});

class AccountNudgeCard extends ConsumerWidget {
  const AccountNudgeCard({super.key});

  static const dismissedMetaKey = 'nudge.account_dismissed';

  Future<void> _dismiss(WidgetRef ref) async {
    await ref.read(databaseProvider).metaDao.set(dismissedMetaKey, '1');
    ref.invalidate(accountNudgeVisibleProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(accountNudgeVisibleProvider).valueOrNull ?? false;
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keep your progress',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to save your streak and cards across devices.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismiss(ref),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const Text('NOT NOW'),
                ),
                TextButton(
                  onPressed: () => showAccountSignInSheet(context, ref),
                  child: const Text('SIGN IN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
