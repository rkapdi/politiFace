// lib/features/onboarding/presentation/onboarding_screen.dart
//
// The diagnostic cold open (Readiness Engine, Move 1). First launch opens
// into VALUE, not a feature tour: "Could you pass the FCLE right now?
// 10 questions." The diagnostic's answers feed the same local answer log
// that powers readiness, so the student lands on Home with the band
// already alive (endowed progress). Then two commitment questions
// disguised as setup: exam date, class code. Standing rules held: no
// signup wall, skippable at every step, supplemental-practice framing.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../fcle/application/fcle_providers.dart';
import '../../fcle/domain/fcle_question.dart';
import '../../home/application/home_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../../shared/widgets/neo/neo_kit.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const doneFlagKey = 'onboarding.done';

  /// Chosen exam date, ISO yyyy-mm-dd, or unset. The readiness hero and
  /// notification scheduling read this.
  static const examDateKey = 'fcle.exam_date';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Phase { invite, quiz, result }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Phase _phase = _Phase.invite;
  List<FcleQuestion> _questions = const [];
  int _index = 0;
  int _correct = 0;
  String? _chosenKey; // answered state for the current question
  DateTime? _examDate;

  Future<void> _finish(String route) async {
    final db = ref.read(databaseProvider);
    await db.metaDao.set(OnboardingScreen.doneFlagKey, '1');
    // The guided tour deliberately stays UNfamiliar here: it fires on the
    // first Home landing, after the diagnostic delivered value.
    if (_examDate != null) {
      await db.metaDao.set(
        OnboardingScreen.examDateKey,
        _examDate!.toIso8601String().substring(0, 10),
      );
    }
    if (!mounted) return;
    context.go(route);
  }

  Future<void> _startDiagnostic() async {
    final bank = await ref.read(questionBankProvider.future);
    if (bank.all.isEmpty) {
      // Bank not shipped in this build: never promise a test we cannot
      // give (DEF-02). Fall through to the app itself.
      await _finish('/');
      return;
    }
    // 10 questions: 3/3/2/2 across the four domains, shuffled, so the
    // starting projection has signal in every competency.
    final r = Random();
    final counts = [3, 3, 2, 2];
    final picked = <FcleQuestion>[];
    for (var i = 0; i < FcleDomain.values.length; i++) {
      final pool = [...?bank.byDomain[FcleDomain.values[i]]]..shuffle(r);
      picked.addAll(pool.take(counts[i]));
    }
    picked.shuffle(r);
    setState(() {
      _questions = picked;
      _phase = _Phase.quiz;
      _index = 0;
      _correct = 0;
      _chosenKey = null;
    });
  }

  Future<void> _answer(String key) async {
    if (_chosenKey != null) return;
    final q = _questions[_index];
    final correct = q.isCorrect(key);
    HapticFeedback.lightImpact();
    setState(() {
      _chosenKey = key;
      if (correct) _correct++;
    });
    // Feed the readiness log: the diagnostic IS the first drill.
    await ref
        .read(fcleAnswerRecorderProvider)
        .record(question: q, chosenKey: key, inMock: false);
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _phase = _Phase.result);
    } else {
      setState(() {
        _index++;
        _chosenKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
        child: switch (_phase) {
          _Phase.invite => _InviteView(
              onStart: _startDiagnostic,
              onSkip: () => _finish('/'),
            ),
          _Phase.quiz => _QuizView(
              question: _questions[_index],
              index: _index,
              total: _questions.length,
              chosenKey: _chosenKey,
              onChoose: _answer,
              onNext: _next,
              onSkip: () => _finish('/'),
            ),
          _Phase.result => _ResultView(
              correct: _correct,
              total: _questions.length,
              examDate: _examDate,
              onPickDate: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 30)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                  helpText: 'When do you plan to take the FCLE?',
                );
                if (picked != null) setState(() => _examDate = picked);
              },
              onClassCode: () => _finish('/leaderboard'),
              onDone: () => _finish('/'),
            ),
        },
      ),
    );
}

class _InviteView extends StatelessWidget {
  const _InviteView({required this.onStart, required this.onSkip});

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                'SKIP',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const Spacer(),
          Text('POLITIFACE', style: theme.textTheme.labelSmall),
          const SizedBox(height: 10),
          Text(
            'Could you pass the FCLE right now?',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 14),
          Text(
            'Florida requires the Civic Literacy Exam to graduate. '
            '10 questions, about 2 minutes, and you will know where '
            'you stand. Every question is cited to a primary source. '
            'Nothing partisan. Free.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const Spacer(flex: 2),
          BrutalButton(
            label: 'Start the diagnostic',
            subtitle: '10 questions · no account needed',
            onPressed: onStart,
          ),
          const SizedBox(height: 10),
          BrutalButton.quiet(
            label: 'Explore on my own',
            onPressed: onSkip,
          ),
        ],
      ),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.question,
    required this.index,
    required this.total,
    required this.chosenKey,
    required this.onChoose,
    required this.onNext,
    required this.onSkip,
  });

  final FcleQuestion question;
  final int index;
  final int total;
  final String? chosenKey;
  final ValueChanged<String> onChoose;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = chosenKey != null;
    final wasCorrect = answered && question.isCorrect(chosenKey!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THE DIAGNOSTIC',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Text(
                '${index + 1} / $total',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'SKIP',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress: hard-edged, signal fill.
          Container(
            height: 8,
            decoration: BoxDecoration(
              border: Border.all(color: EditorialPalette.line, width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (index + (answered ? 1 : 0)) / total,
              child: const ColoredBox(color: EditorialPalette.signal),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.domain.label.toUpperCase(),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(question.stem, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  for (final (i, opt) in question.options.indexed) ...[
                    _OptionRow(
                      key: Key('diag-opt-$i'),
                      option: opt,
                      state: !answered
                          ? _OptState.idle
                          : opt.key == question.answerKey
                              ? _OptState.correct
                              : opt.key == chosenKey
                                  ? _OptState.notYet
                                  : _OptState.dimmed,
                      onTap: answered ? null : () => onChoose(opt.key),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (answered) ...[
                    const SizedBox(height: 6),
                    Text(
                      wasCorrect ? 'Correct.' : 'Not yet.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: wasCorrect
                            ? theme.colorScheme.correctState
                            : theme.colorScheme.notyetState,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.explanation,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOURCE · ${question.citation}'.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (answered)
            BrutalButton(
              label: index + 1 >= total ? 'See your result' : 'Next',
              onPressed: onNext,
            ),
        ],
      ),
    );
  }
}

enum _OptState { idle, correct, notYet, dimmed }

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.state,
    required this.onTap,
    super.key,
  });

  final FcleOption option;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (bg, border, fg, suffix) = switch (state) {
      _OptState.idle => (
          dark ? EditorialPalette.slate2 : EditorialPalette.cardLt,
          dark ? EditorialPalette.mutedBorder : const Color(0xFF000000),
          theme.colorScheme.onSurface,
          '',
        ),
      _OptState.correct => (
          EditorialPalette.correct,
          EditorialPalette.correct,
          EditorialPalette.inkInverted,
          '  ✓',
        ),
      _OptState.notYet => (
          Colors.transparent,
          theme.colorScheme.notyetState,
          theme.colorScheme.notyetState,
          '  ○',
        ),
      _OptState.dimmed => (
          Colors.transparent,
          neoLineDim(context),
          theme.colorScheme.onSurfaceVariant,
          '',
        ),
    };

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 3),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration:
                  BoxDecoration(border: Border.all(color: fg, width: 2)),
              child: Text(
                option.key.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${option.text}$suffix',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontWeight:
                      state == _OptState.correct ? FontWeight.w500 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.correct,
    required this.total,
    required this.examDate,
    required this.onPickDate,
    required this.onClassCode,
    required this.onDone,
  });

  final int correct;
  final int total;
  final DateTime? examDate;
  final VoidCallback onPickDate;
  final VoidCallback onClassCode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The diagnostic just wrote 10 answers, so the shared readiness
    // provider has a real projection: the same numbers Home will show.
    final summary = ref.watch(readinessSummaryProvider).valueOrNull;
    final low = summary?.low ?? ((correct / total) * 80 - 8).round();
    final high = summary?.high ?? ((correct / total) * 80 + 8).round();
    final stage = summary == null
        ? (high >= 48 ? ReadinessStage.onTrack : ReadinessStage.notYet)
        : ReadinessHero.stageFor(summary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('YOUR STARTING POINT', style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          Text(
            '$correct of $total',
            style: theme.textTheme.displayMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Projected on the real exam: about $low–$high of 80. '
            'The pass line is 48. '
            '${high >= 48 ? "You are closer than most people start." : "Everyone starts somewhere; the daily loop is built for exactly this."}',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          PowerlineBar(active: stage),
          const Spacer(),
          BrutalButton.quiet(
            label: examDate == null
                ? 'When is your exam? Pick a date'
                : 'Exam date · ${examDate!.toIso8601String().substring(0, 10)}',
            onPressed: onPickDate,
          ),
          const SizedBox(height: 10),
          BrutalButton.quiet(
            label: 'I have a class code',
            onPressed: onClassCode,
          ),
          const SizedBox(height: 10),
          BrutalButton(
            label: 'Start studying',
            subtitle: 'your plan is ready · no account needed',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}
