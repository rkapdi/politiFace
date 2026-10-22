import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/class_inbox/data/class_inbox_api.dart';

void main() {
  group('groupAnnouncements', () {
    final classes = [
      const ClassRef(id: 'c1', name: 'POS 2041', term: '2026F'),
      const ClassRef(id: 'c2', name: 'AMH 2020'),
    ];

    test('groups by cohort, newest message first within a class', () {
      final groups = groupAnnouncements(classes, [
        ClassAnnouncement(
          id: 'a1',
          cohortId: 'c1',
          body: 'older',
          createdAt: DateTime(2026, 7),
        ),
        ClassAnnouncement(
          id: 'a2',
          cohortId: 'c1',
          body: 'newer',
          createdAt: DateTime(2026, 7, 10),
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.cohortId, 'c1');
      expect(groups.single.className, 'POS 2041');
      expect(groups.single.term, '2026F');
      expect(
        groups.single.messages.map((m) => m.body).toList(),
        ['newer', 'older'],
      );
    });

    test('groups are ordered by their own newest message, newest first', () {
      final groups = groupAnnouncements(classes, [
        ClassAnnouncement(
          id: 'a1',
          cohortId: 'c1',
          body: 'c1 message',
          createdAt: DateTime(2026, 7),
        ),
        ClassAnnouncement(
          id: 'a2',
          cohortId: 'c2',
          body: 'c2 message',
          createdAt: DateTime(2026, 7, 15),
        ),
      ]);

      expect(groups.map((g) => g.cohortId).toList(), ['c2', 'c1']);
    });

    test('a class with no announcements is left out of the groups', () {
      final groups = groupAnnouncements(classes, [
        ClassAnnouncement(
          id: 'a1',
          cohortId: 'c1',
          body: 'only c1 has spoken',
          createdAt: DateTime(2026, 7),
        ),
      ]);

      expect(groups.map((g) => g.cohortId).toList(), ['c1']);
    });

    test('no announcements at all yields an empty list (the empty state)', () {
      expect(groupAnnouncements(classes, const []), isEmpty);
    });

    test(
        'a message for a cohort the caller is not known to belong to is '
        'dropped defensively', () {
      final groups = groupAnnouncements(classes, [
        ClassAnnouncement(
          id: 'a1',
          cohortId: 'stranger-cohort',
          body: 'should not appear',
          createdAt: DateTime(2026, 7),
        ),
      ]);
      expect(groups, isEmpty);
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 7, 23, 12);

    test('under a minute reads "just now"', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'just now',
      );
    });

    test('minutes and hours read as short labels', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });

    test('days under a week read as "Nd ago"; a week or more is a date', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
      final aWeekAgo = now.subtract(const Duration(days: 8));
      expect(
        formatRelativeTime(aWeekAgo, now: now),
        '${aWeekAgo.month}/${aWeekAgo.day}/${aWeekAgo.year}',
      );
    });
  });
}
