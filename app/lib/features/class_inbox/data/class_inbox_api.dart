// lib/features/class_inbox/data/class_inbox_api.dart
//
// Student class inbox, read-only. class_announcements is the record of
// every message a professor has sent to a class (see
// supabase/migrations/20260724000300_class_announcements.sql); the visible
// alert push is best-effort delivery, this table is the source of truth.
// RLS scopes rows to cohorts the caller is a member of, so no cohort filter
// needs enforcing client-side beyond asking for the student's own cohorts.

import 'package:supabase_flutter/supabase_flutter.dart';

/// One message a professor sent to a class.
class ClassAnnouncement {
  const ClassAnnouncement({
    required this.id,
    required this.cohortId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String cohortId;
  final String body;
  final DateTime createdAt;
}

/// One class's worth of announcements, newest first. Classes with no
/// announcements yet are left out of the inbox entirely (the screen shows
/// the empty state instead of an empty group).
class ClassInboxGroup {
  const ClassInboxGroup({
    required this.cohortId,
    required this.className,
    required this.messages,
    this.term,
  });

  final String cohortId;
  final String className;
  final String? term;

  /// Newest first.
  final List<ClassAnnouncement> messages;
}

/// A class the caller belongs to, for grouping announcements by name.
class ClassRef {
  const ClassRef({required this.id, required this.name, this.term});

  final String id;
  final String name;
  final String? term;
}

/// Groups [announcements] by cohort using [classes] for names, newest
/// message first within a group and groups ordered by their own newest
/// message. Pure; unit-tested. Classes with zero announcements are
/// dropped: the screen's empty state covers that case instead.
List<ClassInboxGroup> groupAnnouncements(
  List<ClassRef> classes,
  List<ClassAnnouncement> announcements,
) {
  final classById = {for (final c in classes) c.id: c};
  final byCohort = <String, List<ClassAnnouncement>>{};
  for (final a in announcements) {
    // Defensive: only group messages for a class the caller is known to
    // belong to (RLS already guarantees this server-side).
    if (!classById.containsKey(a.cohortId)) continue;
    byCohort.putIfAbsent(a.cohortId, () => []).add(a);
  }
  final groups = <ClassInboxGroup>[];
  for (final entry in byCohort.entries) {
    final ref = classById[entry.key]!;
    final messages = [...entry.value]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    groups.add(
      ClassInboxGroup(
        cohortId: ref.id,
        className: ref.name,
        term: ref.term,
        messages: messages,
      ),
    );
  }
  groups.sort(
    (a, b) => b.messages.first.createdAt.compareTo(a.messages.first.createdAt),
  );
  return groups;
}

/// A short "3h ago" / "2d ago" label for [when], relative to [now]
/// (defaults to the current time). Pure; unit-tested.
String formatRelativeTime(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.month}/${when.day}/${when.year}';
}

// ignore: one_member_abstracts
abstract class ClassInboxApi {
  /// Every announcement for the caller's classes, grouped and ordered per
  /// [groupAnnouncements]. Empty when signed out, unconfigured, or no
  /// class has sent a message yet.
  Future<List<ClassInboxGroup>> fetchInbox();
}

class SupabaseClassInboxApi implements ClassInboxApi {
  SupabaseClassInboxApi(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ClassInboxGroup>> fetchInbox() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    final memberRows = await _client
        .from('cohort_members')
        .select('cohort_id, cohorts(name, term)')
        .eq('user_id', uid);
    final seen = <String>{};
    final classes = <ClassRef>[];
    for (final r in memberRows) {
      final cohortId = r['cohort_id'] as String;
      // Defensive dedupe, matching SupabaseLeaderboardApi.myCohorts(): RLS
      // scopes cohort_members to every roster row the caller can see, not
      // just their own membership.
      if (!seen.add(cohortId)) continue;
      final cohort = r['cohorts'] as Map?;
      classes.add(
        ClassRef(
          id: cohortId,
          name: cohort?['name'] as String? ?? 'Class',
          term: cohort?['term'] as String?,
        ),
      );
    }
    if (classes.isEmpty) return const [];

    final annRows = await _client
        .from('class_announcements')
        .select('id, cohort_id, body, created_at')
        .inFilter('cohort_id', [for (final c in classes) c.id])
        .order('created_at', ascending: false)
        .limit(200);
    final announcements = [
      for (final r in annRows)
        ClassAnnouncement(
          id: r['id'] as String,
          cohortId: r['cohort_id'] as String,
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
    return groupAnnouncements(classes, announcements);
  }
}
