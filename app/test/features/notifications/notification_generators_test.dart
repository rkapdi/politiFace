import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/notifications/data/notification_generators.dart';
import 'package:politiface/features/notifications/data/washington_watch_service.dart';
import 'package:politiface/features/notifications/domain/notification_brain.dart';

void main() {
  final now = DateTime(2026, 7, 24, 12);

  WatchItem eo({
    String title = 'Executive Order Establishing A Thing',
    String? person,
    String dedupe = 'eo:1',
  }) =>
      WatchItem(
        category: WatchCategory.executiveOrder,
        title: title,
        dedupeKey: dedupe,
        personName: person,
      );

  group('buildWashingtonCandidates', () {
    test('a studied face makes the item personal with a real-name hook', () {
      final out = buildWashingtonCandidates(
        [
          WashingtonInput(
            item: eo(person: 'Susan Collins'),
            link: const WashingtonPersonLink(
              name: 'Susan Collins',
              studied: true,
              homeState: false,
            ),
          ),
        ],
        now: now,
      );

      expect(out, hasLength(1));
      expect(out.single.kind, NotifKind.washingtonPersonal);
      expect(out.single.body, contains('Susan Collins'));
      expect(out.single.relevance, 0.85);
    });

    test('a home-state delegation match personalizes with the state framing',
        () {
      final out = buildWashingtonCandidates(
        [
          WashingtonInput(
            item: eo(person: 'Susan Collins'),
            link: const WashingtonPersonLink(
              name: 'Susan Collins',
              studied: false,
              homeState: true,
              state: 'ME',
            ),
          ),
        ],
        now: now,
      );

      expect(out.single.kind, NotifKind.washingtonPersonal);
      expect(out.single.body, contains('Susan Collins'));
      expect(out.single.body, contains('ME delegation'));
      expect(out.single.relevance, 0.65);
    });

    test('a resolved-but-unconnected person stays general with no name', () {
      final out = buildWashingtonCandidates(
        [
          WashingtonInput(
            item: eo(person: 'Susan Collins', title: 'Order About Widgets'),
            link: const WashingtonPersonLink(
              name: 'Susan Collins',
              studied: false,
              homeState: false,
            ),
          ),
        ],
        now: now,
      );

      expect(out.single.kind, NotifKind.washingtonGeneral);
      expect(out.single.body, isNot(contains('Susan Collins')));
      expect(out.single.body, 'Order About Widgets');
      expect(out.single.relevance, 0.1);
    });

    test('no link at all is general and never invents a name', () {
      final out = buildWashingtonCandidates(
        [WashingtonInput(item: eo(title: 'Order About Widgets'))],
        now: now,
      );

      expect(out.single.kind, NotifKind.washingtonGeneral);
      expect(out.single.body, 'Order About Widgets');
    });

    test('more than 3 general items collapse into one summary candidate', () {
      final out = buildWashingtonCandidates(
        [
          for (var i = 0; i < 4; i++)
            WashingtonInput(item: eo(title: 'Order $i', dedupe: 'eo:$i')),
        ],
        now: now,
      );

      expect(out, hasLength(1));
      expect(out.single.notificationId, NotifSlots.washingtonSummary);
      expect(out.single.title, 'Washington was busy: 4 updates in The Pulse.');
    });

    test('personal items survive individually alongside a general collapse',
        () {
      final out = buildWashingtonCandidates(
        [
          WashingtonInput(
            item: eo(person: 'Studied Face', dedupe: 'eo:p'),
            link: const WashingtonPersonLink(
              name: 'Studied Face',
              studied: true,
              homeState: false,
            ),
          ),
          for (var i = 0; i < 4; i++)
            WashingtonInput(item: eo(title: 'Order $i', dedupe: 'eo:$i')),
        ],
        now: now,
      );

      final personal =
          out.where((c) => c.kind == NotifKind.washingtonPersonal).toList();
      final general =
          out.where((c) => c.kind == NotifKind.washingtonGeneral).toList();
      expect(personal, hasLength(1));
      expect(general, hasLength(1)); // the collapsed summary
      // Individual notification ids are distinct so they do not overwrite.
      expect(out.map((c) => c.notificationId).toSet(), hasLength(out.length));
    });
  });

  group('buildMemoryRescueCandidate', () {
    test('returns null below the three-card threshold', () {
      expect(
        buildMemoryRescueCandidate(slippingCount: 2, now: now),
        isNull,
      );
    });

    test('fires at three cards and names a real card', () {
      final c = buildMemoryRescueCandidate(
        slippingCount: 3,
        sampleCardName: 'Speaker of the House',
        now: now,
      );
      expect(c, isNotNull);
      expect(c!.kind, NotifKind.memoryRescue);
      expect(c.body, contains('Speaker of the House'));
      expect(c.relevance, closeTo(0.3, 1e-9));
      expect(c.dedupeKey, 'rescue:2026-07-24');
    });

    test('falls back to nameless copy when no card name is available', () {
      final c = buildMemoryRescueCandidate(slippingCount: 6, now: now);
      expect(
        c!.body,
        'A few cards are about to slip. Five minutes keeps them.',
      );
      expect(c.relevance, closeTo(0.6, 1e-9));
    });

    test('relevance saturates at ten slipping cards', () {
      final c = buildMemoryRescueCandidate(slippingCount: 20, now: now);
      expect(c!.relevance, 1.0);
    });
  });

  group('buildFcleMilestoneCandidates', () {
    FcleMilestoneResult run({
      required int covered,
      int total = 32,
      Set<FcleDomain> solid = const {},
      Set<String> prior = const {},
    }) =>
        buildFcleMilestoneCandidates(
          covered: covered,
          total: total,
          solidDomains: solid,
          priorSolidDomainCodes: prior,
          now: now,
        );

    test('two objectives from full coverage emits a coverage milestone', () {
      final r = run(covered: 30);
      final coverage = r.candidates
          .where((c) => c.dedupeKey.startsWith('fcle:coverage'))
          .toList();
      expect(coverage, hasLength(1));
      expect(coverage.single.body, contains('2 objectives'));
      expect(coverage.single.dedupeKey, 'fcle:coverage:30');
    });

    test('one objective from full coverage uses the singular close', () {
      final r = run(covered: 31);
      final coverage = r.candidates.single;
      expect(coverage.body, contains('1 objective'));
      expect(coverage.body, contains('closes it'));
    });

    test('full coverage and mid coverage emit no coverage milestone', () {
      expect(run(covered: 32).candidates, isEmpty);
      expect(run(covered: 25).candidates, isEmpty);
      expect(run(covered: 0).candidates, isEmpty);
    });

    test('a freshly solid domain fires exactly once', () {
      final first = run(covered: 10, solid: {FcleDomain.americanDemocracy});
      final solidCands = first.candidates
          .where((c) => c.dedupeKey.startsWith('fcle:solid'))
          .toList();
      expect(solidCands, hasLength(1));
      expect(solidCands.single.dedupeKey, 'fcle:solid:american_democracy');
      expect(first.solidDomainCodes, {'american_democracy'});

      // Same domain already recorded as solid: no repeat.
      final second = run(
        covered: 10,
        solid: {FcleDomain.americanDemocracy},
        prior: {'american_democracy'},
      );
      expect(second.candidates, isEmpty);
    });

    test('no user copy contains an em-dash', () {
      final r = run(covered: 31, solid: {FcleDomain.usConstitution});
      for (final c in r.candidates) {
        expect(c.title.contains('—'), isFalse);
        expect(c.body.contains('—'), isFalse);
      }
    });
  });
}
