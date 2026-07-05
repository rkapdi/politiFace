// lib/features/settings/presentation/account_section.dart
//
// Optional account (email OTP via Supabase). Rendered only in builds with
// backend config; local builds never show it. Signing in is never required
// to play: it unlocks sync, class join codes, and leaderboards. The
// server-side profile is a generated pseudonymous handle; the email stays
// in Supabase Auth and is never shown on any leaderboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/sync/auth_service.dart';

final profileHandleProvider = FutureProvider<String?>((ref) async {
  ref.watch(authStateProvider);
  final auth = ref.watch(authServiceProvider);
  if (auth == null || !auth.isSignedIn) return null;
  return auth.profileHandle();
});

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
          'Optional. Backs up progress and unlocks class leaderboards.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showSignInSheet(context, ref, auth),
      );
    }

    final handle = ref.watch(profileHandleProvider).valueOrNull;
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(handle ?? 'Signed in'),
      subtitle: const Text('Progress syncs when you play.'),
      trailing: TextButton(
        onPressed: () async {
          await auth.signOut();
          ref.invalidate(profileHandleProvider);
        },
        child: const Text('SIGN OUT'),
      ),
    );
  }

  Future<void> _showSignInSheet(
    BuildContext context,
    WidgetRef ref,
    AuthService auth,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _SignInSheet(auth: auth),
      ),
    );
    ref.invalidate(profileHandleProvider);
    // Deliver anything recorded while signed out was dropped by design;
    // this drains events from any previous signed-in run.
    await ref.read(syncEngineProvider).flush();
  }
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.auth});

  final AuthService auth;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = 'That did not work. Check and try again.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign in', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _codeSent
                  ? 'Enter the 6-digit code we emailed you.'
                  : 'We email you a one-time code. No password, no account '
                      'profile beyond a generated handle.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!_codeSent) {
                        await _run(() async {
                          await widget.auth.requestOtp(_email.text);
                          setState(() => _codeSent = true);
                        });
                      } else {
                        final navigator = Navigator.of(context);
                        await _run(() async {
                          await widget.auth.verifyOtp(
                            email: _email.text,
                            code: _code.text,
                          );
                          navigator.pop();
                        });
                      }
                    },
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? 'VERIFY' : 'SEND CODE'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
