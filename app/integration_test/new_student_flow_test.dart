// End-to-end walk of a brand-new student on a simulator, against the real
// backend (run with the SUPABASE_URL / SUPABASE_ANON_KEY dart-defines):
// first-launch diagnostic (5 questions, no skip), score, required account
// step, plan, Home's "Joining a class?" row, and joining a class by code.
//
// Driven from the host: the test prints `QA_SHOT <name>` at each screen
// (a host watcher screenshots the simulator), and at the code step prints
// `QA_NEED_CODE` and waits for the emailed code in QA_OTP_FILE.
//
//   flutter test integration_test/new_student_flow_test.dart -d <sim> \
//     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... \
//     --dart-define=QA_EMAIL=you+sim1@example.com \
//     --dart-define=QA_CLASS_CODE=ABC123

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:politiface/main.dart' as app;

const _email = String.fromEnvironment('QA_EMAIL');
const _classCode = String.fromEnvironment('QA_CLASS_CODE');
const _otpFile = String.fromEnvironment(
  'QA_OTP_FILE',
  defaultValue: '/private/tmp/politiface_otp.txt',
);

Future<void> settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  // ignore: avoid_print
  print('QA_SHOT $name');
  await Future<void>.delayed(const Duration(seconds: 3));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'no "$text" on screen');
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new student: diagnostic, account, plan, join a class',
      (tester) async {
    expect(_email, isNotEmpty, reason: 'pass --dart-define=QA_EMAIL');
    await app.main();
    await settle(tester, 40);
    await shot(tester, '01_invite');
    expect(find.text('SKIP'), findsNothing);

    await tapText(tester, 'START THE DIAGNOSTIC');
    for (var i = 0; i < 5; i++) {
      await shot(tester, '02_question_${i + 1}');
      await tester.tap(find.byKey(const Key('diag-opt-0')));
      await settle(tester);
      expect(find.text('SKIP'), findsNothing);
      await tapText(tester, i == 4 ? 'SEE YOUR RESULT' : 'NEXT');
    }

    await shot(tester, '03_score');
    expect(find.text('START STUDYING'), findsNothing);
    await tapText(tester, 'CREATE YOUR ACCOUNT');
    await shot(tester, '04_account_email');

    await tester.enterText(find.byType(TextField).first, _email);
    await tapText(tester, 'SEND CODE');
    await settle(tester, 30);
    await shot(tester, '05_account_code');
    expect(find.text('USE A DIFFERENT EMAIL'), findsOneWidget);

    // ignore: avoid_print
    print('QA_NEED_CODE $_email');
    final file = File(_otpFile);
    String? code;
    for (var i = 0; i < 600 && code == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (file.existsSync()) {
        final v = file.readAsStringSync().trim();
        if (RegExp(r'^\d{6}$').hasMatch(v)) code = v;
      }
    }
    expect(code, isNotNull, reason: 'no code in $_otpFile within 10 minutes');
    await tester.enterText(find.byType(TextField).first, code!);
    await tapText(tester, 'VERIFY');
    await settle(tester, 60);
    await shot(tester, '06_plan_after_signup');
    expect(find.text('START STUDYING'), findsOneWidget);

    await tapText(tester, 'START STUDYING');
    await settle(tester, 40);
    await shot(tester, '07_home');
    // The first-landing guided tour sits on top of Home; close it.
    if (find.text('SKIP').evaluate().isNotEmpty) {
      await tapText(tester, 'SKIP');
      await settle(tester, 20);
      await shot(tester, '07c_home_after_tour');
    }

    final joinRow = find.textContaining('Joining a class?');
    if (joinRow.evaluate().isEmpty) {
      // A first-landing overlay (guided tour) may sit on top; record it.
      await shot(tester, '07b_home_overlay');
      return;
    }
    await tester.ensureVisible(joinRow.first);
    await tester.tap(joinRow.first);
    await settle(tester, 30);
    await shot(tester, '08_join_class_screen');

    if (_classCode.isEmpty) return;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Sim Student');
    await tester.enterText(fields.at(1), _classCode);
    await tapText(tester, 'JOIN CLASS');
    await settle(tester, 60);
    await shot(tester, '09_joined_class');
  });
}
