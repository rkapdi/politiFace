// lib/core/database/daos/outbox_dao.dart
//
// Queue of server-bound events. Rows are appended by SyncEngine.enqueue*,
// flushed oldest-first, and deleted on confirmed delivery. A row that keeps
// failing (a poison event, e.g. referencing content the server no longer
// serves) stops being retried after [maxTries] but is kept for diagnosis.

import 'package:drift/drift.dart';

import '../drift/app_database.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [OutboxEvents])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Events that have exhausted [maxTries] stay in the table but are no
  /// longer flushed; they surface in [deadLetterCount] instead.
  static const maxTries = 8;

  Future<void> enqueue(OutboxEventsCompanion event) =>
      into(outboxEvents).insert(event, mode: InsertMode.insertOrIgnore);

  /// Oldest deliverable events first, so server-side ordering follows
  /// client-side ordering.
  Future<List<OutboxEvent>> pending({int limit = 50}) => (select(outboxEvents)
        ..where((t) => t.tries.isSmallerThanValue(maxTries))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
        ..limit(limit))
      .get();

  Future<void> markDelivered(String eventId) =>
      (delete(outboxEvents)..where((t) => t.eventId.equals(eventId))).go();

  /// A transient delivery failure: remember the error for diagnosis but do
  /// not advance [tries]; only permanent rejections may dead-letter a row.
  Future<void> noteTransient(String eventId, String error) => customStatement(
        'UPDATE outbox_events SET last_error = ? WHERE event_id = ?',
        [error, eventId],
      );

  Future<void> recordFailure(String eventId, String error) => customStatement(
        'UPDATE outbox_events SET tries = tries + 1, last_error = ? '
        'WHERE event_id = ?',
        [error, eventId],
      );

  Future<int> pendingCount() async {
    final c = countAll();
    final row = await (selectOnly(outboxEvents)
          ..addColumns([c])
          ..where(outboxEvents.tries.isSmallerThanValue(maxTries)))
        .getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> deadLetterCount() async {
    final c = countAll();
    final row = await (selectOnly(outboxEvents)
          ..addColumns([c])
          ..where(outboxEvents.tries.isBiggerOrEqualValue(maxTries)))
        .getSingle();
    return row.read(c) ?? 0;
  }
}
