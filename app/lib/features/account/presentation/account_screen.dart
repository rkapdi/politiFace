// lib/features/account/presentation/account_screen.dart
//
// Account management: avatar picker, handle (the leaderboard display
// name), an optional school label, sign out, and account deletion. Only
// meaningful when signed in; the settings Account section (the only
// current entry point) already gates its "Manage account" row on
// SupabaseConfig.isConfigured + auth.isSignedIn, but this screen checks
// again so a stale deep link never shows a broken form. Talks to the
// server exclusively through ProfileApi (update_my_profile /
// delete_my_account, see supabase/migrations/20260724000500_
// account_management.sql) so tests fake the network.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/sync/supabase_config.dart';
import '../application/account_providers.dart';
import '../data/profile_api.dart';
import '../domain/avatars.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    ref.watch(authStateProvider);

    if (!SupabaseConfig.isConfigured || auth == null || !auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('Sign in to manage your account.')),
      );
    }

    final account = ref.watch(myAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Could not load your account. Pull to retry.'),
        ),
        data: (profile) => AccountBody(
          key: ValueKey(profile?.avatarId ?? -1),
          initial: profile ??
              const ProfileUpdate(handle: null, school: null, avatarId: 0),
          signOut: auth.signOut,
          onSignedOut: () {
            ref.invalidate(myAccountProvider);
            if (!context.mounted) return;
            context.canPop() ? context.pop() : context.go('/settings');
          },
          onDeleted: () {
            ref.invalidate(myAccountProvider);
            if (!context.mounted) return;
            context.go('/');
          },
        ),
      ),
    );
  }
}

/// The editable account form: avatar grid, handle, school, sign out, and
/// the danger-zone delete. Public (not the usual leading-underscore private
/// widget), like leaderboard's JoinCohortView, so it can be pumped directly
/// in widget tests against a fake [ProfileApi] without threading a
/// signed-in Supabase session through [AccountScreen]. [signOut],
/// [onSignedOut], and [onDeleted] are injected rather than reached via
/// authServiceProvider/go_router directly, for the same reason: AuthService
/// wraps a real SupabaseClient with no fake seam yet, so session
/// termination and post-action navigation are the caller's job.
class AccountBody extends ConsumerStatefulWidget {
  const AccountBody({
    required this.initial,
    required this.signOut,
    required this.onSignedOut,
    required this.onDeleted,
    super.key,
  });

  final ProfileUpdate initial;

  /// Terminates the Supabase session (AuthService.signOut in production).
  final Future<void> Function() signOut;

  /// Called after a successful sign-out, so the caller can navigate away.
  final VoidCallback onSignedOut;

  /// Called after a successful account deletion (and the sign-out that
  /// follows it), so the caller can navigate away.
  final VoidCallback onDeleted;

  @override
  ConsumerState<AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends ConsumerState<AccountBody> {
  late int _avatarId = widget.initial.avatarId;
  late final _handle = TextEditingController(text: widget.initial.handle);
  late final _school = TextEditingController(text: widget.initial.school);

  bool _savingHandle = false;
  bool _savingSchool = false;
  String? _handleError;
  String? _schoolError;
  String? _handleSuccess;
  String? _schoolSuccess;

  @override
  void dispose() {
    _handle.dispose();
    _school.dispose();
    super.dispose();
  }

  ProfileApi? get _api => ref.read(profileApiProvider);

  Future<void> _pickAvatar(int id) async {
    final api = _api;
    if (api == null || id == _avatarId) return;
    final previous = _avatarId;
    HapticFeedback.selectionClick();
    setState(() => _avatarId = id); // optimistic
    try {
      await api.updateProfile(avatarId: id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _avatarId = previous); // revert on failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your avatar. Try again.'),
        ),
      );
    }
  }

  Future<void> _saveHandle() async {
    final api = _api;
    if (api == null) return;
    final value = _handle.text.trim();
    setState(() {
      _savingHandle = true;
      _handleError = null;
      _handleSuccess = null;
    });
    try {
      final result = await api.updateProfile(handle: value);
      if (!mounted) return;
      setState(() {
        _handle.text = result.handle ?? value;
        _handleSuccess = 'Saved.';
      });
    } on PostgrestException catch (e) {
      // Server verdict on the handle itself; show it verbatim (e.g.
      // "That handle is taken.").
      if (!mounted) return;
      setState(() => _handleError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _handleError = 'Could not reach the server. Try again.',
      );
    } finally {
      if (mounted) setState(() => _savingHandle = false);
    }
  }

  Future<void> _saveSchool() async {
    final api = _api;
    if (api == null) return;
    final value = _school.text.trim();
    setState(() {
      _savingSchool = true;
      _schoolError = null;
      _schoolSuccess = null;
    });
    try {
      await api.updateProfile(school: value);
      if (!mounted) return;
      setState(() => _schoolSuccess = 'Saved.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _schoolError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _schoolError = 'Could not reach the server. Try again.',
      );
    } finally {
      if (mounted) setState(() => _savingSchool = false);
    }
  }

  Future<void> _signOut() async {
    await widget.signOut();
    if (!mounted) return;
    widget.onSignedOut();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and all your progress. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final api = _api;
    if (api == null) return;

    HapticFeedback.heavyImpact();
    try {
      await api.deleteAccount();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Try again.'),
        ),
      );
      return;
    }
    // The account row is already gone server-side; sign out locally and
    // leave no stale session behind.
    await widget.signOut();
    if (!mounted) return;
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(child: PolitifaceAvatar(avatarId: _avatarId, size: 96)),
        const SizedBox(height: 24),
        Text('Choose an avatar', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _AvatarGrid(selected: _avatarId, onSelect: _pickAvatar),
        const SizedBox(height: 32),
        Text('Display name', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'This is the name other students see on leaderboards.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _handle,
          autocorrect: false,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: 'Handle',
            border: OutlineInputBorder(),
          ),
        ),
        if (_handleError != null) ...[
          const SizedBox(height: 4),
          Text(
            _handleError!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (_handleSuccess != null) ...[
          const SizedBox(height: 4),
          Text(
            _handleSuccess!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.brandGreen),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingHandle ? null : _saveHandle,
            child: _savingHandle
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SAVE'),
          ),
        ),
        const SizedBox(height: 32),
        Text('School', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Optional. A label you choose, not verified.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _school,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'School',
            border: OutlineInputBorder(),
          ),
        ),
        if (_schoolError != null) ...[
          const SizedBox(height: 4),
          Text(
            _schoolError!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (_schoolSuccess != null) ...[
          const SizedBox(height: 4),
          Text(
            _schoolSuccess!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.brandGreen),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingSchool ? null : _saveSchool,
            child: _savingSchool
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SAVE'),
          ),
        ),
        const Divider(height: 48),
        OutlinedButton(
          onPressed: _signOut,
          child: const Text('SIGN OUT'),
        ),
        const SizedBox(height: 32),
        Text(
          'DANGER ZONE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.error,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _confirmDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error, width: 1.5),
          ),
          child: const Text('DELETE ACCOUNT'),
        ),
        const SizedBox(height: 8),
        Text(
          'This permanently deletes your account and all your progress. '
          'This cannot be undone.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kAvatarCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final isSelected = index == selected;
        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Avatar ${index + 1}',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => onSelect(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: PolitifaceAvatar(avatarId: index),
            ),
          ),
        );
      },
    );
  }
}
