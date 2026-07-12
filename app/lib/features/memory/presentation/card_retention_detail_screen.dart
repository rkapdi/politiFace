import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/editorial_theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/drift/app_database.dart';
import '../../session/domain/fsrs_algorithm.dart';
import '../../session/domain/mastery.dart';
import '../../shared/widgets/card_avatar.dart';
import '../../shared/widgets/mastery_stars.dart';
import '../../shared/widgets/state_views.dart';

/// Per-card retention detail: plots the FSRS forgetting curve across the
/// card's whole review history (a "sawtooth" that dips as memory fades and
/// jumps back up each time you review), marks where you are today and when
/// the next review is due, and shows plain-language strength stats.
///
/// All FSRS jargon (stability, difficulty, retrievability) is translated to
/// days / percentages / plain words — the learner never sees the raw terms.
class CardRetentionDetailScreen extends ConsumerWidget {
  const CardRetentionDetailScreen({required this.cardId, super.key});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cardRetentionProvider(cardId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/memory');
            }
          },
        ),
        title: const Text('Memory'),
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          title: 'Failed to load',
          message: '$e',
          onRetry: () => ref.invalidate(_cardRetentionProvider(cardId)),
        ),
        data: (data) {
          final card = data.card;
          if (card == null) {
            return AppEmptyView(
              icon: Icons.help_outline,
              title: 'Card not found',
              body: 'This card no longer exists in the local database.',
              action: FilledButton(
                onPressed: () => context.go('/memory'),
                child: const Text('Back to Memory'),
              ),
            );
          }
          return _RetentionBody(data: data);
        },
      ),
    );
  }
}

class _RetentionBody extends StatelessWidget {
  const _RetentionBody({required this.data});
  final _CardRetention data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = data.card!;
    final state = data.state;
    final logs = data.logs;

    // A card needs at least one real review to have a curve worth showing.
    final hasHistory = state != null && !state.isNew && logs.isNotEmpty;

    final displayName =
        card.politicianName.isNotEmpty ? card.politicianName : card.title;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — avatar + name + title.
          Row(
            children: [
              CardAvatar(
                name: displayName,
                radius: 28,
                photoUrl: card.photoUrl,
                lqipBase64: card.lqipBase64,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (card.title.isNotEmpty && card.title != displayName)
                      Text(
                        card.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasHistory)
            _TooEarly(reviewCount: state?.reviewCount ?? 0)
          else
            _CurveSection(state: state, logs: logs),
        ],
      ),
    );
  }
}

class _TooEarly extends StatelessWidget {
  const _TooEarly({required this.reviewCount});
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Too early to chart',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            reviewCount == 0
                ? 'Review this card in a daily round and your memory curve '
                    'will start to take shape here.'
                : "You've reviewed this once. A couple more reviews and the "
                    'forgetting curve will appear.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CurveSection extends StatelessWidget {
  const _CurveSection({required this.state, required this.logs});
  final CardMemoryState state;
  final List<ReviewLog> logs;

  static const _fsrs = FSRS();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final t0 = logs.first.reviewedAt;
    final lastReviewedAt = logs.last.reviewedAt;
    final lastStability = logs.last.stability;
    final dueS = state.nextReviewAt;

    // Plot domain: from the first review to a little past whichever is later,
    // "now" or the due date — so both markers are always visible with margin.
    final endAnchor = math.max(dueS, nowS);
    final spanSeconds = math.max(endAnchor - t0, 1);
    final endS = endAnchor + (spanSeconds * 0.08).round();
    final xMaxDays = math.max((endS - t0) / 86400.0, 0.001);

    double dayOf(int unixS) => (unixS - t0) / 86400.0;

    // Sawtooth segments — one per review, each decaying with that review's
    // resulting stability until the next review (or the chart's end).
    final segments = <_Segment>[];
    for (var i = 0; i < logs.length; i++) {
      final startDay = dayOf(logs[i].reviewedAt);
      final endDay =
          i < logs.length - 1 ? dayOf(logs[i + 1].reviewedAt) : xMaxDays;
      segments.add(
        _Segment(
          startDay: startDay,
          endDay: endDay,
          stability: logs[i].stability,
        ),
      );
    }

    // Review dots: each plotted at the retention it had decayed to right
    // before that review (the bottom of the dip), colored by the grade given.
    // The first review starts fresh, so it sits at the top.
    final dots = <_ReviewDot>[];
    for (var i = 0; i < logs.length; i++) {
      final x = dayOf(logs[i].reviewedAt);
      double r;
      if (i == 0) {
        r = 1;
      } else {
        final elapsed = (logs[i].reviewedAt - logs[i - 1].reviewedAt) / 86400.0;
        r = _fsrs.retrievabilityCurve(elapsed, logs[i - 1].stability);
      }
      dots.add(_ReviewDot(day: x, retention: r, grade: logs[i].grade));
    }

    final rNow = _fsrs.retrievabilityCurve(
      (nowS - lastReviewedAt) / 86400.0,
      lastStability,
    );
    final strength = (rNow * 100).round();
    final level = masteryLevelFromStability(
      isNewCard: false,
      stability: state.stability,
    );
    final status = _Status.of(rNow, dueS, nowS);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Strength + status pill.
        Row(
          children: [
            MasteryStars(level: level),
            const Spacer(),
            _StatusPill(status: status),
          ],
        ),
        const SizedBox(height: 16),
        // The curve.
        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    painter: _RetentionCurvePainter(
                      segments: segments,
                      dots: dots,
                      xMaxDays: xMaxDays,
                      nowDay: dayOf(nowS),
                      dueDay: dayOf(dueS),
                      rNow: rNow,
                      targetRetention: 0.9,
                      progress: t,
                      curveColor: theme.colorScheme.primary,
                      nowColor: theme.colorScheme.onSurface,
                      dueColor: const Color(0xFFC9A05B),
                      gridColor: theme.colorScheme.outlineVariant,
                      labelColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _CurveLegend(labelColor: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Plain-language stats.
        _StatGrid(
          strengthPct: strength,
          dueLabel: _formatDue(dueS, nowS),
          reviewCount: state.reviewCount,
          lapses: state.lapses,
          durabilityDays: state.stability,
          difficulty: state.difficulty,
        ),
        const SizedBox(height: 16),
        Text(
          _explainer(strength, status),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _HistorySection(logs: logs),
      ],
    );
  }

  String _explainer(int strength, _Status status) {
    switch (status) {
      case _Status.strong:
        return "Solid. You'd recall this about $strength% of the time right "
            'now — it won\'t need a refresh for a while.';
      case _Status.holding:
        return 'Holding steady at about $strength% recall. Each review '
            'stretches the gap before it fades.';
      case _Status.fading:
        return 'Starting to fade — around $strength% recall. A review soon '
            'will lock it back in.';
      case _Status.atRisk:
        return 'This one has slipped to about $strength% recall. Review it in '
            'your next round to rescue it.';
    }
  }

  static String _formatDue(int dueS, int nowS) {
    final days = (dueS - nowS) / 86400.0;
    if (days <= -1.5) return 'Overdue ${(-days).round()}d';
    if (days < 0.5) return 'Due today';
    if (days < 1.5) return 'Due tomorrow';
    return 'In ${days.round()}d';
  }
}

enum _Status {
  strong('Strong', Color(0xFF34D399)),
  holding('Holding', Color(0xFF60A5FA)),
  fading('Fading', Color(0xFFFFB74D)),
  atRisk('At risk', Color(0xFFE57373));

  const _Status(this.label, this.color);
  final String label;
  final Color color;

  static _Status of(double rNow, int dueS, int nowS) {
    if (nowS > dueS && rNow < 0.9) {
      // Past due — bias toward urgency.
      if (rNow < 0.5) return _Status.atRisk;
      if (rNow < 0.75) return _Status.fading;
    }
    if (rNow >= 0.9) return _Status.strong;
    if (rNow >= 0.75) return _Status.holding;
    if (rNow >= 0.5) return _Status.fading;
    return _Status.atRisk;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final _Status status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: status.color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: status.color.withOpacity(0.5)),
        ),
        child: Text(
          status.label.toUpperCase(),
          style: TextStyle(
            color: status.color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _CurveLegend extends StatelessWidget {
  const _CurveLegend({required this.labelColor});
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: labelColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    Widget swatch(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: style),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        swatch(const Color(0xFFE57373), 'Forgot'),
        swatch(const Color(0xFF81C784), 'Recalled'),
        swatch(const Color(0xFFFFD54F), 'Easy'),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.strengthPct,
    required this.dueLabel,
    required this.reviewCount,
    required this.lapses,
    required this.durabilityDays,
    required this.difficulty,
  });

  final int strengthPct;
  final String dueLabel;
  final int reviewCount;
  final int lapses;
  final double durabilityDays;
  final double difficulty;

  String get _durability {
    if (durabilityDays < 1) return '<1d';
    if (durabilityDays < 10) return '${durabilityDays.toStringAsFixed(1)}d';
    return '${durabilityDays.round()}d';
  }

  /// FSRS difficulty runs 1-10; students get the plain read.
  String get _difficultyLabel {
    if (difficulty < 4) return 'Easy';
    if (difficulty < 7) return 'Medium';
    return 'Hard';
  }

  @override
  Widget build(BuildContext context) {
    final cells = <(String, String)>[
      ('$strengthPct%', 'Recall now'),
      (dueLabel, 'Next review'),
      (_durability, 'Memory lasts'),
      ('$reviewCount', 'Times reviewed'),
      ('$lapses', 'Times forgotten'),
      ('$_difficultyLabel (${difficulty.toStringAsFixed(1)})', 'Difficulty'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final c in cells) _StatCell(value: c.$1, label: c.$2)],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────

class _Segment {
  const _Segment({
    required this.startDay,
    required this.endDay,
    required this.stability,
  });
  final double startDay;
  final double endDay;
  final double stability;
}

class _ReviewDot {
  const _ReviewDot({
    required this.day,
    required this.retention,
    required this.grade,
  });
  final double day;
  final double retention;
  final int grade; // 0 again, 1 hard, 2 good, 3 easy
}

Color _gradeColor(int grade) {
  switch (grade) {
    case 0:
      return const Color(0xFFE57373); // again — red
    case 1:
      return const Color(0xFFFFB74D); // hard — orange
    case 3:
      return const Color(0xFFFFD54F); // easy — gold
    case 2:
    default:
      return const Color(0xFF81C784); // good — green
  }
}

class _RetentionCurvePainter extends CustomPainter {
  _RetentionCurvePainter({
    required this.segments,
    required this.dots,
    required this.xMaxDays,
    required this.nowDay,
    required this.dueDay,
    required this.rNow,
    required this.targetRetention,
    required this.progress,
    required this.curveColor,
    required this.nowColor,
    required this.dueColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<_Segment> segments;
  final List<_ReviewDot> dots;
  final double xMaxDays;
  final double nowDay;
  final double dueDay;
  final double rNow;
  final double targetRetention;
  final double progress; // 0..1 entrance reveal
  final Color curveColor;
  final Color nowColor;
  final Color dueColor;
  final Color gridColor;
  final Color labelColor;

  static const _fsrs = FSRS();
  static const _padL = 6.0;
  static const _padR = 6.0;
  static const _padT = 8.0;
  static const _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - _padL - _padR;
    final plotH = size.height - _padT - _padB;
    if (plotW <= 0 || plotH <= 0) return;

    double xToPx(double day) => _padL + (day / xMaxDays) * plotW;
    double yToPx(double r) => _padT + (1 - r.clamp(0.0, 1.0)) * plotH;

    // Horizontal gridlines at 25/50/75/100%.
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.5)
      ..strokeWidth = 1;
    for (final r in [0.25, 0.5, 0.75, 1.0]) {
      final y = yToPx(r);
      canvas.drawLine(
        Offset(_padL, y),
        Offset(size.width - _padR, y),
        gridPaint,
      );
    }

    // Target retention line (90%) — dashed, the "review before this" floor.
    _drawDashedLine(
      canvas,
      Offset(_padL, yToPx(targetRetention)),
      Offset(size.width - _padR, yToPx(targetRetention)),
      Paint()
        ..color = dueColor.withOpacity(0.55)
        ..strokeWidth = 1.2,
    );

    // Build the sawtooth curve path by sampling each segment.
    final path = Path();
    var started = false;
    final revealDay = xMaxDays * progress;
    for (final seg in segments) {
      final segStart = seg.startDay;
      final segEnd = math.min(seg.endDay, revealDay);
      if (segEnd < segStart) break;
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final day = segStart + (segEnd - segStart) * (i / steps);
        final elapsed = day - seg.startDay;
        final r = _fsrs.retrievabilityCurve(elapsed, seg.stability);
        final p = Offset(xToPx(day), yToPx(r));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      if (seg.endDay > revealDay) break;
    }

    if (started) {
      // Fill under the curve with a soft gradient.
      final fill = Path.from(path)
        ..lineTo(xToPx(math.min(revealDay, xMaxDays)), yToPx(0))
        ..lineTo(xToPx(0), yToPx(0))
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, _padT),
            Offset(0, _padT + plotH),
            [curveColor.withOpacity(0.28), curveColor.withOpacity(0.02)],
          ),
      );
      // Stroke the curve.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = curveColor,
      );
    }

    // DUE vertical marker.
    if (dueDay >= 0 && dueDay <= xMaxDays) {
      final x = xToPx(dueDay);
      _drawDashedLine(
        canvas,
        Offset(x, _padT),
        Offset(x, _padT + plotH),
        Paint()
          ..color = dueColor
          ..strokeWidth = 1.5,
      );
      _drawLabel(
        canvas,
        'DUE',
        Offset(x, size.height - _padB + 6),
        dueColor,
        align: TextAlign.center,
      );
    }

    // NOW vertical marker + current-retention dot (only once revealed).
    if (nowDay >= 0 && nowDay <= revealDay + 0.0001) {
      final x = xToPx(nowDay);
      canvas.drawLine(
        Offset(x, _padT),
        Offset(x, _padT + plotH),
        Paint()
          ..color = nowColor.withOpacity(0.55)
          ..strokeWidth = 1.5,
      );
      _drawLabel(
        canvas,
        'NOW',
        Offset(x, size.height - _padB + 6),
        nowColor,
        align: TextAlign.center,
      );
      // Current dot.
      final dotPos = Offset(x, yToPx(rNow));
      canvas.drawCircle(
        dotPos,
        7,
        Paint()..color = curveColor.withOpacity(0.25),
      );
      canvas.drawCircle(dotPos, 4.5, Paint()..color = curveColor);
      canvas.drawCircle(
        dotPos,
        2,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }

    // Review dots — colored by grade, at the dip each review recovered from.
    for (final d in dots) {
      if (d.day > revealDay + 0.0001) continue;
      final pos = Offset(xToPx(d.day), yToPx(d.retention));
      final c = _gradeColor(d.grade);
      canvas.drawCircle(pos, 6, Paint()..color = c.withOpacity(0.22));
      canvas.drawCircle(pos, 3.6, Paint()..color = c);
      canvas.drawCircle(
        pos,
        1.3,
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * math.min(drawn + dash, total);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _RetentionCurvePainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.rNow != rNow ||
      old.curveColor != curveColor;
}

// ── Data + provider ────────────────────────────────────────────────────────

class _CardRetention {
  const _CardRetention({
    required this.card,
    required this.state,
    required this.logs,
  });
  final LocalCard? card;
  final CardMemoryState? state;
  final List<ReviewLog> logs;
}

final _cardRetentionProvider =
    FutureProvider.family<_CardRetention, String>((ref, cardId) async {
  // Refresh whenever a grade is recorded so the curve stays live.
  ref.watch(sessionTickProvider);
  final db = ref.watch(databaseProvider);
  final card = await db.cardsDao.cardById(cardId);
  final state = await db.reviewsDao.stateFor(cardId);
  final logs = await db.reviewsDao.logsForCard(cardId);
  return _CardRetention(card: card, state: state, logs: logs);
});

/// Anki-style per-review history: when, how it was graded, and the
/// interval FSRS granted as a result. Newest first.
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.logs});

  final List<ReviewLog> logs;

  static const _gradeLabels = ['AGAIN', 'HARD', 'GOOD', 'EASY'];

  Color _gradeColor(BuildContext context, int grade) {
    final cs = Theme.of(context).colorScheme;
    switch (grade) {
      case 0:
        return cs.brandRed;
      case 1:
        return cs.brandOchreText;
      case 3:
        return cs.brandNavy;
      default:
        return cs.brandGreen;
    }
  }

  String _date(int unixSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REVIEW HISTORY',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        for (final log in logs.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MergeSemantics(
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      _date(log.reviewedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _gradeColor(context, log.grade),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _gradeLabels[log.grade.clamp(0, 3)],
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: _gradeColor(context, log.grade),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    log.intervalDays < 1
                        ? 'same day'
                        : 'next in ${log.intervalDays}d',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
