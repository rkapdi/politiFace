// lib/features/fcle/presentation/mock_exam_screen.dart
//
// The Mock FCLE: 80 questions in domain order, no feedback until the end,
// mirroring the real exam. The session behind the screen is server-backed
// when signed in (mock_attempts, the efficacy instrument) and local
// otherwise; the screen cannot tell the difference. Answers persist one by
// one, so a backgrounded or killed app loses nothing already given.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../application/mock_session_provider.dart';
import '../domain/fcle_question.dart';
import '../domain/mock_session.dart';

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  int _index = 0;
  String? _selectedKey;
  bool _finishing = false;

  /// In-flight submits. Advancing never waits on the network, but finish
  /// waits for every answer to settle so finalize cannot race a submit.
  final _pending = <Future<void>>[];

  Future<void> _next(MockSession session) async {
    final chosen = _selectedKey;
    if (chosen == null || _finishing) return;
    final q = session.questions[_index];

    if (_index + 1 < session.questions.length) {
      setState(() {
        _index++;
        _selectedKey = null;
      });
      _pending.add(
        session.submit(q, chosen).catchError((Object _) {}),
      );
    } else {
      setState(() => _finishing = true);
      _pending.add(
        session.submit(q, chosen).catchError((Object _) {}),
      );
      await Future.wait(_pending);
      final result = await session.finish();

      // Count completed mocks: the first one is the baseline.
      final meta = ref.read(databaseProvider).metaDao;
      final completed =
          int.tryParse(await meta.get(kCompletedMocksMetaKey) ?? '0') ?? 0;
      await meta.set(kCompletedMocksMetaKey, '${completed + 1}');

      if (!mounted) return;
      context.pushReplacement('/fcle/result', extra: result);
    }
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the mock?'),
        content: const Text(
          'Answers so far still count toward your readiness, but this '
          'mock attempt will not be scored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP GOING'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(mockSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Mock FCLE')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not assemble a mock right now. Check back once more '
              'questions are published.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
      data: (session) => _buildExam(context, theme, session),
    );
  }

  Widget _buildExam(
    BuildContext context,
    ThemeData theme,
    MockSession session,
  ) {
    final q = session.questions[_index];
    final total = session.questions.length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (await _confirmExit()) router.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_index + 1} of $total'),
          leading: IconButton(
            tooltip: 'Leave mock',
            icon: const Icon(Icons.close),
            onPressed: () async {
              final router = GoRouter.of(context);
              if (await _confirmExit()) router.pop();
            },
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 3,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    q.domain.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    q.stem,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  for (final option in q.options)
                    _OptionTile(
                      option: option,
                      selected: _selectedKey == option.key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedKey = option.key);
                      },
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedKey == null || _finishing
                        ? null
                        : () => _next(session),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    child: _finishing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _index + 1 == total ? 'FINISH MOCK' : 'NEXT',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final FcleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
                borderRadius: BorderRadius.circular(6),
                color: selected
                    ? theme.colorScheme.primary.withOpacity(0.06)
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.key.toUpperCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
