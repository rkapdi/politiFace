// lib/features/onboarding/presentation/onboarding_screen.dart
//
// The diagnostic cold open (Readiness Engine, Move 1). First launch opens
// into VALUE, not a feature tour: "Could you pass the FCLE right now?
// 5 quick questions." The diagnostic's answers feed the same local answer
// log that powers readiness, so the student lands on Home with the band
// already alive (endowed progress). Then two optional commitment questions
// disguised as setup: exam date, class code. No signup wall and
// supplemental-practice framing still hold; the quiz itself is not
// skippable (founder decision, 2026-10-04: every student gets a starting
// point, and 5 short questions keep that cost to about a minute).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../fcle/application/fcle_providers.dart';
import '../../fcle/data/question_bank_loader.dart';
import '../../fcle/domain/fcle_question.dart';
import '../../fcle/domain/readiness_projection.dart';
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
    // Chokepoint bank: a brand-new user is unlikely to have hold-outs, but
    // a re-onboarding student in a cohort must not see reserved items.
    final bank = await ref.read(practiceBankProvider.future);
    if (bank.all.isEmpty) {
      // Bank not shipped in this build: never promise a test we cannot
      // give (DEF-02). Fall through to the app itself.
      await _finish('/');
      return;
    }
    final picked = pickDiagnosticQuestions(bank, Random());
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
          _Phase.invite => _InviteView(onStart: _startDiagnostic),
          _Phase.quiz => _QuizView(
              question: _questions[_index],
              index: _index,
              total: _questions.length,
              chosenKey: _chosenKey,
              onChoose: _answer,
              onNext: _next,
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
  const _InviteView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            '5 quick questions, about a minute, and you will know where '
            'you stand. Every question is cited to a primary source. '
            'Nothing partisan. Free.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const Spacer(flex: 2),
          BrutalButton(
            label: 'Start the diagnostic',
            subtitle: '5 questions · no account needed',
            onPressed: onStart,
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
  });

  final FcleQuestion question;
  final int index;
  final int total;
  final String? chosenKey;
  final ValueChanged<String> onChoose;
  final VoidCallback onNext;

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
    // The diagnostic just wrote its answers, so the shared readiness
    // provider has a real projection: the same numbers Home will show.
    // The fallback uses the same shrunk math, never a raw extrapolation.
    final summary = ref.watch(readinessSummaryProvider).valueOrNull;
    final fallback = fallbackProjection(correct, total);
    final low = summary?.low ?? fallback.low;
    final high = summary?.high ?? fallback.high;
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

/// How many questions the onboarding diagnostic deals.
const diagnosticQuestionCount = 5;

/// Reading load of a question: stem plus every option, in characters.
int _readLength(FcleQuestion q) =>
    q.stem.length + q.options.fold(0, (n, o) => n + o.text.length);

/// 5 quick diagnostic questions: one per domain plus one more from a
/// random domain, so the starting projection has signal in every
/// competency. Within each domain only quick items qualify: no longer
/// than the domain's median reading length and difficulty 3 or below.
/// A thin domain tops up with its shortest remaining items. Pure so the
/// hold-out contamination test can assert reserved items never appear.
List<FcleQuestion> pickDiagnosticQuestions(QuestionBank bank, Random r) {
  const domains = FcleDomain.values;
  final extra = r.nextInt(domains.length);
  final picked = <FcleQuestion>[];
  for (var i = 0; i < domains.length; i++) {
    final need = i == extra ? 2 : 1;
    final all = [...?bank.byDomain[domains[i]]]
      ..sort((a, b) => _readLength(a).compareTo(_readLength(b)));
    if (all.isEmpty) continue;
    final median = _readLength(all[(all.length - 1) ~/ 2]);
    final quick = all
        .where((q) => _readLength(q) <= median && q.difficulty <= 3)
        .toList()
      ..shuffle(r);
    final chosen = quick.take(need).toList();
    for (final q in all) {
      if (chosen.length >= need) break;
      if (!chosen.contains(q)) chosen.add(q);
    }
    picked.addAll(chosen);
  }
  picked.shuffle(r);
  return picked;
}
