// Regression test for the TestFlight-reported bug where the email/code
// field in the sign-in bottom sheet was hidden behind the keyboard: the
// sheet's fixed Column plus a bottom-inset Padding wasn't enough on
// smaller screens once the keyboard's viewInsets ate into the available
// height. Pumps the sheet at a constrained, keyboard-shrunk viewport and
// asserts the autofocused field is actually laid out on-screen and
// hittable, not just present in the tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/sync/auth_service.dart';
import 'package:politiface/core/sync/sign_in_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _app(AuthService auth) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showSignInSheet(context, auth),
              child: const Text('Sign in'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'email field stays visible and hittable on a keyboard-shrunk viewport',
      (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    final originalInsets = tester.view.viewInsets;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
      tester.view.viewInsets = originalInsets;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    // Small surface (e.g. an SE-class phone) to simulate the smaller
    // screens the report came from.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 500);

    final auth = AuthService(
      SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        // No auto-refresh timer: this sheet is only ever pumped to check
        // layout, never signed in for real, and the pending periodic
        // timer would otherwise trip the test binding's cleanup check.
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

    await tester.pumpWidget(_app(auth));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Now bring up the "keyboard": shrink the remaining visible space the
    // way the OS does when the field is focused and the keyboard shows.
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final fieldFinder = find.widgetWithText(TextField, 'Email').first;
    expect(fieldFinder, findsOneWidget);

    // Laid out with non-zero size and positioned within the (keyboard
    // shrunk) visible viewport, not pushed off past its bottom edge.
    final size = tester.getSize(fieldFinder);
    final topLeft = tester.getTopLeft(fieldFinder);
    expect(size.height, greaterThan(0));
    const visibleBottom = 500 - 260; // physical size minus keyboard inset
    expect(topLeft.dy + size.height, lessThanOrEqualTo(visibleBottom));

    // And actually hittable, not just laid out off-tree.
    await tester.tap(fieldFinder);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
