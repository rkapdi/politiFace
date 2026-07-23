// lib/features/leaderboard/presentation/leaderboard_screen.dart
//
// Class leaderboard. Three states: signed out (inline sign-in, then
// straight into the join view), signed in with no class (join by code),
// in a class (ranked pseudonymous handles, own row highlighted).
// Multiple classes get a simple chip switcher. Scores are
// server-authoritative; this screen only reads.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../features/settings/presentation/account_section.dart';
import '../../live/application/live_session_controller.dart';
import '../../live/data/live_session_api.dart';
import '../application/leaderboard_providers.dart';
import '../data/leaderboard_api.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String? _selectedCohortId;
  bool _joiningAnother = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    ref.watch(authStateProvider);

    Widget body;
    if (auth == null) {
      // Unconfigured build: the feature is dark, nothing to sign in to.
      body = const _CenteredNote(
        icon: Icons.wifi_off,
        text: 'Class leaderboards are not available in this build.',
      );
    } else if (!auth.isSignedIn) {
      body = _CenteredNote(
        icon: Icons.person_outline,
        text: 'Your professor shares a class code. Sign in with your '
            'email, then enter the code right here.',
        actionLabel: 'SIGN IN',
        // The shared routine flushes the outbox and restores this
        // account's progress; auth listeners rebuild into the join view.
        onAction: () => showAccountSignInSheet(context, ref),
      );
    } else {
      final cohorts = ref.watch(myCohortsProvider);
      body = cohorts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const _CenteredNote(
          icon: Icons.wifi_off,
          text: 'Could not load your classes. Pull to retry.',
        ),
        data: (list) => list.isEmpty || _joiningAnother
            ? _JoinView(
                onCancel: list.isEmpty
                    ? null
                    : () => setState(() => _joiningAnother = false),
                onJoined: (cohortId) {
                  ref.invalidate(myCohortsProvider);
                  setState(() {
                    _selectedCohortId = cohortId;
                    _joiningAnother = false;
                  });
                },
              )
            : _BoardView(
                cohorts: list,
                selectedId: _selectedCohortId ?? list.first.id,
                onSelect: (id) => setState(() => _selectedCohortId = id),
                onJoinAnother: () => setState(() => _joiningAnother = true),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class leaderboard'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myCohortsProvider);
          final list = ref.read(myCohortsProvider).valueOrNull;
          final id = _selectedCohortId ??
              (list == null || list.isEmpty ? null : list.first.id);
          if (id != null) ref.invalidate(leaderboardEntriesProvider(id));
        },
        child: body,
      ),
    );
  }
}

class _JoinView extends ConsumerStatefulWidget {
  const _JoinView({required this.onJoined, this.onCancel});

  /// Called with the newly joined cohort's id.
  final void Function(String cohortId) onJoined;

  /// When non-null, the student already belongs to at least one class, so
  /// this view was opened from the board and can be dismissed without
  /// joining.
  final VoidCallback? onCancel;

  @override
  ConsumerState<_JoinView> createState() => _JoinViewState();
}

class _JoinViewState extends ConsumerState<_JoinView> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final api = ref.read(leaderboardApiProvider);
    if (api == null || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cohortId = await api.joinCohort(_code.text);
      widget.onJoined(cohortId);
    } on PostgrestException {
      // A server verdict on the code itself (e.g. no matching cohort):
      // the code is genuinely wrong.
      setState(
        () => _error = 'That code did not work. Check with your '
            'professor and try again.',
      );
    } catch (_) {
      // Network/socket/timeout failures never reached the server, so the
      // code itself has not been judged; do not blame it.
      setState(
        () => _error = 'Could not reach the server. Check your '
            'connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Join your class',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the class code your professor shared. Leaderboards show '
          'generated handles only, never names or emails.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Class code',
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
          onPressed: _busy ? null : _join,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'JOIN CLASS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : widget.onCancel,
              child: const Text('CANCEL'),
            ),
          ),
        ],
      ],
    );
  }
}

class _BoardView extends ConsumerStatefulWidget {
  const _BoardView({
    required this.cohorts,
    required this.selectedId,
    required this.onSelect,
    required this.onJoinAnother,
  });

  final List<CohortInfo> cohorts;
  final String selectedId;
  final void Function(String) onSelect;
  final VoidCallback onJoinAnother;

  @override
  ConsumerState<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<_BoardView> {
  ActiveLiveSession? _live;
  Timer? _livePoll;

  @override
  void initState() {
    super.initState();
    // A running live session shows up within one check on entry and then
    // within 20 seconds while the board stays visible.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLive());
    _livePoll = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkLive(),
    );
  }

  @override
  void didUpdateWidget(_BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      setState(() => _live = null);
      unawaited(_checkLive());
    }
  }

  @override
  void dispose() {
    _livePoll?.cancel();
    super.dispose();
  }

  Future<void> _checkLive() async {
    final api = ref.read(liveSessionApiProvider);
    if (api == null || !mounted) return;
    // Only while this board is front-most; a pushed route pauses checks.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    try {
      final live = await api.activeSession(widget.selectedId);
      if (!mounted) return;
      setState(() => _live = live);
    } catch (_) {
      // Offline blip: keep the last known state; the next tick retries.
    }
  }

  Future<void> _openLive(ActiveLiveSession live) async {
    await context.push(
      '/live',
      extra: LiveSessionArgs(sessionId: live.id, title: live.title),
    );
    if (mounted) unawaited(_checkLive());
  }

  Future<void> _joinLiveByCode() async {
    final api = ref.read(liveSessionApiProvider);
    if (api == null) return;
    final joined = await showDialog<JoinedLiveSession>(
      context: context,
      builder: (dialogContext) => _LiveCodeDialog(api: api),
    );
    if (joined == null || !mounted) return;
    await context.push(
      '/live',
      extra: LiveSessionArgs(sessionId: joined.id, title: joined.title),
    );
    if (mounted) unawaited(_checkLive());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cohorts = widget.cohorts;
    final selectedId = widget.selectedId;
    final entries = ref.watch(leaderboardEntriesProvider(selectedId));
    final myId = ref.watch(authServiceProvider)?.currentUser?.id;
    final live = _live;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (live != null) ...[
          _LiveNowBanner(live: live, onJoin: () => _openLive(live)),
          const SizedBox(height: 16),
        ],
        if (cohorts.length > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final c in cohorts)
                ChoiceChip(
                  label: Text(c.name),
                  selected: c.id == selectedId,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    widget.onSelect(c.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            cohorts.first.term == null
                ? cohorts.first.name
                : '${cohorts.first.name} · ${cohorts.first.term}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onJoinAnother,
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'JOIN ANOTHER CLASS',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: _joinLiveByCode,
              icon: const Icon(Icons.sensors, size: 16),
              label: const Text(
                'JOIN A LIVE SESSION',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        entries.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Could not load the board.')),
          ),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    'No scores yet. Correct answers in practice and mocks '
                    'earn points for the board.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final entry in rows)
                      _EntryRow(entry: entry, isMe: entry.userId == myId),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Points are one per correct answer, counted by the server. '
          'Handles are generated; no names or emails appear here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The board-top call to a running session. Loud on purpose: this is the
/// one moment the class is together in the room.
class _LiveNowBanner extends StatelessWidget {
  const _LiveNowBanner({required this.live, required this.onJoin});

  final ActiveLiveSession live;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.colorScheme.brandRed;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: red.withOpacity(0.08),
          border: Border.all(color: red, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.sensors, color: red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE NOW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live.title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onJoin,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'JOIN',
                style:
                    TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session-code prompt for the quiet entry point. The code is the one the
/// professor puts on screen; it works even when the banner has not caught
/// up yet or the session belongs to another of the student's classes.
class _LiveCodeDialog extends StatefulWidget {
  const _LiveCodeDialog({required this.api});

  final LiveSessionApi api;

  @override
  State<_LiveCodeDialog> createState() => _LiveCodeDialogState();
}

class _LiveCodeDialogState extends State<_LiveCodeDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final joined = await widget.api.joinByCode(_code.text);
      if (mounted) Navigator.of(context).pop(joined);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.message.toLowerCase().contains('join the class')
            ? 'Join that class on this board first, then enter the '
                'session code.'
            : 'That code did not match a running session. Check the '
                'screen at the front and try again.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not reach the server. Check your connection '
            'and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Join a live session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the session code your professor is showing.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            onSubmitted: (_) => _join(),
            decoration: const InputDecoration(
              labelText: 'Session code',
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _busy ? null : _join,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('JOIN'),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    // One semantic node per row: "#3, handle, 42".
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? green.withOpacity(0.10) : null,
          border: Border.all(
            color: isMe
                ? green.withOpacity(0.55)
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.rank}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: entry.rank <= 3
                      ? theme.colorScheme.brandOchreText
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                isMe ? '${entry.handle} (you)' : entry.handle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${entry.score}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

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
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
