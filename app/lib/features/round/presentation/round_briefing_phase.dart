import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../curriculum/domain/curriculum.dart';
import '../domain/round_state.dart';

/// Briefing phase of the daily round: today's lessons as swipeable readable
/// pages — the teach step that precedes the cards. No grading, no timer.
/// The last page's CTA advances to the cards phase via
/// [DailyRoundController.completeBriefing].
class RoundBriefingPhase extends ConsumerStatefulWidget {
  const RoundBriefingPhase({required this.state, super.key});
  final DailyRoundState state;

  @override
  ConsumerState<RoundBriefingPhase> createState() =>
      _RoundBriefingPhaseState();
}

class _RoundBriefingPhaseState extends ConsumerState<RoundBriefingPhase> {
  final _pageController = PageController();
  int _page = 0;

  List<Lesson> get _lessons => widget.state.lessons;
  bool get _onLastPage => _page >= _lessons.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    HapticFeedback.lightImpact();
    if (_onLastPage) {
      await ref
          .read(dailyRoundControllerProvider.notifier)
          .completeBriefing();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'READ FIRST · ${_page + 1} OF ${_lessons.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _lessons.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _LessonPage(lesson: _lessons[i]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _lessons.length; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? EditorialPalette.ochre
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i != _lessons.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _advance,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _onLastPage ? 'START CARDS' : 'NEXT',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: EditorialPalette.ochre,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              'LESSON',
              style: theme.textTheme.labelSmall?.copyWith(
                color: EditorialPalette.ink,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            lesson.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lesson.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
            ),
          ),
          if (lesson.source != null) ...[
            const SizedBox(height: 16),
            Text(
              'Source: ${Uri.tryParse(lesson.source!)?.host ?? lesson.source!}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
