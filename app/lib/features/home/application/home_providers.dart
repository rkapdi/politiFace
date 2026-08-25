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
import '../../fcle/domain/readiness_projection.dart';

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
/// the stage band, derived from RECENT per-domain evidence with
/// conservative shrinkage (see readiness_projection.dart). Null until
/// enough recent answers exist to say anything honest.
class ReadinessSummary {
  const ReadinessSummary({
    required this.low,
    required this.high,
    required this.perDomain,
    required this.totalAnswers,
  });

  final int low;
  final int high;

  /// Raw windowed accuracy per domain (null = no recent history), for the
  /// domain bars and the weakest-domain ladder rung.
  final Map<FcleDomain, double?> perDomain;

  /// Answers inside the recency window, all domains.
  final int totalAnswers;
}

final readinessSummaryProvider = FutureProvider<ReadinessSummary?>(
  (ref) async {
    ref.watch(fcleTickProvider);
    final dao = ref.watch(databaseProvider).fcleAnswersDao;
    final since = DateTime.now()
        .subtract(const Duration(days: kRecencyDays))
        .millisecondsSinceEpoch;

    var totalRecent = 0;
    final evidence = <({int correct, int count})>[];
    final perDomain = <FcleDomain, double?>{};
    for (final d in FcleDomain.values) {
      final s = await dao.windowedStats(d.code, sinceMs: since);
      evidence.add(s);
      totalRecent += s.count;
      perDomain[d] = s.count == 0 ? null : s.correct / s.count;
    }

    final p = projectScore(evidence);
    if (p == null) return null;
    return ReadinessSummary(
      low: p.low,
      high: p.high,
      perDomain: perDomain,
      totalAnswers: totalRecent,
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
