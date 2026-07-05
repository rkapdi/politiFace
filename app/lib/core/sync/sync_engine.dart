// lib/core/sync/sync_engine.dart
//
// Local-first sync: gameplay stays instant and offline (Drift + local FSRS);
// server-bound events are appended to the outbox and flushed opportunistically
// (after enqueue, after sign-in, on app resume). Delivery is idempotent: the
// server dedupes on the client-generated event_id, so retries never
// double-count (ARCHITECTURE.md, Sync model).
//
// Only events the server can accept are enqueued. Today that is session
// boundaries; FCLE answers (submit_answer) and reviews (submit_review) use
// the same paths once the FCLE prep UI ships and plays server-known
// questions. v1 face/concept-card reviews stay local: their cards are not in
// the server question bank.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/daos/outbox_dao.dart';
import '../database/drift/app_database.dart';

/// Transport boundary: everything that talks to Supabase lives behind this,
/// so SyncEngine is unit-testable without a server.
abstract class SyncTransport {
  bool get isSignedIn;
  Future<void> sendAnswer(OutboxEvent e);
  Future<void> sendReview(OutboxEvent e);
  Future<void> sendSessionEvent(OutboxEvent e);
}

/// Thrown by transports for errors that will not succeed on retry (the
/// server rejected the event). Anything else is treated as transient
/// (network) and stops the flush until next trigger.
class PermanentSyncError implements Exception {
  PermanentSyncError(this.message);
  final String message;
  @override
  String toString() => message;
}

class SupabaseTransport implements SyncTransport {
  SupabaseTransport(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  Future<void> sendAnswer(OutboxEvent e) => _guard(() => _client.rpc<void>(
        'submit_answer',
        params: {
          'p_event_id': e.eventId,
          'p_question_id': e.questionId,
          'p_chosen_key': e.chosenKey,
          'p_client_ts':
              DateTime.fromMillisecondsSinceEpoch(e.clientTs).toIso8601String(),
          'p_attempt_id': e.attemptId,
        },
      ),);

  @override
  Future<void> sendReview(OutboxEvent e) => _guard(() => _client.rpc<void>(
        'submit_review',
        params: {
          'p_event_id': e.eventId,
          'p_question_id': e.questionId,
          'p_grade': e.grade,
          'p_client_ts':
              DateTime.fromMillisecondsSinceEpoch(e.clientTs).toIso8601String(),
        },
      ),);

  @override
  Future<void> sendSessionEvent(OutboxEvent e) =>
      _guard(() => _client.from('events').insert({
            'event_id': e.eventId,
            'user_id': _client.auth.currentUser!.id,
            'type': e.type,
            'payload': jsonDecode(e.payload),
            'client_ts': DateTime.fromMillisecondsSinceEpoch(e.clientTs)
                .toIso8601String(),
          }),);

  /// PostgrestExceptions are server verdicts (bad payload, RLS, missing
  /// content): retrying cannot fix them. Everything else (socket, timeout)
  /// is transient.
  Future<void> _guard(Future<void> Function() send) async {
    try {
      await send();
    } on PostgrestException catch (e) {
      // 23505 unique_violation = the event already landed on a previous try
      // that timed out on the way back. That is success, not failure.
      if (e.code == '23505') return;
      throw PermanentSyncError('${e.code}: ${e.message}');
    }
  }
}

class SyncEngine {
  SyncEngine(this._db, this._transport);

  final AppDatabase _db;
  final SyncTransport? _transport;

  OutboxDao get _outbox => _db.outboxDao;
  Future<void>? _inFlight;

  /// Whether events should be recorded at all. No backend configured or no
  /// account signed in means no data leaves the device, same as v1.
  bool get isActive => _transport?.isSignedIn ?? false;

  Future<void> enqueueSessionStart() => _enqueueSession('session_start');
  Future<void> enqueueSessionEnd() => _enqueueSession('session_end');

  Future<void> enqueueAnswer({
    required String questionId,
    required String chosenKey,
    String? attemptId,
  }) =>
      _enqueue(
        type: 'answer',
        questionId: questionId,
        chosenKey: chosenKey,
        attemptId: attemptId,
      );

  Future<void> enqueueReview({
    required String questionId,
    required String grade,
  }) =>
      _enqueue(type: 'review', questionId: questionId, grade: grade);

  Future<void> _enqueueSession(String type) => _enqueue(type: type);

  Future<void> _enqueue({
    required String type,
    String? questionId,
    String? chosenKey,
    String? grade,
    String? attemptId,
  }) async {
    if (!isActive) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _outbox.enqueue(OutboxEventsCompanion.insert(
      eventId: uuidV4(),
      type: type,
      questionId: Value(questionId),
      chosenKey: Value(chosenKey),
      grade: Value(grade),
      attemptId: Value(attemptId),
      clientTs: now,
      createdAt: now,
    ),);
    unawaited(flush());
  }

  /// Drains the outbox oldest-first. Transient failure stops the pass (the
  /// next trigger retries); permanent failure records the error on that row
  /// and moves on so one poison event cannot dam the queue. Concurrent
  /// callers share the in-flight pass instead of racing it.
  Future<void> flush() {
    final transport = _transport;
    if (transport == null || !transport.isSignedIn) return Future.value();
    return _inFlight ??=
        _drain(transport).whenComplete(() => _inFlight = null);
  }

  Future<void> _drain(SyncTransport transport) async {
    while (true) {
      final batch = await _outbox.pending();
      if (batch.isEmpty) return;
      var delivered = 0;
      for (final event in batch) {
        try {
          switch (event.type) {
            case 'answer':
              await transport.sendAnswer(event);
            case 'review':
              await transport.sendReview(event);
            default:
              await transport.sendSessionEvent(event);
          }
          await _outbox.markDelivered(event.eventId);
          delivered++;
        } on PermanentSyncError catch (e) {
          await _outbox.recordFailure(event.eventId, e.message);
        } catch (e) {
          await _outbox.recordFailure(event.eventId, e.toString());
          return; // transient: stop, retry on the next trigger
        }
      }
      // A pass of nothing but permanent failures must not spin the loop.
      if (delivered == 0) return;
    }
  }
}

/// RFC 4122 v4 UUID from a cryptographic RNG. Local implementation to avoid
/// a dependency for 16 random bytes.
String uuidV4({Random? random}) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int start, int end) => b
      .sublist(start, end)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
