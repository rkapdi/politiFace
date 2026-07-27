// lib/features/home/application/home_providers.dart
//
// Home v2 state: the readiness projection and the priority ladder that
// picks the ONE primary action (Readiness Engine, Move 2). The ladder
// order is founder-approved (decision D2): live game > repairs owed >
// reviews due > weakest domain > today's round. The first two rungs land
// with the live/repair server work (Move 4); until then the ladder starts
// at reviews.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fcle/application/fcle_providers.dart';
import '../../fcle/domain/fcle_question.dart';

/// Cards due for review right now, capped at the visible-queue limit
/// (never show a raw backlog: DESIGN of the forgiving streak, Move 5).
const kVisibleQueueCap = 12;

final dueReviewCountProvider = FutureProvider<int>((ref) async {
  ref.watch(sessionTickProvider);
  final repo = ref.watch(cardReviewRepositoryProvider);
  final candidates =
      await repo.loadSessionCandidates(dueLimit: kVisibleQueueCap);
  return candidates.due.length;
});

/// The four-stage readiness read: projected score range out of 80 plus
/// the stage band, derived from per-domain rolling accuracy. Null until
/// enough answers exist to say anything honest (the diagnostic is the
/// intended first filler of this).
class ReadinessSummary {
  const ReadinessSummary({
    required this.low,
    required this.high,
    required this.perDomain,
    required this.totalAnswers,
  });

  final int low;
  final int high;
  final Map<FcleDomain, double?> perDomain;
  final int totalAnswers;
}

final readinessSummaryProvider = FutureProvider<ReadinessSummary?>(
  (ref) async {
    final readiness = await ref.watch(readinessProvider.future);
    var totalAnswers = 0;
    var mid = 0.0;
    final perDomain = <FcleDomain, double?>{};
    for (final r in readiness.values) {
      totalAnswers += r.answerCount;
      perDomain[r.domain] = r.accuracy;
      // Domains with no history contribute a conservative prior rather
      // than an optimistic blank: an unstudied domain is a risk, and the
      // projection must be honest about precision.
      mid += (r.accuracy ?? 0.40) * 20;
    }
    if (totalAnswers < 8) return null; // no honest signal yet
    // Range narrows as evidence accumulates; never a point estimate.
    final width = (10 - totalAnswers ~/ 25).clamp(4, 10);
    return ReadinessSummary(
      low: (mid - width).round().clamp(0, 80),
      high: (mid + width).round().clamp(0, 80),
      perDomain: perDomain,
      totalAnswers: totalAnswers,
    );
  },
);

/// What the one Home button should do right now.
enum LadderRung { review, drill, round }

class LadderPick {
  const LadderPick(this.rung, {this.dueCount = 0, this.weakest});

  final LadderRung rung;
  final int dueCount;
  final FcleDomain? weakest;
}

final ladderPickProvider = FutureProvider<LadderPick>((ref) async {
  // Rung: reviews due (capped) beat everything available today.
  final due = await ref.watch(dueReviewCountProvider.future);
  if (due > 0) return LadderPick(LadderRung.review, dueCount: due);

  // Rung: weakest FCLE domain below par, when there is real signal.
  final summary = await ref.watch(readinessSummaryProvider.future);
  if (summary != null) {
    final weakest = await ref.watch(weakestDomainProvider.future);
    final acc = weakest == null ? null : summary.perDomain[weakest];
    if (weakest != null && acc != null && acc < 0.6) {
      return LadderPick(LadderRung.drill, weakest: weakest);
    }
  }

  // Rung: today's chapter round, the default ritual.
  return const LadderPick(LadderRung.round);
});

/// Round played-today state, re-exported so Home can phrase the button.
final homeRoundPlayedProvider = FutureProvider<bool>(
  (ref) => ref.watch(todayRoundPlayedProvider.future),
);
