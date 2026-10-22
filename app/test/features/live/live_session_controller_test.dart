// Controller state machine for live sessions, driven by a fake API: the
// full lifecycle, the fire-once answer lock, the late-answer path, poll
// dedupe, and the server-clamped countdown. No network, no database.

import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/live/application/live_session_controller.dart';
import 'package:politiface/features/live/data/live_session_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _args =
    LiveSessionArgs(sessionId: 'session-1', title: 'Federalism pop quiz');

const _question0 = LiveQuestion(
  id: 'q-0',
  stem: 'How many branches does the federal government have?',
  options: [
    LiveOption(key: 'a', text: 'Two'),
    LiveOption(key: 'b', text: 'Three'),
    LiveOption(key: 'c', text: 'Four'),
  ],
);

class FakeLiveSessionApi implements LiveSessionApi {
  LiveQuestionState snapshot = const LiveQuestionState(status: 'lobby');
  LiveRevealData revealData = const LiveRevealData(
    questionId: 'q-0',
    correctKey: 'b',
    explanation: 'Legislative, executive, judicial.',
    counts: {'a': 2, 'b': 9, 'c': 1},
  );
  List<LiveStanding> board = const [
    LiveStanding(
      rank: 1,
      handle: 'brisk-otter',
      score: 140,
      correctCount: 1,
      isMe: false,
    ),
    LiveStanding(
      rank: 2,
      handle: 'calm-heron',
      score: 120,
      correctCount: 1,
      isMe: true,
    ),
  ];
  PostgrestException? submitError;
  final submissions = <({String sessionId, String questionId, String key})>[];
  int questionCalls = 0;
  final enteredSessions = <String>[];
  Exception? enterError;
  int participantCountValue = 0;

  @override
  Future<ActiveLiveSession?> activeSession(String cohortId) async => null;

  @override
  Future<JoinedLiveSession> joinByCode(String code) async =>
      const JoinedLiveSession(
        id: 'session-1',
        title: 'Federalism pop quiz',
        status: 'lobby',
        index: -1,
        total: 2,
        questionSeconds: 20,
      );

  @override
  Future<void> enterLiveSession(String sessionId) async {
    enteredSessions.add(sessionId);
    final error = enterError;
    if (error != null) throw error;
  }

  @override
  Future<int> participantCount(String sessionId) async => participantCountValue;

  @override
  Future<LiveQuestionState> question(String sessionId) async {
    questionCalls++;
    return snapshot;
  }

  @override
  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    required String key,
  }) async {
    final error = submitError;
    if (error != null) throw error;
    submissions.add((sessionId: sessionId, questionId: questionId, key: key));
  }

  @override
  Future<LiveRevealData> reveal(String sessionId) async => revealData;

  @override
  Future<List<LiveStanding>> scoreboard(String sessionId) async => board;
}

LiveQuestionState _questionSnapshot({DateTime? startedAt}) => LiveQuestionState(
      status: 'question',
      index: 0,
      total: 2,
      startedAt: startedAt ?? DateTime.utc(2026, 7, 22, 12),
      question: _question0,
    );

void main() {
  late FakeLiveSessionApi api;
  late LiveSessionController controller;

  LiveSessionController buildController({DateTime Function()? now}) =>
      LiveSessionController(api: api, args: _args, now: now);

  setUp(() {
    api = FakeLiveSessionApi();
    controller = buildController(
      // Frozen just after the question opens, so the countdown is full and
      // the ticker computation is deterministic.
      now: () => DateTime.utc(2026, 7, 22, 12, 0, 1),
    );
  });

  tearDown(() => controller.dispose());

  test('walks joined -> question -> answered -> reveal -> ended', () async {
    // Joined: the lobby snapshot lands.
    await controller.refresh();
    expect(controller.state.phase, LivePhase.lobby);

    // Question opens.
    api.snapshot = _questionSnapshot();
    await controller.refresh();
    expect(controller.state.phase, LivePhase.question);
    expect(controller.state.question?.stem, _question0.stem);
    expect(controller.state.lockedKey, isNull);
    expect(controller.state.reveal, isNull);

    // Answer locks exactly once; the double-tap is swallowed.
    await controller.selectAnswer('b');
    await controller.selectAnswer('c');
    expect(controller.state.lockedKey, 'b');
    expect(controller.state.answerAccepted, isTrue);
    expect(api.submissions, hasLength(1));
    expect(api.submissions.single.key, 'b');
    expect(api.submissions.single.questionId, 'q-0');
    // Correctness is never known before the reveal.
    expect(controller.state.outcome, isNull);

    // Reveal: correct key, counts, standings, my verdict.
    api.snapshot = const LiveQuestionState(
      status: 'reveal',
      index: 0,
      total: 2,
      question: _question0,
    );
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.phase, LivePhase.reveal);
    expect(controller.state.reveal?.correctKey, 'b');
    expect(controller.state.reveal?.counts['b'], 9);
    expect(controller.state.outcome, LiveOutcome.correct);
    expect(controller.state.standings, hasLength(2));
    expect(controller.state.myStanding?.handle, 'calm-heron');

    // Ended: final standings and my rank.
    api.snapshot = const LiveQuestionState(status: 'ended');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.phase, LivePhase.ended);
    expect(controller.state.myStanding?.rank, 2);
  });

  test('late answer keeps the lock, shows the notice, never a verdict',
      () async {
    api.snapshot = _questionSnapshot();
    await controller.refresh();

    api.submitError = const PostgrestException(message: 'time is up');
    await controller.selectAnswer('a');
    expect(controller.state.lockedKey, 'a');
    expect(controller.state.answerAccepted, isFalse);
    expect(controller.state.notice, 'Too late for this one.');

    // "question is not open" walks the same graceful path.
    final closed = buildController();
    addTearDown(closed.dispose);
    api.snapshot = _questionSnapshot();
    await closed.refresh();
    api.submitError = const PostgrestException(message: 'question is not open');
    await closed.selectAnswer('c');
    expect(closed.state.notice, 'Too late for this one.');
    expect(closed.state.answerAccepted, isFalse);

    // At the reveal a rejected answer reads as unanswered, never right or
    // wrong.
    api.snapshot = const LiveQuestionState(
      status: 'reveal',
      index: 0,
      total: 2,
      question: _question0,
    );
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.outcome, LiveOutcome.unanswered);
  });

  test('same payload twice does not re-fire transitions', () async {
    api.snapshot = _questionSnapshot();
    await controller.refresh();
    await controller.selectAnswer('b');
    expect(controller.state.lockedKey, 'b');

    var emissions = 0;
    controller.addListener((_) => emissions++, fireImmediately: false);

    // The poll fallback returns the identical payload again: no state
    // emission, no lock reset, no countdown restart.
    controller.applySnapshot(_questionSnapshot());
    expect(emissions, 0);
    expect(controller.state.lockedKey, 'b');
    expect(controller.state.phase, LivePhase.question);
  });

  test('channel drops back-to-back identical snapshots', () async {
    api.snapshot = _questionSnapshot();
    final channel = LiveSessionChannel(api: api, sessionId: 'session-1');
    final seen = <String>[];
    final sub = channel.states.listen((s) => seen.add(s.signature));
    addTearDown(() async {
      await sub.cancel();
      await channel.dispose();
    });

    await channel.fetchNow();
    await channel.fetchNow();
    expect(api.questionCalls, 2);
    expect(seen, hasLength(1));
  });

  test('countdown clamps to server started_at', () async {
    // Device clock says 15s have already elapsed on a 20s question: the
    // bar must start at 5s remaining, not 20.
    var deviceNow = DateTime.utc(2026, 7, 22, 12, 0, 15);
    final clamped = LiveSessionController(
      api: api,
      args: _args,
      now: () => deviceNow,
    );
    addTearDown(clamped.dispose);
    api.snapshot = _questionSnapshot(startedAt: DateTime.utc(2026, 7, 22, 12));
    await clamped.refresh();
    expect(clamped.state.remainingSeconds, closeTo(5, 0.05));

    // A later poll carries a corrected started_at (the server restarted the
    // question); the countdown snaps to server truth instead of drifting.
    deviceNow = DateTime.utc(2026, 7, 22, 12, 0, 40);
    api.snapshot =
        _questionSnapshot(startedAt: DateTime.utc(2026, 7, 22, 12, 0, 38));
    await clamped.refresh();
    expect(clamped.state.remainingSeconds, closeTo(18, 0.05));

    // Elapsed beyond the window clamps to zero, never negative.
    deviceNow = DateTime.utc(2026, 7, 22, 12, 1, 40);
    clamped.applySnapshot(
      _questionSnapshot(startedAt: DateTime.utc(2026, 7, 22, 12, 1)),
    );
    // Same question restarted at a new started_at is a new signature, so it
    // applies; 40s elapsed on a 20s window floors at 0.
    expect(clamped.state.remainingSeconds, 0);
  });

  test('start() records presence best-effort and never blocks on failure',
      () async {
    // The banner-entry path never calls join_live_session (which records
    // its own presence row), so start() must call enter_live_session
    // itself, and a failure there must not stop the session from working.
    api.enterError = Exception('offline');
    controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(api.enteredSessions, ['session-1']);

    // The rest of the lifecycle proceeds unaffected by that failure.
    api.snapshot = _questionSnapshot();
    await controller.refresh();
    expect(controller.state.phase, LivePhase.question);
  });
}
