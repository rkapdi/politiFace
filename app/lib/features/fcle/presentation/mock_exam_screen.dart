// lib/features/fcle/presentation/mock_exam_screen.dart
//
// The Mock FCLE: 80 questions in domain order, no feedback until the end,
// mirroring the real exam. Answers are recorded (locally + outbox) as they
// are given; grading happens at the finish and routes to the result screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/fcle_providers.dart';
import '../domain/fcle_question.dart';
import '../domain/mock_engine.dart';

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  static const _engine = MockEngine();

  MockAssembly? _assembly;
  final _answers = <String, String>{};
  int _index = 0;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    // Assemble once the bank resolves; the hub only links here when the
    // bank can supply a full mock.
    ref.read(questionBankProvider.future).then((bank) {
      if (!mounted) return;
      setState(() => _assembly = _engine.assemble(bank));
    });
  }

  Future<void> _next() async {
    final assembly = _assembly;
    final chosen = _selectedKey;
    if (assembly == null || chosen == null) return;
    final q = assembly.questions[_index];
    _answers[q.id] = chosen;

    // Record now, not at the end: a backgrounded/killed app still keeps
    // every given answer in the local log and outbox.
    await ref.read(fcleAnswerRecorderProvider).record(
          question: q,
          chosenKey: chosen,
          inMock: true,
        );
    if (!mounted) return;

    if (_index + 1 < assembly.questions.length) {
      setState(() {
        _index++;
        _selectedKey = null;
      });
    } else {
      final result = _engine.grade(assembly, _answers);
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
    final assembly = _assembly;

    if (assembly == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = assembly.questions[_index];
    final total = assembly.questions.length;

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
                    onPressed: _selectedKey == null ? null : _next,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    child: Text(
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
    );
  }
}
