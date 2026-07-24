// lib/features/settings/presentation/account_section.dart
//
// Optional account (email OTP via Supabase). Rendered only in builds with
// backend config; local builds never show it. Signing in is never required
// to play: it unlocks sync, class join codes, and leaderboards. The
// server-side profile is a generated pseudonymous handle; the email stays
// in Supabase Auth and is never shown on any leaderboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/sync/restore_service.dart';
import '../../../core/sync/sign_in_sheet.dart';
import '../../account/application/account_providers.dart';
import '../../account/domain/avatars.dart';
import '../../decks/application/deck_providers.dart';

final profileHandleProvider = FutureProvider<String?>((ref) async {
  ref.watch(authStateProvider);
  final auth = ref.watch(authServiceProvider);
  if (auth == null || !auth.isSignedIn) return null;
  return auth.profileHandle();
});

/// Opens the email-OTP sign-in sheet and, when the user signs in, restores
/// any progress the account already carries (cross-device sync). Shared by
/// the Settings account row and the post-session nudge card. Safe to call
/// anywhere: no-ops on unconfigured builds and never throws.
Future<void> showAccountSignInSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final auth = ref.read(authServiceProvider);
  if (auth == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showSignInSheet(context, auth);
  ref.invalidate(profileHandleProvider);
  if (!auth.isSignedIn) return; // sheet dismissed without signing in

  // Account switch guard: this device may hold another account's progress
  // (and undelivered outbox events). Never mix them; ask, then start the
  // new account clean before anything flushes under the new session.
  const kAccountUidKey = 'sync.account_uid';
  final db = ref.read(databaseProvider);
  final uid = auth.currentUser?.id;
  final stored = await db.metaDao.get(kAccountUidKey);
  if (stored != null && uid != null && stored != uid) {
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch accounts?'),
        content: const Text(
          'This device has progress from a different account. Continue to '
          'load this account\'s progress instead. Anything the other '
          'account had not yet synced from this device will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    if (proceed != true) {
      await auth.signOut();
      ref.invalidate(profileHandleProvider);
      return;
    }
    await wipeLocalUserState(db);
  }
  if (uid != null) await db.metaDao.set(kAccountUidKey, uid);

  // Deliver anything recorded while signed out was dropped by design;
  // this drains events from any previous signed-in run.
  await ref.read(syncEngineProvider).flush();
  // Pull this account's progress and merge it into the local database.
  final summary = await ref.read(restoreServiceProvider).restoreNow();
  // Refresh everything that renders streak/XP/chapter/deck state.
  ref.read(sessionTickProvider.notifier).state++;
  ref.read(deckSubscriptionTickProvider.notifier).state++;
  if (summary.cardsRestored > 0) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Progress restored: ${summary.cardsRestored} cards.'),
      ),
    );
  }
}

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final auth = ref.watch(authServiceProvider);
    if (auth == null) return const SizedBox.shrink();

    if (!auth.isSignedIn) {
      return ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Sign in'),
        subtitle: const Text(
          'Optional. Keeps your progress on all your devices and unlocks '
          'class leaderboards.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showAccountSignInSheet(context, ref),
      );
    }

    final handle = ref.watch(profileHandleProvider).valueOrNull;
    final avatarId = ref.watch(myAccountProvider).valueOrNull?.avatarId ?? 0;
    return ListTile(
      leading: PolitifaceAvatar(avatarId: avatarId, size: 36),
      title: Text(handle ?? 'Signed in'),
      subtitle: const Text(
        'Progress syncs across your devices. Tap to manage your account.',
      ),
      trailing: TextButton(
        onPressed: () async {
          await auth.signOut();
          ref.invalidate(profileHandleProvider);
          ref.invalidate(myAccountProvider);
        },
        child: const Text('SIGN OUT'),
      ),
      onTap: () => context.push('/account'),
    );
  }
}
