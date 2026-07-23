// lib/features/live/data/live_session_api.dart
//
// Live class sessions, student side. The server owns everything that
// matters: phase machine, timing, grading, scoring. This layer wraps the
// student RPCs (join, current question, answer, reveal, standings) and a
// per-session change feed. Correctness is withheld until the reveal by
// design: submit_live_answer returns only "accepted", and the current
// question payload is key-free.
//
// Phase changes arrive two ways at once: Realtime postgres_changes on the
// session row, and a 3-second poll of get_live_question. Campus wifi kills
// websockets, so the game must survive on polling alone; the channel
// dedupes by snapshot signature so the double source never double-fires.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The cohort's joinable session, if any (the CLASS-screen banner).
class ActiveLiveSession {
  const ActiveLiveSession({
    required this.id,
    required this.title,
    required this.status,
  });

  final String id;
  final String title;
  final String status; // lobby | question | reveal
}

/// What join_live_session returns: enough to enter the screen.
class JoinedLiveSession {
  const JoinedLiveSession({
    required this.id,
    required this.title,
    required this.status,
    required this.index,
    required this.total,
    required this.questionSeconds,
  });

  final String id;
  final String title;
  final String status;
  final int index;
  final int total;
  final int questionSeconds;
}

class LiveOption {
  const LiveOption({required this.key, required this.text});

  final String key;
  final String text;
}

/// A key-free question as served during the question and reveal phases.
class LiveQuestion {
  const LiveQuestion({
    required this.id,
    required this.stem,
    required this.options,
  });

  factory LiveQuestion.fromJson(Map<String, dynamic> json) => LiveQuestion(
        id: json['id'] as String,
        stem: json['stem'] as String? ?? '',
        options: [
          for (final o in json['options'] as List? ?? const [])
            LiveOption(
              key: (o as Map)['key'] as String? ?? '',
              text: o['text'] as String? ?? '',
            ),
        ],
      );

  final String id;
  final String stem;
  final List<LiveOption> options;
}

/// One get_live_question snapshot. In lobby and ended phases only [status]
/// is populated; question and reveal phases carry the full payload.
class LiveQuestionState {
  const LiveQuestionState({
    required this.status,
    this.index = -1,
    this.total = 0,
    this.questionSeconds = 20,
    this.startedAt,
    this.question,
  });

  factory LiveQuestionState.fromJson(Map<String, dynamic> json) {
    final q = json['question'];
    final started = json['started_at'];
    return LiveQuestionState(
      status: json['status'] as String? ?? 'lobby',
      index: (json['index'] as num?)?.toInt() ?? -1,
      total: (json['total'] as num?)?.toInt() ?? 0,
      questionSeconds: (json['question_seconds'] as num?)?.toInt() ?? 20,
      startedAt: started is String ? DateTime.tryParse(started) : null,
      question:
          q is Map ? LiveQuestion.fromJson(Map<String, dynamic>.from(q)) : null,
    );
  }

  final String status; // lobby | question | reveal | ended
  final int index;
  final int total;
  final int questionSeconds;
  final DateTime? startedAt;
  final LiveQuestion? question;

  /// Identity of this snapshot for dedupe: two payloads with the same
  /// signature describe the same phase moment and must not re-fire
  /// transitions.
  String get signature => '$status:$index:'
      '${startedAt?.toUtc().microsecondsSinceEpoch}:${question?.id}';
}

/// live_reveal: the correct key, explanation, and per-option answer counts.
class LiveRevealData {
  const LiveRevealData({
    required this.questionId,
    required this.correctKey,
    required this.explanation,
    required this.counts,
  });

  factory LiveRevealData.fromJson(Map<String, dynamic> json) => LiveRevealData(
        questionId: json['question_id'] as String? ?? '',
        correctKey: json['correct_key'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        counts: {
          for (final e in (json['counts'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
      );

  final String questionId;
  final String correctKey;
  final String explanation;
  final Map<String, int> counts;
}

/// One live_scoreboard row. Handles are the pseudonymous generated ones;
/// no real names exist anywhere in the system.
class LiveStanding {
  const LiveStanding({
    required this.rank,
    required this.handle,
    required this.score,
    required this.correctCount,
    required this.isMe,
  });

  factory LiveStanding.fromJson(Map<String, dynamic> json) => LiveStanding(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        handle: json['handle'] as String? ?? 'anonymous',
        score: (json['score'] as num?)?.toInt() ?? 0,
        correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
        isMe: json['is_me'] == true,
      );

  final int rank;
  final String handle;
  final int score;
  final int correctCount;
  final bool isMe;
}

abstract class LiveSessionApi {
  /// The cohort's joinable session via active_live_session, or null.
  Future<ActiveLiveSession?> activeSession(String cohortId);

  /// Joins by session code via join_live_session.
  Future<JoinedLiveSession> joinByCode(String code);

  /// Records presence via enter_live_session, for entries reached through
  /// the LIVE NOW banner: that path never calls join_live_session (which
  /// records presence itself), so this fills the gap. Best-effort; callers
  /// must never let a failure here block entry into the session.
  Future<void> enterLiveSession(String sessionId);

  /// Headcount of public.live_participants for this session, for the
  /// lobby's "N in the lobby" line.
  Future<int> participantCount(String sessionId);

  /// The current phase snapshot via get_live_question (key-free).
  Future<LiveQuestionState> question(String sessionId);

  /// Submits via submit_live_answer. The server returns only "accepted";
  /// correctness stays hidden until the reveal.
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String key,
  });

  /// The reveal payload via live_reveal (reveal phase only for students).
  Future<LiveRevealData> reveal(String sessionId);

  /// Ranked standings via live_scoreboard (reveal/ended for students).
  Future<List<LiveStanding>> scoreboard(String sessionId);
}

class SupabaseLiveSessionApi implements LiveSessionApi {
  SupabaseLiveSessionApi(this._client);

  final SupabaseClient _client;

  @override
  Future<ActiveLiveSession?> activeSession(String cohortId) async {
    final res = await _client
        .rpc<dynamic>('active_live_session', params: {'p_cohort': cohortId});
    if (res is! Map) return null;
    final json = Map<String, dynamic>.from(res);
    return ActiveLiveSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Live session',
      status: json['status'] as String? ?? 'lobby',
    );
  }

  @override
  Future<JoinedLiveSession> joinByCode(String code) async {
    final res = await _client
        .rpc<dynamic>('join_live_session', params: {'p_code': code.trim()});
    final json = Map<String, dynamic>.from(res as Map);
    return JoinedLiveSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Live session',
      status: json['status'] as String? ?? 'lobby',
      index: (json['index'] as num?)?.toInt() ?? -1,
      total: (json['total'] as num?)?.toInt() ?? 0,
      questionSeconds: (json['question_seconds'] as num?)?.toInt() ?? 20,
    );
  }

  @override
  Future<void> enterLiveSession(String sessionId) async {
    await _client
        .rpc<dynamic>('enter_live_session', params: {'p_session': sessionId});
  }

  @override
  Future<int> participantCount(String sessionId) async {
    final res = await _client
        .from('live_participants')
        .select()
        .eq('session_id', sessionId)
        .count(CountOption.exact);
    return res.count;
  }

  @override
  Future<LiveQuestionState> question(String sessionId) async {
    final res = await _client
        .rpc<dynamic>('get_live_question', params: {'p_session': sessionId});
    return LiveQuestionState.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String key,
  }) async {
    await _client.rpc<dynamic>(
      'submit_live_answer',
      params: {
        'p_session': sessionId,
        'p_question': questionId,
        'p_key': key,
      },
    );
  }

  @override
  Future<LiveRevealData> reveal(String sessionId) async {
    final res = await _client
        .rpc<dynamic>('live_reveal', params: {'p_session': sessionId});
    return LiveRevealData.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<LiveStanding>> scoreboard(String sessionId) async {
    final res = await _client
        .rpc<dynamic>('live_scoreboard', params: {'p_session': sessionId});
    return [
      for (final row in res as List? ?? const [])
        LiveStanding.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }
}

/// Streams deduped [LiveQuestionState] snapshots for one session.
///
/// Two sources feed one stream: Realtime postgres_changes UPDATE events on
/// the session row (fast path), and a poll of get_live_question every
/// [pollInterval] (survival path; campus wifi kills websockets). A Realtime
/// nudge does not trust the row payload; it triggers the same fetch the
/// poll uses, so there is exactly one code path and one dedupe. Snapshots
/// with an unchanged [LiveQuestionState.signature] are dropped.
class LiveSessionChannel {
  LiveSessionChannel({
    required LiveSessionApi api,
    required String sessionId,
    SupabaseClient? realtime,
    this.pollInterval = const Duration(seconds: 3),
  })  : _api = api,
        _sessionId = sessionId,
        _realtime = realtime;

  final LiveSessionApi _api;
  final String _sessionId;
  final SupabaseClient? _realtime;
  final Duration pollInterval;

  final StreamController<LiveQuestionState> _states =
      StreamController<LiveQuestionState>.broadcast();
  RealtimeChannel? _channel;
  Timer? _poll;
  String? _lastSignature;
  bool _fetching = false;

  /// Deduped phase snapshots, newest wins. Broadcast; listen before [start].
  Stream<LiveQuestionState> get states => _states.stream;

  void start() {
    final rt = _realtime;
    if (rt != null && _channel == null) {
      _channel = rt.channel('live-session-$_sessionId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _sessionId,
          ),
          callback: (_) => unawaited(fetchNow()),
        )
        ..subscribe();
    }
    _poll ??= Timer.periodic(pollInterval, (_) => unawaited(fetchNow()));
    unawaited(fetchNow());
  }

  /// One fetch-and-maybe-emit pass. Reentrancy-guarded so a slow response
  /// never stacks requests; failures are silent because the next poll tick
  /// retries anyway.
  Future<void> fetchNow() async {
    if (_fetching || _states.isClosed) return;
    _fetching = true;
    try {
      final snapshot = await _api.question(_sessionId);
      if (_states.isClosed) return;
      if (snapshot.signature == _lastSignature) return;
      _lastSignature = snapshot.signature;
      _states.add(snapshot);
    } catch (_) {
      // Offline blip or transient RPC failure: the poll retries.
    } finally {
      _fetching = false;
    }
  }

  Future<void> dispose() async {
    _poll?.cancel();
    _poll = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _realtime?.removeChannel(channel);
    }
    await _states.close();
  }
}
