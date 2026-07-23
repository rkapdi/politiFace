// The class-join form, rendered against a fake API (no network, no
// database): the roster name field is required client-side before the
// join ever reaches join_cohort, since professor reports are the point of
// joining a class.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/leaderboard/application/leaderboard_providers.dart';
import 'package:politiface/features/leaderboard/data/leaderboard_api.dart';
import 'package:politiface/features/leaderboard/presentation/leaderboard_screen.dart';

class FakeLeaderboardApi implements LeaderboardApi {
  final joinCalls = <({String code, String rosterName})>[];
  final rosterNameCalls = <({String cohortId, String name})>[];

  @override
  Future<List<CohortInfo>> myCohorts() async => const [];

  @override
  Future<List<LeaderboardEntry>> entries(String cohortId) async => const [];

  @override
  Future<String> joinCohort(String code, String rosterName) async {
    joinCalls.add((code: code, rosterName: rosterName));
    return 'cohort-1';
  }

  @override
  Future<void> setRosterName(String cohortId, String name) async {
    rosterNameCalls.add((cohortId: cohortId, name: name));
  }
}

Widget _app(
  FakeLeaderboardApi api, {
  required void Function(String) onJoined,
}) =>
    ProviderScope(
      overrides: [leaderboardApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Scaffold(
          body: JoinCohortView(onJoined: onJoined),
        ),
      ),
    );

void main() {
  testWidgets('join is blocked client-side until a roster name is entered',
      (tester) async {
    final api = FakeLeaderboardApi();
    String? joinedId;

    await tester.pumpWidget(_app(api, onJoined: (id) => joinedId = id));

    // Class code filled in, roster name left blank.
    await tester.enterText(
      find.widgetWithText(TextField, 'Class code'),
      'ABC123',
    );
    await tester.tap(find.text('JOIN CLASS'));
    await tester.pump();

    // Client-side validation stops it before the network call, and no
    // cohort is ever reported joined.
    expect(api.joinCalls, isEmpty);
    expect(joinedId, isNull);
    expect(find.textContaining('Enter your name'), findsOneWidget);

    // A name that is too short (server floor is 2 characters) is rejected
    // the same way.
    await tester.enterText(
      find.widgetWithText(TextField, 'Your name (as your professor knows you)'),
      'A',
    );
    await tester.tap(find.text('JOIN CLASS'));
    await tester.pump();
    expect(api.joinCalls, isEmpty);

    // A valid name lets the join go through, roster name included.
    await tester.enterText(
      find.widgetWithText(TextField, 'Your name (as your professor knows you)'),
      'Jordan Rivera',
    );
    await tester.tap(find.text('JOIN CLASS'));
    await tester.pump();

    expect(api.joinCalls, [(code: 'ABC123', rosterName: 'Jordan Rivera')]);
    expect(joinedId, 'cohort-1');
  });
}
