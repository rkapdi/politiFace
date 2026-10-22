// lib/features/live/application/live_session_controller.dart
//
// Owns one student's ride through a live session:
//
//   joined (lobby) -> question (open, local countdown) -> answered (locked)
//   -> reveal (correct key + my result + counts + standings) -> next
//   question -> ... -> ended (final standings).
//
// The server is the only truth. Snapshots arrive via LiveSessionChannel
// (Realtime nudge + 3-second poll, deduped); the local countdown is a
// cosmetic ticker derived from the server's started_at + question_seconds
// and re-clamped on every snapshot, never a clock of its own. Answer
// submission is fire-once, and correctness is NEVER shown before the
// reveal: submit returns only "accepted", and my result exists only once
// the reveal payload is in hand.
//
// Answering is two taps, like the daily trivia: pick an option (pending,
// changeable), then say how sure you are, which locks it in. If the
// countdown runs out on a picked but unconfirmed option, it is sent
// without a confidence so the pick still counts. Confidence is metadata;
// the server never scores with it. Each revealed answer that carried one
// feeds the end-of-session calibration card.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, Supabase, SupabaseClient;

import '../../../core/sync/supabase_config.dart';
import '../../trivia/domain/calibration.dart';
import '../../trivia/domain/trivia_question.dart';
import '../data/live_session_api.dart';

final liveSessionApiProvider = Provider<LiveSessionApi?>(
  (ref) => SupabaseConfig.isConfigured
      ? SupabaseLiveSessionApi(Supabase.instance.client)
      : null,
);

/// Route payload for /live (same shape of pattern as BillDetailArgs).
class LiveSessionArgs {
  const LiveSessionArgs({required this.sessionId, required this.title});

  final String sessionId;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is LiveSessionArgs &&
      other.sessionId == sessionId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(sessionId, title);
}

enum LivePhase { connecting, lobby, question, reveal, ended }

/// My verdict for the current question, defined only during the reveal.
enum LiveOutcome { correct, incorrect, unanswered }

class LiveSessionState {
  const LiveSessionState({
    required this.phase,
    required this.title,
    this.index = -1,
    this.total = 0,
    this.questionSeconds = 20,
    this.speedBonus = true,
    this.startedAt,
    this.question,
    this.pendingKey,
    this.lockedKey,
    this.lockedConfidence,
    this.answerAccepted = false,
    this.submitting = false,
    this.notice,
    this.reveal,
    this.standings = const [],
    this.remainingSeconds = 0,
    this.outcomes = const [],
  });

  const LiveSessionState.initial(String title)
      : this(phase: LivePhase.connecting, title: title);

  final LivePhase phase;
  final String title;
  final int index; // 0-based current question index
  final int total;
  final int questionSeconds;

  /// Whether faster correct answers earn bonus points this session.
  final bool speedBonus;
  final DateTime? startedAt;
  final LiveQuestion? question;

  /// Picked but not yet locked in (waiting for a confidence tap).
  final String? pendingKey;

  /// The choice locked in for the current question, if any. Locking is
  /// visual only until the reveal; it carries zero correctness signal.
  final String? lockedKey;

  /// The confidence the locked choice was sent with, if any.
  final TriviaConfidence? lockedConfidence;

  /// Whether the server accepted the locked answer. False while in flight
  /// and when the submission arrived too late.
  final bool answerAccepted;
  final bool submitting;

  /// A short user-facing note ('Too late for this one.'), or null.
  final String? notice;

  final LiveRevealData? reveal;
  final List<LiveStanding> standings;

  /// Cosmetic countdown, always derived from server started_at.
  final double remainingSeconds;

  /// Revealed answers that carried a confidence, for calibration.
  final List<ConfidenceOutcome> outcomes;

  LiveOutcome? get outcome {
    final r = reveal;
    if (phase != LivePhase.reveal || r == null) return null;
    if (lockedKey == null || !answerAccepted) return LiveOutcome.unanswered;
    return lockedKey == r.correctKey
        ? LiveOutcome.correct
        : LiveOutcome.incorrect;
  }

  /// My row in the standings, or null before any score lands.
  LiveStanding? get myStanding {
    for (final s in standings) {
      if (s.isMe) return s;
    }
    return null;
  }

  static const _unset = Object();

  LiveSessionState copyWith({
    LivePhase? phase,
    int? index,
    int? total,
    int? questionSeconds,
    bool? speedBonus,
    Object? startedAt = _unset,
    Object? question = _unset,
    Object? pendingKey = _unset,
    Object? lockedKey = _unset,
    Object? lockedConfidence = _unset,
    bool? answerAccepted,
    bool? submitting,
    Object? notice = _unset,
    Object? reveal = _unset,
    List<LiveStanding>? standings,
    double? remainingSeconds,
    List<ConfidenceOutcome>? outcomes,
  }) =>
      LiveSessionState(
        phase: phase ?? this.phase,
        title: title,
        index: index ?? this.index,
        total: total ?? this.total,
        questionSeconds: questionSeconds ?? this.questionSeconds,
        speedBonus: speedBonus ?? this.speedBonus,
        startedAt: identical(startedAt, _unset)
            ? this.startedAt
            : startedAt as DateTime?,
        question: identical(question, _unset)
            ? this.question
            : question as LiveQuestion?,
        pendingKey: identical(pendingKey, _unset)
            ? this.pendingKey
            : pendingKey as String?,
        lockedKey: identical(lockedKey, _unset)
            ? this.lockedKey
            : lockedKey as String?,
        lockedConfidence: identical(lockedConfidence, _unset)
            ? this.lockedConfidence
            : lockedConfidence as TriviaConfidence?,
        answerAccepted: answerAccepted ?? this.answerAccepted,
        submitting: submitting ?? this.submitting,
        notice: identical(notice, _unset) ? this.notice : notice as String?,
        reveal:
            identical(reveal, _unset) ? this.reveal : reveal as LiveRevealData?,
        standings: standings ?? this.standings,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        outcomes: outcomes ?? this.outcomes,
      );
}

class LiveSessionController extends StateNotifier<LiveSessionState> {
  LiveSessionController({
    required LiveSessionApi api,
    required LiveSessionArgs args,
    SupabaseClient? realtime,
    DateTime Function()? now,
  })  : _api = api,
        _args = args,
        _realtime = realtime,
        _now = now ?? DateTime.now,
        super(LiveSessionState.initial(args.title));

  final LiveSessionApi _api;
  final LiveSessionArgs _args;
  final SupabaseClient? _realtime;
  final DateTime Function() _now;

  LiveSessionChannel? _channel;
  StreamSubscription<LiveQuestionState>? _sub;
  Timer? _ticker;
  Timer? _retry;
  String? _appliedSignature;
  int _revealLoadedIndex = -1;
  bool _revealLoading = false;
  bool _finalLoaded = false;
  bool _finalLoading = false;

  /// The question id a submit is in flight for, if any. Scoped per
  /// question so a slow submit for Q(n) never blocks answering Q(n+1).
  String? _submittingQuestionId;

  /// Question ids already folded into [LiveSessionState.outcomes], so a
  /// reveal retry never counts the same answer twice.
  final _calibrated = <String>{};

  /// When we anchored the current countdown, plus the server started_at it
  /// was anchored to. Re-anchoring on a started_at change gives a monotonic
  /// countdown that survives device-clock skew yet still snaps to a
  /// server-corrected start.
  DateTime? _questionReceivedAt;
  DateTime? _anchoredStartedAt;

  /// Wires the channel (Realtime + poll) and pulls the first snapshot.
  void start() {
    if (_channel != null) return;
    // Best-effort presence record. The LIVE NOW banner pushes straight to
    // this screen without ever calling join_live_session (which records
    // presence itself), so this fills that gap; the code-join path calling
    // it again is a harmless duplicate (server-side "on conflict do
    // nothing"). Never blocks entry: a failure here is silently swallowed.
    unawaited(_api.enterLiveSession(_args.sessionId).catchError((_, __) {}));
    final channel = LiveSessionChannel(
      api: _api,
      sessionId: _args.sessionId,
      realtime: _realtime,
    );
    _channel = channel;
    _sub = channel.states.listen(applySnapshot);
    channel.start();
  }

  /// One direct fetch-and-apply, used at init and by tests. Failures are
  /// silent; the poll retries.
  Future<void> refresh() async {
    try {
      applySnapshot(await _api.question(_args.sessionId));
    } catch (_) {
      // Transient; the channel poll is the retry loop.
    }
  }

  /// Applies a server snapshot. Idempotent: a payload whose signature
  /// matches the last applied one is dropped, so the double source
  /// (Realtime + poll) can never re-fire a transition, reset a lock, or
  /// restart the countdown.
  void applySnapshot(LiveQuestionState snapshot) {
    if (!mounted) return;
    if (snapshot.signature == _appliedSignature) return;
    _appliedSignature = snapshot.signature;

    switch (snapshot.status) {
      case 'lobby':
        _stopTicker();
        state = state.copyWith(phase: LivePhase.lobby);
      case 'question':
        final isNewQuestion =
            state.phase != LivePhase.question || snapshot.index != state.index;
        state = state.copyWith(
          phase: LivePhase.question,
          index: snapshot.index,
          total: snapshot.total,
          questionSeconds: snapshot.questionSeconds,
          speedBonus: snapshot.speedBonus,
          startedAt: snapshot.startedAt,
          question: snapshot.question ?? state.question,
          // A brand-new question wipes the previous one's lock, verdict,
          // and notice; a re-clamp of the same question keeps them.
          pendingKey: isNewQuestion ? null : state.pendingKey,
          lockedKey: isNewQuestion ? null : state.lockedKey,
          lockedConfidence: isNewQuestion ? null : state.lockedConfidence,
          answerAccepted: !isNewQuestion && state.answerAccepted,
          submitting: !isNewQuestion && state.submitting,
          notice: isNewQuestion ? null : state.notice,
          reveal: isNewQuestion ? null : state.reveal,
          standings: isNewQuestion ? const [] : state.standings,
        );
        if (isNewQuestion) {
          // Stop treating a stalled prior-question submit as in flight.
          _submittingQuestionId = null;
        }
        // (Re)anchor the monotonic clock whenever the server start changes,
        // including a corrected started_at on the same question.
        if (_anchoredStartedAt != snapshot.startedAt) {
          _anchoredStartedAt = snapshot.startedAt;
          _questionReceivedAt = _now();
        }
        _recomputeRemaining();
        _startTicker();
      case 'reveal':
        _stopTicker();
        state = state.copyWith(
          phase: LivePhase.reveal,
          index: snapshot.index,
          total: snapshot.total,
          questionSeconds: snapshot.questionSeconds,
          speedBonus: snapshot.speedBonus,
          question: snapshot.question ?? state.question,
          startedAt: null,
          remainingSeconds: 0,
          // An unconfirmed pick never became an answer.
          pendingKey: null,
        );
        if (_revealLoadedIndex != snapshot.index) {
          unawaited(_loadReveal(snapshot.index));
        }
      case 'ended':
        _stopTicker();
        state = state.copyWith(phase: LivePhase.ended, startedAt: null);
        if (!_finalLoaded) unawaited(_loadFinalStandings());
    }
  }

  /// First tap: picks an option without sending it. Changeable until a
  /// confidence locks it in.
  void pickAnswer(String key) {
    if (state.phase != LivePhase.question || state.question == null) return;
    if (state.lockedKey != null) return;
    state = state.copyWith(pendingKey: key, notice: null);
  }

  /// Second tap: locks the picked option in with [confidence].
  Future<void> confirmPick(TriviaConfidence confidence) async {
    final key = state.pendingKey;
    if (key == null) return;
    await selectAnswer(key, confidence: confidence);
  }

  /// Fire-once answer lock. Double-taps and re-taps are ignored; a late
  /// arrival ('time is up' / 'question is not open') keeps the visual lock
  /// but records it as not accepted and shows a gentle notice. The server
  /// withholds correctness, so nothing here can leak the answer.
  Future<void> selectAnswer(String key, {TriviaConfidence? confidence}) async {
    final question = state.question;
    if (question == null || state.phase != LivePhase.question) return;
    if (state.lockedKey != null || _submittingQuestionId == question.id) {
      return;
    }
    _submittingQuestionId = question.id;
    state = state.copyWith(
      lockedKey: key,
      lockedConfidence: confidence,
      pendingKey: null,
      submitting: true,
      notice: null,
    );
    try {
      try {
        await _api.submitAnswer(
          sessionId: _args.sessionId,
          questionId: question.id,
          key: key,
          confidence: confidence?.wireValue,
        );
      } on PostgrestException {
        rethrow; // server verdicts do not get a blind retry
      } catch (_) {
        // One silent retry for transport stalls; the countdown allows it.
        await _api.submitAnswer(
          sessionId: _args.sessionId,
          questionId: question.id,
          key: key,
          confidence: confidence?.wireValue,
        );
      }
      // Only mark accepted if we are still on this question and have not
      // already moved to the reveal: a late success must not flip a verdict
      // the student has already been shown and heard.
      if (mounted &&
          state.phase == LivePhase.question &&
          state.question?.id == question.id) {
        state = state.copyWith(submitting: false, answerAccepted: true);
      }
    } on PostgrestException catch (e) {
      if (mounted) _handleSubmitRejection(e.message);
    } catch (_) {
      if (mounted) {
        // Never reached the server: unlock so the student can retry. The
        // pick stays, so one confidence tap resends it.
        state = state.copyWith(
          lockedKey: null,
          lockedConfidence: null,
          pendingKey: key,
          submitting: false,
          notice: 'Could not send that. Tap an answer to try again.',
        );
      }
    } finally {
      if (_submittingQuestionId == question.id) _submittingQuestionId = null;
    }
  }

  void _handleSubmitRejection(String message) {
    final m = message.toLowerCase();
    if (m.contains('time is up') || m.contains('question is not open')) {
      state = state.copyWith(
        submitting: false,
        notice: 'Too late for this one.',
      );
    } else {
      state = state.copyWith(
        pendingKey: state.lockedKey,
        lockedKey: null,
        lockedConfidence: null,
        submitting: false,
        notice: 'That did not go through. Tap an answer to try again.',
      );
    }
  }

  Future<void> _loadReveal(int index) async {
    if (_revealLoading) return;
    _revealLoading = true;
    try {
      final reveal = await _api.reveal(_args.sessionId);
      final standings = await _api.scoreboard(_args.sessionId);
      if (!mounted) return;
      _revealLoadedIndex = index;
      if (state.phase == LivePhase.reveal && state.index == index) {
        state = state.copyWith(
          reveal: reveal,
          standings: standings,
          outcomes: _withOutcome(reveal),
        );
      }
    } catch (_) {
      // The dedupe means no snapshot will re-trigger this, so retry
      // ourselves while the reveal is still on stage.
      _scheduleRetry(() {
        if (state.phase == LivePhase.reveal && state.index == index) {
          unawaited(_loadReveal(index));
        }
      });
    } finally {
      _revealLoading = false;
    }
  }

  /// Folds my revealed answer into the calibration list when it carried a
  /// confidence and the server accepted it. Once per question.
  List<ConfidenceOutcome> _withOutcome(LiveRevealData reveal) {
    final confidence = state.lockedConfidence;
    final key = state.lockedKey;
    if (confidence == null ||
        key == null ||
        !state.answerAccepted ||
        !_calibrated.add(reveal.questionId)) {
      return state.outcomes;
    }
    return [
      ...state.outcomes,
      ConfidenceOutcome(confidence: confidence, correct: key == reveal.correctKey),
    ];
  }

  Future<void> _loadFinalStandings() async {
    if (_finalLoading) return;
    _finalLoading = true;
    try {
      final standings = await _api.scoreboard(_args.sessionId);
      if (!mounted) return;
      _finalLoaded = true;
      state = state.copyWith(standings: standings);
    } catch (_) {
      _scheduleRetry(() {
        if (state.phase == LivePhase.ended) unawaited(_loadFinalStandings());
      });
    } finally {
      _finalLoading = false;
    }
  }

  void _scheduleRetry(void Function() action) {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 3), () {
      if (mounted) action();
    });
  }

  // ── countdown ─────────────────────────────────────────────────────────────
  // Purely cosmetic. remaining = question_seconds - (now - started_at),
  // clamped into [0, question_seconds]; every snapshot re-derives it from
  // the server's started_at, so a drifting device clock self-corrects at
  // the next poll or push.

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _recomputeRemaining(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _recomputeRemaining() {
    if (!mounted) return;
    final startedAt = state.startedAt;
    if (startedAt == null) return;
    // Elapsed is measured from when THIS client received the question,
    // offset by however much of the window the server says had already
    // passed. This is immune to absolute device-clock skew (a fast clock
    // no longer forces the bar to 0 for the entire question).
    final serverElapsedAtReceiptMs = (_questionReceivedAt == null)
        ? 0
        : _questionReceivedAt!
            .toUtc()
            .difference(startedAt.toUtc())
            .inMilliseconds
            .clamp(0, state.questionSeconds * 1000);
    final sinceReceiptMs = (_questionReceivedAt == null)
        ? 0
        : _now().difference(_questionReceivedAt!).inMilliseconds;
    final elapsedMs = serverElapsedAtReceiptMs + sinceReceiptMs;
    final remaining = (state.questionSeconds - elapsedMs / 1000)
        .clamp(0.0, state.questionSeconds.toDouble());
    if (remaining <= 0) {
      _stopTicker();
      // Picked but never confirmed: send the pick without a confidence so
      // it still counts (the server allows a short grace past zero).
      final pending = state.pendingKey;
      if (pending != null &&
          state.lockedKey == null &&
          state.phase == LivePhase.question) {
        unawaited(selectAnswer(pending));
      }
    }
    if (remaining != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: remaining);
    }
  }

  @override
  void dispose() {
    _stopTicker();
    _retry?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_channel?.dispose());
    _channel = null;
    super.dispose();
  }
}

final liveSessionControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveSessionController, LiveSessionState, LiveSessionArgs>(
  (ref, args) {
    final api = ref.watch(liveSessionApiProvider);
    if (api == null) {
      // The screen never routes here unconfigured; this is a belt to the
      // screen's suspenders.
      throw StateError('Live sessions need a configured backend.');
    }
    return LiveSessionController(
      api: api,
      args: args,
      realtime: Supabase.instance.client,
    )..start();
  },
);
