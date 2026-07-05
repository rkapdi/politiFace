// lib/features/fcle/presentation/practice_screen.dart
//
// Weak-area / per-domain practice: immediate feedback with the explanation
// and the primary-source citation after every answer. Recently missed
// questions come first, then unseen ones.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../application/fcle_providers.dart';
import '../domain/fcle_question.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({required this.domainCode, super.key});

  final String domainCode;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  List<FcleQuestion>? _questions;
  int _index = 0;
  int _correct = 0;
  String? _chosenKey; // non-null = feedback showing
  bool _finished = false;

  FcleDomain get _domain =>
      FcleDomain.fromCode(widget.domainCode) ?? FcleDomain.values.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bank = await ref.read(questionBankProvider.future);
    final questions = await buildPracticeSet(
      bank: bank,
      dao: ref.read(databaseProvider).fcleAnswersDao,
      domain: _domain,
    );
    if (!mounted) return;
    setState(() => _questions = questions);
  }

  Future<void> _choose(String key) async {
    if (_chosenKey != null) return; // already answered
    final q = _questions![_index];
    HapticFeedback.lightImpact();
    setState(() {
      _chosenKey = key;
      if (q.isCorrect(key)) _correct++;
    });
    await ref.read(fcleAnswerRecorderProvider).record(
          question: q,
          chosenKey: key,
          inMock: false,
        );
  }

  void _next() {
    if (_index + 1 < _questions!.length) {
      setState(() {
        _index++;
        _chosenKey = null;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _questions;

    if (questions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_domain.label)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No published questions in this domain yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }
    if (_finished) {
      return _SummaryView(
        domain: _domain,
        correct: _correct,
        total: questions.length,
      );
    }

    final q = questions[_index];
    final answered = _chosenKey != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_domain.label} · ${_index + 1}/${questions.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  q.stem,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 20),
                for (final option in q.options)
                  _FeedbackOptionTile(
                    option: option,
                    answered: answered,
                    isAnswer: option.key == q.answerKey,
                    isChosen: option.key == _chosenKey,
                    onTap: () => _choose(option.key),
                  ),
                if (answered) ...[
                  const SizedBox(height: 12),
                  _ExplanationCard(question: q, theme: theme),
                ],
              ],
            ),
          ),
          if (answered)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    child: Text(
                      _index + 1 == questions.length ? 'FINISH' : 'NEXT',
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
    );
  }
}

class _FeedbackOptionTile extends StatelessWidget {
  const _FeedbackOptionTile({
    required this.option,
    required this.answered,
    required this.isAnswer,
    required this.isChosen,
    required this.onTap,
  });

  final FcleOption option;
  final bool answered;
  final bool isAnswer;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.brandGreen;
    final red = theme.colorScheme.brandRed;

    var border = theme.colorScheme.outlineVariant;
    Color? fill;
    if (answered && isAnswer) {
      border = green;
      fill = green.withOpacity(0.10);
    } else if (answered && isChosen && !isAnswer) {
      border = red;
      fill = red.withOpacity(0.10);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: answered ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: answered && (isAnswer || isChosen) ? 2 : 1),
            borderRadius: BorderRadius.circular(6),
            color: fill,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.key.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                ),
              ),
              if (answered && isAnswer)
                Icon(Icons.check_circle, color: green, size: 20)
              else if (answered && isChosen && !isAnswer)
                Icon(Icons.cancel, color: red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.question, required this.theme});

  final FcleQuestion question;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(question.citation),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(
                children: [
                  Icon(Icons.link,
                      size: 16, color: theme.colorScheme.primary,),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Source: ${Uri.parse(question.citation).host}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.domain,
    required this.correct,
    required this.total,
  });

  final FcleDomain domain;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice complete'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              '$correct / $total',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              domain.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              onPressed: () => context.go('/fcle'),
              child: const Text(
                'BACK TO FCLE PREP',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
