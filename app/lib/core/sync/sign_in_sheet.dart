// lib/core/sync/sign_in_sheet.dart
//
// The shared email-OTP sign-in sheet. Lives here (not in settings) so any
// surface that needs an account, the Settings account row, the class
// leaderboard, the keep-your-progress nudge, can open the same flow in
// place instead of sending the user on a trip through Settings.

import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Shows the sign-in bottom sheet and completes when it closes. Callers
/// that care whether sign-in happened should check `auth.isSignedIn`
/// afterward (auth state listeners rebuild dependents automatically).
Future<void> showSignInSheet(BuildContext context, AuthService auth) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SignInSheet(auth: auth),
      ),
    );

class SignInSheet extends StatefulWidget {
  const SignInSheet({required this.auth, super.key});

  final AuthService auth;

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
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
