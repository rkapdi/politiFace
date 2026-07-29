// The signed-in class inbox body, rendered against a fake API (no network,
// no database): messages grouped by class, and the empty state when no
// class has sent anything yet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/class_inbox/application/class_inbox_providers.dart';
import 'package:politiface/features/class_inbox/data/class_inbox_api.dart';
import 'package:politiface/features/class_inbox/presentation/class_inbox_screen.dart';

class FakeClassInboxApi implements ClassInboxApi {
  FakeClassInboxApi(this.groups);

  final List<ClassInboxGroup> groups;

  @override
  Future<List<ClassInboxGroup>> fetchInbox() async => groups;
}

Widget _app(ClassInboxApi api) => ProviderScope(
      overrides: [classInboxApiProvider.overrideWithValue(api)],
      child: const MaterialApp(
        home: Scaffold(body: ClassInboxBody()),
      ),
    );

void main() {
  testWidgets('renders messages grouped by class, newest class first',
      (tester) async {
    final api = FakeClassInboxApi([
      ClassInboxGroup(
        cohortId: 'c2',
        className: 'AMH 2020',
        messages: [
          ClassAnnouncement(
            id: 'a2',
            cohortId: 'c2',
            body: 'Quiz moved to Friday',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      ClassInboxGroup(
        cohortId: 'c1',
        className: 'POS 2041',
        term: '2026F',
        messages: [
          ClassAnnouncement(
            id: 'a1',
            cohortId: 'c1',
            body: 'Bring your laptop Thursday',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(_app(api));
    await tester.pump();

    expect(find.text('AMH 2020'), findsOneWidget);
    expect(find.text('POS 2041 · 2026F'), findsOneWidget);
    expect(find.text('Quiz moved to Friday'), findsOneWidget);
    expect(find.text('Bring your laptop Thursday'), findsOneWidget);

    // AMH 2020's group (newest message) renders above POS 2041's.
    final amhOffset = tester.getTopLeft(find.text('AMH 2020')).dy;
    final posOffset = tester.getTopLeft(find.text('POS 2041 · 2026F')).dy;
    expect(amhOffset, lessThan(posOffset));
  });

  testWidgets('shows the empty state when no class has sent a message',
      (tester) async {
    final api = FakeClassInboxApi(const []);

    await tester.pumpWidget(_app(api));
    await tester.pump();

    expect(
      find.text(
        'No messages yet. Your professor can send reminders here.',
      ),
      findsOneWidget,
    );
  });
}
