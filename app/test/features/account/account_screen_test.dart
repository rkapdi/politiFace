// AccountBody (the real production widget, see lib/features/account/
// presentation/account_screen.dart) rendered against a fake ProfileApi via
// provider override, no network and no Supabase, mirroring how
// JoinCohortView is tested in leaderboard_screen_test.dart. signOut /
// onSignedOut / onDeleted are injected fakes: AuthService wraps a real
// SupabaseClient with no fake seam yet, so session termination stays out
// of ProfileApi's scope here.
//
// Covers the three behaviors called out in the build task: handle edit
// calls update_my_profile and surfaces the server's error text verbatim,
// avatar pick optimistic-updates (and reverts on failure), and account
// deletion requires an explicit confirm dialog before delete_my_account is
// ever called.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/account/application/account_providers.dart';
import 'package:politiface/features/account/data/profile_api.dart';
import 'package:politiface/features/account/domain/avatars.dart';
import 'package:politiface/features/account/presentation/account_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class UpdateCall {
  UpdateCall({this.handle, this.school, this.avatarId});
  final String? handle;
  final String? school;
  final int? avatarId;
}

/// Fakes update_my_profile / delete_my_account so tests never touch
/// Supabase. [handleError], when set, is thrown verbatim (as the server
/// would via PostgrestException) whenever a handle update is attempted.
/// [avatarShouldThrow] simulates a network failure on the avatar RPC only.
class FakeProfileApi implements ProfileApi {
  FakeProfileApi({
    ProfileUpdate? initial,
    this.handleError,
    this.avatarShouldThrow = false,
  }) : _current = initial ??
            const ProfileUpdate(
              handle: 'civic_quill_0001',
              school: null,
              avatarId: 0,
            );

  ProfileUpdate _current;
  final String? handleError;
  final bool avatarShouldThrow;
  final calls = <UpdateCall>[];
  var deleteCalls = 0;

  @override
  Future<ProfileUpdate?> fetchMyProfile() async => _current;

  @override
  Future<ProfileUpdate> updateProfile({
    String? handle,
    String? school,
    int? avatarId,
  }) async {
    calls.add(UpdateCall(handle: handle, school: school, avatarId: avatarId));
    if (avatarId != null && avatarShouldThrow) {
      throw Exception('network down');
    }
    if (handle != null && handleError != null) {
      throw PostgrestException(message: handleError!);
    }
    _current = ProfileUpdate(
      handle: handle ?? _current.handle,
      school: school ?? _current.school,
      avatarId: avatarId ?? _current.avatarId,
    );
    return _current;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
  }
}

Widget _app(
  FakeProfileApi api, {
  required ProfileUpdate initial,
  VoidCallback? onSignedOut,
  VoidCallback? onDeleted,
}) =>
    ProviderScope(
      overrides: [profileApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Scaffold(
          body: AccountBody(
            initial: initial,
            signOut: () async {},
            onSignedOut: onSignedOut ?? () {},
            onDeleted: onDeleted ?? () {},
          ),
        ),
      ),
    );

/// The form's 48-tile avatar grid alone runs well past the default 800x600
/// test surface, so anything below it (the handle field, the danger zone)
/// never mounts at the default size. Grow the surface instead of scrolling
/// so every field is laid out and hittable up front.
void _useTallSurface(WidgetTester tester) {
  final originalSize = tester.view.physicalSize;
  final originalRatio = tester.view.devicePixelRatio;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalRatio;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 4000);
}

void main() {
  const initial = ProfileUpdate(
    handle: 'civic_quill_0001',
    school: null,
    avatarId: 0,
  );

  group('handle editing', () {
    testWidgets('saving a new handle calls update_my_profile and confirms',
        (tester) async {
      _useTallSurface(tester);
      final api = FakeProfileApi();
      await tester.pumpWidget(_app(api, initial: initial));

      await tester.enterText(
        find.widgetWithText(TextField, 'Handle'),
        'newhandle',
      );
      await tester.tap(find.text('SAVE').first);
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single.handle, 'newhandle');
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('a taken handle shows the server error text verbatim',
        (tester) async {
      _useTallSurface(tester);
      final api = FakeProfileApi(handleError: 'That handle is taken.');
      await tester.pumpWidget(_app(api, initial: initial));

      await tester.enterText(
        find.widgetWithText(TextField, 'Handle'),
        'taken_handle',
      );
      await tester.tap(find.text('SAVE').first);
      await tester.pumpAndSettle();

      expect(find.text('That handle is taken.'), findsOneWidget);
      expect(api.calls, hasLength(1));
    });
  });

  group('avatar picking', () {
    testWidgets(
        'picking an avatar optimistically updates the big preview '
        'and saves via update_my_profile', (tester) async {
      final api = FakeProfileApi();
      await tester.pumpWidget(_app(api, initial: initial));

      // Tap the grid tile for avatar id 5 ("Avatar 6").
      await tester.tap(find.bySemanticsLabel('Avatar 6'));
      await tester.pump(); // optimistic update happens before the RPC awaits

      // The big preview (96px) already shows avatar 5, before the fake's
      // Future even resolves.
      var bigAvatar = tester
          .widgetList<PolitifaceAvatar>(find.byType(PolitifaceAvatar))
          .firstWhere((w) => w.size == 96);
      expect(bigAvatar.avatarId, 5);

      await tester.pumpAndSettle();
      expect(api.calls, hasLength(1));
      expect(api.calls.single.avatarId, 5);

      bigAvatar = tester
          .widgetList<PolitifaceAvatar>(find.byType(PolitifaceAvatar))
          .firstWhere((w) => w.size == 96);
      expect(bigAvatar.avatarId, 5);
    });

    testWidgets('a failed avatar save reverts the optimistic pick',
        (tester) async {
      final api = FakeProfileApi(avatarShouldThrow: true);
      await tester.pumpWidget(_app(api, initial: initial));

      await tester.tap(find.bySemanticsLabel('Avatar 6')); // id 5
      await tester.pumpAndSettle();

      final bigAvatar = tester
          .widgetList<PolitifaceAvatar>(find.byType(PolitifaceAvatar))
          .firstWhere((w) => w.size == 96);
      // Reverted back to the original avatar id 0 after the failure.
      expect(bigAvatar.avatarId, 0);
      expect(
        find.text('Could not save your avatar. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('account deletion', () {
    testWidgets('delete requires explicit confirmation before it is called',
        (tester) async {
      _useTallSurface(tester);
      final api = FakeProfileApi();
      var deletedCalls = 0;
      await tester.pumpWidget(
        _app(api, initial: initial, onDeleted: () => deletedCalls++),
      );

      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();

      // The confirm dialog is up, but delete_my_account has not fired yet.
      expect(api.deleteCalls, 0);
      expect(
        find.text(
          'This permanently deletes your account and all your progress. '
          'This cannot be undone.',
        ),
        findsWidgets, // once in the dialog, once as the on-screen subtitle
      );

      // Cancelling never calls delete.
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 0);
      expect(deletedCalls, 0);

      // Confirming does, and the onDeleted callback fires afterward.
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 1);
      expect(deletedCalls, 1);
    });

    testWidgets('a failed delete shows an error and does not sign out',
        (tester) async {
      _useTallSurface(tester);
      final api = FakeProfileApi();
      // Wrap deleteAccount to fail without touching the recorded count.
      final failingApi = _FailingDeleteApi(api);
      var deletedCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileApiProvider.overrideWithValue(failingApi)],
          child: MaterialApp(
            home: Scaffold(
              body: AccountBody(
                initial: initial,
                signOut: () async {},
                onSignedOut: () {},
                onDeleted: () => deletedCalls++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not delete your account. Try again.'),
        findsOneWidget,
      );
      expect(deletedCalls, 0);
    });
  });
}

class _FailingDeleteApi implements ProfileApi {
  _FailingDeleteApi(this._inner);
  final FakeProfileApi _inner;

  @override
  Future<void> deleteAccount() async => throw Exception('boom');

  @override
  Future<ProfileUpdate?> fetchMyProfile() => _inner.fetchMyProfile();

  @override
  Future<ProfileUpdate> updateProfile({
    String? handle,
    String? school,
    int? avatarId,
  }) =>
      _inner.updateProfile(handle: handle, school: school, avatarId: avatarId);
}
