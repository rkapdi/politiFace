import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/ops/ops_log.dart';
import 'package:politiface/core/sync/auth_service.dart';
import 'package:politiface/core/sync/sign_in_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RateLimitedAuth extends AuthService {
  _RateLimitedAuth()
      : super(
          SupabaseClient(
            'http://localhost',
            'test-key',
            // No auto-refresh timer: this sheet is only pumped to trigger
            // the failure path, never signed in for real, and the pending
            // periodic timer would otherwise trip the test binding's
            // cleanup check (see sign_in_sheet_test.dart).
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<void> requestOtp(String email) async =>
      throw const AuthException('rate limit', statusCode: '429');
}

void main() {
  late List<Map<String, dynamic>> sent;
  setUp(() {
    sent = [];
    OpsLog.sinkOverride = (p) async => sent.add(p);
  });
  tearDown(() => OpsLog.sinkOverride = null);

  test('report sends kind, client ios, and details', () async {
    await OpsLog.report('join_refused', code: 'invalid or ended session code');
    expect(sent.single['p_kind'], 'join_refused');
    expect(sent.single['p_client'], 'ios');
    expect(sent.single['p_code'], 'invalid or ended session code');
  });

  test('report never throws when sending fails', () async {
    OpsLog.sinkOverride = (_) async => throw Exception('offline');
    await OpsLog.report('client_error', code: 'x');
  });

  testWidgets('a failed code send reports signin_send_failed with the email',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignInSheet(auth: _RateLimitedAuth()))),
    );
    await tester.enterText(find.byType(TextField), 'Maria@MyMDC.net');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(sent.single['p_kind'], 'signin_send_failed');
    expect(sent.single['p_code'], '429');
    expect(sent.single['p_email'], 'Maria@MyMDC.net');
  });
}
