// The contamination invariant: a question reserved as a hold-out for a
// scheduled retention check must never be emitted by any practice surface.
// Each selection path is exercised against a chokepoint-filtered bank; if a
// surface ever grows its own unfiltered path, the matching test here is the
// tripwire.

import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/fcle/application/fcle_providers.dart';
import 'package:politiface/features/fcle/data/locked_questions_service.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';
import 'package:politiface/features/fcle/domain/mock_engine.dart';
import 'package:politiface/features/fcle/domain/server_ids.dart';
import 'package:politiface/features/onboarding/presentation/onboarding_screen.dart';

FcleQuestion _q(FcleDomain d, int i) => FcleQuestion(
      id: '${d.code}-$i',
      domain: d,
      stem: 'Question $i of ${d.code}?',
      options: const [
        FcleOption(key: 'a', text: 'A'),
        FcleOption(key: 'b', text: 'B'),
      ],
      answerKey: 'b',
      explanation: 'Because b.',
      citation: 'https://example.gov',
      difficulty: 3,
    );

QuestionBank _bank(int perDomain) => QuestionBank({
      for (final d in FcleDomain.values)
        d: [for (var i = 0; i < perDomain; i++) _q(d, i)],
    });

/// Locks question index 0 of every domain (as server UUIDs) and returns
/// (filtered bank, locked yaml ids).
(QuestionBank, Set<String>) _filtered(QuestionBank bank) {
  final lockedYaml = {for (final d in FcleDomain.values) '${d.code}-0'};
  final lockedServer = lockedYaml.map(serverUuidForQuestion).toSet();
  final filtered =
      bank.where((q) => !lockedServer.contains(serverUuidForQuestion(q.id)));
  return (filtered, lockedYaml);
}

void main() {
  test('QuestionBank.where drops locked items in every domain', () {
    final (filtered, locked) = _filtered(_bank(5));
    expect(filtered.all.length, 16);
    for (final q in filtered.all) {
      expect(locked.contains(q.id), isFalse);
    }
    // Read-only consumers keep the raw bank: counts differ by exactly one.
    expect(filtered.countFor(FcleDomain.values.first), 4);
  });

  test('weak-area practice never deals a locked item', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final (filtered, locked) = _filtered(_bank(12));
    for (final d in FcleDomain.values) {
      final set = await buildPracticeSet(
        bank: filtered,
        dao: db.fcleAnswersDao,
        domain: d,
        count: 11,
        random: Random(3),
      );
      expect(set, isNotEmpty);
      for (final q in set) {
        expect(
          locked.contains(q.id),
          isFalse,
          reason: 'locked ${q.id} surfaced in ${d.code} practice',
        );
      }
    }
  });

  test('local mock assembly never deals a locked item', () {
    // 21 per domain, 1 locked each: exactly 20 remain, so assembly succeeds
    // and must contain every unlocked item but no locked one.
    final (filtered, locked) = _filtered(_bank(21));
    final assembly = const MockEngine().assemble(filtered, random: Random(7));
    expect(assembly.questions.length, 80);
    for (final q in assembly.questions) {
      expect(
        locked.contains(q.id),
        isFalse,
        reason: 'locked ${q.id} dealt into a mock',
      );
    }
  });

  test('mock CTA gate agrees with assembly under locks', () {
    // 20 per domain with 1 locked each leaves 19: the filtered bank must
    // say "no mock" so the CTA never offers what assemble() would throw on.
    final (filtered, _) = _filtered(_bank(20));
    expect(filtered.canAssembleMock, isFalse);
  });

  test('diagnostic sampling never deals a locked item', () {
    final (filtered, locked) = _filtered(_bank(4));
    for (var seed = 0; seed < 20; seed++) {
      final picked = pickDiagnosticQuestions(filtered, Random(seed));
      expect(picked.length, 10);
      for (final q in picked) {
        expect(
          locked.contains(q.id),
          isFalse,
          reason: 'locked ${q.id} surfaced in the diagnostic (seed $seed)',
        );
      }
    }
  });

  group('LockedQuestionsService', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('fetches, caches, and serves the cache while fresh', () async {
      var calls = 0;
      final service = LockedQuestionsService(
        db: db,
        active: true,
        fetch: () async {
          calls++;
          return ['aaaa-1', 'bbbb-2'];
        },
        now: () => DateTime(2026, 8, 6, 12),
      );
      expect(await service.current(), {'aaaa-1', 'bbbb-2'});
      expect(calls, 1);
      // Second read inside the freshness window: cache, no second call.
      expect(await service.current(), {'aaaa-1', 'bbbb-2'});
      expect(calls, 1);
    });

    test('stale cache refetches; fetch failure falls back to cache', () async {
      await db.metaDao.set(
        LockedQuestionsService.metaKey,
        jsonEncode({
          'at': DateTime(2026, 8, 6, 10).millisecondsSinceEpoch,
          'ids': ['cccc-3'],
        }),
      );
      final failing = LockedQuestionsService(
        db: db,
        active: true,
        fetch: () async => throw Exception('offline'),
        now: () => DateTime(2026, 8, 6, 12),
      );
      expect(await failing.current(), {'cccc-3'});
    });

    test('inactive (signed out) never fetches, serves cache or empty',
        () async {
      var calls = 0;
      final service = LockedQuestionsService(
        db: db,
        active: false,
        fetch: () async {
          calls++;
          return ['dddd-4'];
        },
      );
      expect(await service.current(), isEmpty);
      expect(calls, 0);
    });
  });
}
