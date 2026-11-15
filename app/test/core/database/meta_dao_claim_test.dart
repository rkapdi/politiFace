// Regression: the notification sweep lock and the per-notification sent
// record both rest on MetaDao.claimStamp being a single atomic statement.
// These tests pin its contract, including across separate connections to
// one database file (how the background refresh isolate reaches it).

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';

void main() {
  group('on one connection', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('first claim wins, a second is refused while it is live', () async {
      expect(
        await db.metaDao.claimStamp('lock', value: '2000|a', staleBelow: 1000),
        isTrue,
      );
      expect(
        await db.metaDao.claimStamp('lock', value: '2500|b', staleBelow: 1500),
        isFalse,
      );
      expect(await db.metaDao.get('lock'), '2000|a');
    });

    test('an expired claim can be taken over', () async {
      await db.metaDao.claimStamp('lock', value: '2000|a', staleBelow: 1000);
      expect(
        await db.metaDao.claimStamp('lock', value: '9000|b', staleBelow: 2001),
        isTrue,
      );
      expect(await db.metaDao.get('lock'), '9000|b');
    });

    test('a guarded claim needs the guard row to hold the exact value',
        () async {
      await db.metaDao.claimStamp('lock', value: '2000|a', staleBelow: 1000);
      expect(
        await db.metaDao.claimStamp(
          'sent:x',
          value: '1500',
          staleBelow: 0,
          requireKey: 'lock',
          requireValue: '2000|someone-else',
        ),
        isFalse,
      );
      expect(await db.metaDao.get('sent:x'), isNull);
      expect(
        await db.metaDao.claimStamp(
          'sent:x',
          value: '1500',
          staleBelow: 0,
          requireKey: 'lock',
          requireValue: '2000|a',
        ),
        isTrue,
      );
      expect(await db.metaDao.get('sent:x'), '1500');
    });

    test('removeIfValue never deletes a newer claim', () async {
      await db.metaDao.claimStamp('lock', value: '2000|a', staleBelow: 1000);
      await db.metaDao.removeIfValue('lock', '1000|old');
      expect(await db.metaDao.get('lock'), '2000|a');
      await db.metaDao.removeIfValue('lock', '2000|a');
      expect(await db.metaDao.get('lock'), isNull);
    });

    test('withPrefix returns only matching keys, wildcards taken literally',
        () async {
      await db.metaDao.set('notif.sent:eo:1', '10');
      await db.metaDao.set('notif.sent:bill:HR 1:2026-01-01', '20');
      await db.metaDao.set('notif_sent:other', '30');
      await db.metaDao.set('notifXsent:other', '40');
      expect(await db.metaDao.withPrefix('notif.sent:'), {
        'notif.sent:eo:1': '10',
        'notif.sent:bill:HR 1:2026-01-01': '20',
      });
      expect(await db.metaDao.withPrefix('notif_sent:'), {
        'notif_sent:other': '30',
      });
    });
  });

  test('three connections to one file: exactly one wins the claim', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('pf_claim_');
    final file = File('${dir.path}/claim.sqlite');
    final dbs = [
      for (var i = 0; i < 3; i++) AppDatabase.forTesting(NativeDatabase(file)),
    ];
    addTearDown(() async {
      for (final d in dbs) {
        await d.close();
      }
      await dir.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });
    // Open (and migrate) one at a time, as real launches do.
    for (final d in dbs) {
      await d.metaDao.get('warm');
    }

    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        dbs[i].metaDao.claimStamp('lock', value: '2000|$i', staleBelow: 1000),
    ]);
    expect(results.where((won) => won), hasLength(1));
    final winner = results.indexOf(true);
    for (final d in dbs) {
      expect(await d.metaDao.get('lock'), '2000|$winner');
    }
  });
}
