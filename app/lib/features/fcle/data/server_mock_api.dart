// lib/features/fcle/data/server_mock_api.dart
//
// The three mock RPCs behind an interface so ServerMockSession is testable
// without a server. SupabaseMockApi is the production implementation.

import 'package:supabase_flutter/supabase_flutter.dart';

class ServerMockItem {
  const ServerMockItem({
    required this.serverId,
    required this.domainCode,
    required this.stem,
    required this.options, // [{key, text}, ...]
    required this.citation,
  });

  final String serverId;
  final String domainCode;
  final String stem;
  final List<Map<String, dynamic>> options;
  final String citation;
}

class ServerMockAssembly {
  const ServerMockAssembly({required this.attemptId, required this.items});

  final String attemptId;
  final List<ServerMockItem> items;
}

class ServerMockOutcome {
  const ServerMockOutcome({
    required this.score,
    required this.passed,
    required this.perDomain, // {domain_code: {correct, total}}
  });

  final int score;
  final bool passed;
  final Map<String, Map<String, int>> perDomain;
}

abstract class ServerMockApi {
  Future<ServerMockAssembly> assembleMock(String kind);

  /// Returns the server's grading verdict.
  Future<bool> submitAnswer({
    required String eventId,
    required String serverQuestionId,
    required String chosenKey,
    required String attemptId,
  });

  Future<ServerMockOutcome> finalize(String attemptId);
}

class SupabaseMockApi implements ServerMockApi {
  SupabaseMockApi(this._client);

  final SupabaseClient _client;

  @override
  Future<ServerMockAssembly> assembleMock(String kind) async {
    final res = await _client
        .rpc<dynamic>('assemble_mock', params: {'p_kind': kind});
    final map = res as Map<String, dynamic>;
    return ServerMockAssembly(
      attemptId: map['attempt_id'] as String,
      items: [
        for (final q in map['questions'] as List<dynamic>)
          ServerMockItem(
            serverId: q['id'] as String,
            domainCode: q['domain'] as String,
            stem: q['stem'] as String,
            options: [
              for (final o in q['options'] as List<dynamic>)
                Map<String, dynamic>.from(o as Map),
            ],
            citation: q['citation'] as String? ?? '',
          ),
      ],
    );
  }

  @override
  Future<bool> submitAnswer({
    required String eventId,
    required String serverQuestionId,
    required String chosenKey,
    required String attemptId,
  }) async {
    final res = await _client.rpc<dynamic>('submit_answer', params: {
      'p_event_id': eventId,
      'p_question_id': serverQuestionId,
      'p_chosen_key': chosenKey,
      'p_client_ts': DateTime.now().toIso8601String(),
      'p_attempt_id': attemptId,
    },);
    return (res as Map<String, dynamic>)['correct'] as bool;
  }

  @override
  Future<ServerMockOutcome> finalize(String attemptId) async {
    final res = await _client
        .rpc<dynamic>('finalize_mock', params: {'p_attempt_id': attemptId});
    final map = res as Map<String, dynamic>;
    return ServerMockOutcome(
      score: map['score'] as int,
      passed: map['passed'] as bool,
      perDomain: {
        for (final e in (map['per_domain'] as Map<String, dynamic>).entries)
          e.key: {
            'correct': (e.value as Map)['correct'] as int,
            'total': (e.value as Map)['total'] as int,
          },
      },
    );
  }
}
