// lib/features/notifications/data/notification_generators.dart
//
// Pure candidate generators for the notification brain. Each function turns a
// slice of already-gathered local state into a list of [NotifCandidate]s; it
// performs no I/O and holds no clock of its own, so every relevance score and
// every string is testable to the character. The NotificationOrchestrator
// gathers the inputs (daos, loaders, resolved person links) and calls these.
//
// House style is load-bearing here, not cosmetic:
//   * No em-dashes anywhere in user copy.
//   * Notifications state what happened, never what it means. No verdicts,
//     no consequences, no opinions on legislation.
//   * Every personalized string is built ONLY from real local data: a real
//     person name the user has really studied, a real card name, a real
//     objective count. When the data is not there, we fall back to the
//     general, non-personal copy. A name is never synthesized.

import '../../fcle/domain/fcle_question.dart';
import '../domain/notification_brain.dart';
import 'washington_watch_service.dart';

/// Stable platform notification-id slots, one per category, so a newer
/// notification in a slot replaces an older one rather than stacking. These
/// sit clear of the daily streak reminder (1) and the chapter nudge (50).
class NotifSlots {
  static const washingtonSummary = 100;
  static const washingtonItemBase = 101; // 101, 102, 103, ...
  static const memoryRescue = 60;
  static const fcleMilestone = 70;
  static const chapterReady = 50; // == chapterReadyNotificationId
}

/// The real newsmaker behind a Washington item, resolved locally. Only ever
/// constructed from a card/person that genuinely exists in the user's data,
/// so [name] is always safe to put in copy.
class WashingtonPersonLink {
  const WashingtonPersonLink({
    required this.name,
    required this.studied,
    required this.homeState,
    this.state,
  });

  /// The person's real display name, taken from their local card.
  final String name;

  /// The user has actually reviewed this person's card (isNew == false).
  final bool studied;

  /// This person sits in the user's home-state delegation.
  final bool homeState;

  /// Two-letter home state, for the delegation framing. Null unless known.
  final String? state;

  bool get isPersonal => studied || homeState;
}

/// A detected Washington item paired with its resolved person link (null when
/// the item carries no known person, so no personalization is possible).
class WashingtonInput {
  const WashingtonInput({required this.item, this.link});

  final WatchItem item;
  final WashingtonPersonLink? link;
}

/// Turns detected Washington items into candidates. Personal items (a face
/// the user studied, or their home-state delegation) surface individually
/// with high relevance and a relationship hook; general items carry the
/// official title verbatim at low relevance. When there are more than three
/// GENERAL items, they collapse into a single summary candidate so a busy
/// news day cannot flood the queue (the brain's daily cap then trims further).
List<NotifCandidate> buildWashingtonCandidates(
  List<WashingtonInput> inputs, {
  required DateTime now,
}) {
  final personal = <NotifCandidate>[];
  final general = <WashingtonInput>[];

  for (final input in inputs) {
    final link = input.link;
    if (link != null && link.isPersonal) {
      personal.add(_washingtonPersonal(input.item, link));
    } else {
      general.add(input);
    }
  }

  final out = <NotifCandidate>[];
  var slot = NotifSlots.washingtonItemBase;
  for (final c in personal) {
    out.add(_withId(c, slot++));
  }

  if (general.length > 3) {
    out.add(
      NotifCandidate(
        kind: NotifKind.washingtonGeneral,
        notificationId: NotifSlots.washingtonSummary,
        title: 'Washington was busy: ${general.length} updates in The Pulse.',
        body: '',
        dedupeKey: 'wash:summary:${_dayKey(now)}',
        relevance: 0.1,
        route: '/pulse',
      ),
    );
  } else {
    for (final input in general) {
      out.add(_withId(_washingtonGeneral(input.item), slot++));
    }
  }
  return out;
}

NotifCandidate _washingtonPersonal(WatchItem item, WashingtonPersonLink link) {
  final connection = link.studied
      ? 'a face from your deck'
      : 'from your ${link.state ?? 'home-state'} delegation';
  // Relevance leans on the strength of the connection. Studied-and-home-state
  // is the strongest signal; a studied face outranks a home-state-only tie.
  final relevance = link.studied && link.homeState
      ? 1.0
      : link.studied
          ? 0.85
          : 0.65;
  return NotifCandidate(
    kind: NotifKind.washingtonPersonal,
    notificationId: NotifSlots.washingtonItemBase,
    title: item.notificationTitle,
    body: '${link.name}, $connection, just ${_actionPhrase(item.category)}.',
    dedupeKey: item.dedupeKey,
    relevance: relevance,
    route: '/pulse',
  );
}

NotifCandidate _washingtonGeneral(WatchItem item) => NotifCandidate(
      kind: NotifKind.washingtonGeneral,
      notificationId: NotifSlots.washingtonItemBase,
      title: item.notificationTitle,
      body: item.notificationBody, // official title (+ CRS), verbatim
      dedupeKey: item.dedupeKey,
      relevance: 0.1,
      route: '/pulse',
    );

/// Factual, verdict-free phrasing for what the newsmaker did.
String _actionPhrase(WatchCategory category) => switch (category) {
      WatchCategory.executiveOrder => 'signed a new executive order',
      // Dormant until a sponsor field reaches WatchItem.personName: today the
      // congress.gov feed carries no bill/law sponsor, so these never fire.
      WatchCategory.law => 'signed a bill into law',
      WatchCategory.bill => 'moved a bill forward in Congress',
    };

/// One nudge when enough valuable cards are about to slip below recall. Never
/// invents a card name: [sampleCardName] must be a real card the user owns, or
/// the copy falls back to the nameless form.
NotifCandidate? buildMemoryRescueCandidate({
  required int slippingCount,
  required DateTime now,
  String? sampleCardName,
  int threshold = 3,
}) {
  if (slippingCount < threshold) return null;
  final name = sampleCardName?.trim();
  final body = (name == null || name.isEmpty)
      ? 'A few cards are about to slip. Five minutes keeps them.'
      : 'A few cards are about to slip, including $name. '
          'Five minutes keeps them.';
  // More cards slipping means a more valuable rescue; saturates by ~10 cards.
  final relevance = (slippingCount / 10).clamp(0.3, 1.0).toDouble();
  return NotifCandidate(
    kind: NotifKind.memoryRescue,
    notificationId: NotifSlots.memoryRescue,
    title: 'A few cards are fading',
    body: body,
    dedupeKey: 'rescue:${_dayKey(now)}',
    relevance: relevance,
    route: '/round',
  );
}

/// The FCLE milestone generator's output: the candidates to consider, plus the
/// updated set of solid-domain codes for the caller to persist (so a domain's
/// "just reached solid" nudge fires exactly once).
class FcleMilestoneResult {
  const FcleMilestoneResult({
    required this.candidates,
    required this.solidDomainCodes,
  });

  final List<NotifCandidate> candidates;
  final Set<String> solidDomainCodes;
}

/// Coverage and domain-solidity milestones for an FCLE-engaged user. The brain
/// also hard-gates this whole category to engaged users; we still compute it
/// cheaply and only when [covered]/[solidDomains] warrant it.
///
/// Two honest, specific moments:
///   * Coverage: 1 or 2 objectives from touching the whole 32-objective
///     blueprint.
///   * Freshly solid: a domain whose practice just crossed into "solid" that
///     was not solid on the previous run ([priorSolidDomainCodes]).
///
/// [urgent] stays false: no real exam-date signal exists yet. TODO: set urgent
/// when a cohort exam_window is near.
FcleMilestoneResult buildFcleMilestoneCandidates({
  required int covered,
  required int total,
  required Set<FcleDomain> solidDomains,
  required Set<String> priorSolidDomainCodes,
  required DateTime now,
}) {
  final candidates = <NotifCandidate>[];
  final solidCodes = {for (final d in solidDomains) d.code};

  final remaining = total - covered;
  if (total > 0 && covered > 0 && (remaining == 1 || remaining == 2)) {
    final body = remaining == 1
        ? 'You are 1 objective from covering the whole blueprint. '
            'Today closes it.'
        : 'You are 2 objectives from covering the whole blueprint. '
            'Today closes one.';
    candidates.add(
      NotifCandidate(
        kind: NotifKind.fcleMilestone,
        notificationId: NotifSlots.fcleMilestone,
        title: 'FCLE blueprint',
        body: body,
        dedupeKey: 'fcle:coverage:$covered',
        relevance: remaining == 1 ? 0.9 : 0.7,
        route: '/fcle/blueprint',
      ),
    );
  }

  // A domain that is solid now but was not on the previous run. Order by enum
  // so the choice is deterministic when two cross at once.
  for (final d in FcleDomain.values) {
    if (solidCodes.contains(d.code) &&
        !priorSolidDomainCodes.contains(d.code)) {
      candidates.add(
        NotifCandidate(
          kind: NotifKind.fcleMilestone,
          notificationId: NotifSlots.fcleMilestone,
          title: 'FCLE progress',
          body: 'Your ${d.label} practice just reached a solid level. '
              'Keep the rest close behind.',
          dedupeKey: 'fcle:solid:${d.code}',
          relevance: 0.6,
          route: '/fcle/blueprint',
        ),
      );
    }
  }

  return FcleMilestoneResult(
    candidates: candidates,
    solidDomainCodes: solidCodes,
  );
}

/// Wraps a chapter-ready teaser (already decided by
/// [decideChapterNotification]) into a candidate. It is fresh external news,
/// so the brain lets it through even when the user opened the app today; the
/// orchestrator, not this function, chooses the delivery time via the brain.
NotifCandidate buildChapterReadyCandidate({
  required String title,
  required String body,
  required String nextChapterTitle,
}) =>
    NotifCandidate(
      kind: NotifKind.chapterReady,
      notificationId: NotifSlots.chapterReady,
      title: title,
      body: body,
      dedupeKey: 'chapter:$nextChapterTitle',
      route: '/round',
    );

NotifCandidate _withId(NotifCandidate c, int id) => NotifCandidate(
      kind: c.kind,
      notificationId: id,
      title: c.title,
      body: c.body,
      dedupeKey: c.dedupeKey,
      relevance: c.relevance,
      route: c.route,
      urgent: c.urgent,
    );

/// Local calendar day, for once-per-day dedupe keys.
String _dayKey(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}
