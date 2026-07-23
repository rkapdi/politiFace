// The live question screen, rendered against a fake API (no network, no
// database, no Realtime): options come from the jsonb options shape
// [{key, text}], a tap locks the choice, and nothing on screen leaks the
// correct answer before the reveal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/live/application/live_session_controller.dart';
import 'package:politiface/features/live/data/live_session_api.dart';
import 'package:politiface/features/live/presentation/live_session_screen.dart';

const _args =
    LiveSessionArgs(sessionId: 'session-1', title: 'Federalism pop quiz');

class FakeLiveSessionApi implements LiveSessionApi {
  FakeLiveSessionApi(this.snapshot);

  LiveQuestionState snapshot;
  final submissions = <String>[];

  @override
  Future<ActiveLiveSession?> activeSession(String cohortId) async => null;

  @override
  Future<JoinedLiveSession> joinByCode(String code) async =>
      throw UnimplementedError();

  @override
  Future<LiveQuestionState> question(String sessionId) async => snapshot;

  @override
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String key,
  }) async {
    submissions.add(key);
  }

  @override
  Future<LiveRevealData> reveal(String sessionId) async =>
      throw UnimplementedError();

  @override
  Future<List<LiveStanding>> scoreboard(String sessionId) async => const [];
}

void main() {
  testWidgets('question renders jsonb options, tap locks, no answer leak',
      (tester) async {
    // The exact wire shape get_live_question returns during the question
    // phase, options as jsonb [{key, text}].
    final snapshot = LiveQuestionState.fromJson({
      'status': 'question',
      'index': 0,
      'total': 5,
      'question_seconds': 20,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'question': {
        'id': 'q-0',
        'stem': 'How many branches does the federal government have?',
        'options': [
          {'key': 'a', 'text': 'Two'},
          {'key': 'b', 'text': 'Three'},
          {'key': 'c', 'text': 'Four'},
        ],
      },
    });
    final api = FakeLiveSessionApi(snapshot);
    final controller = LiveSessionController(api: api, args: _args);
    await controller.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionApiProvider.overrideWithValue(api),
          liveSessionControllerProvider.overrideWith((ref, args) => controller),
        ],
        child: const MaterialApp(home: LiveSessionScreen(args: _args)),
      ),
    );
    await tester.pump();

    // The question and every option from the jsonb shape are on screen.
    expect(
      find.text('How many branches does the federal government have?'),
      findsOneWidget,
    );
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
    expect(find.text('QUESTION 1 OF 5'), findsOneWidget);
    expect(find.text('LOCKED IN'), findsNothing);

    // Tap an option: it locks visually and reaches the server once.
    await tester.tap(find.text('Three'));
    await tester.pump();
    expect(find.text('LOCKED IN'), findsOneWidget);
    expect(api.submissions, ['b']);

    // A second tap on another option changes nothing: fire-once.
    await tester.tap(find.text('Four'), warnIfMissed: false);
    await tester.pump();
    expect(api.submissions, ['b']);

    // No correctness leak before the reveal: no verdict icons, no verdict
    // words, no explanation.
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.textContaining('CORRECT'), findsNothing);
    expect(find.textContaining('Legislative'), findsNothing);
    expect(find.text('The answer arrives with the reveal.'), findsOneWidget);
  });
}
