// lib/features/fcle/data/locked_questions_service.dart
//
// The caller's held-out question ids (server UUIDs), fetched from the
// locked_question_ids RPC and cached in AppMeta so every practice surface
// can filter synchronously-ish and offline. Fail-soft in both directions:
// an unreachable server returns the cache, an empty cache returns empty.
//
// Freshness note: this deliberately does NOT ride the RestoreService
// 6-hour pull throttle. A check closing should unlock its items within
// minutes, so the cache is considered stale after 15 minutes and refetched
// on the next read (practice entry, mock entry, diagnostic).

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/drift/app_database.dart';

class LockedQuestionsService {
  LockedQuestionsService({
    required AppDatabase db,
    required bool active,
    Future<List<dynamic>> Function()? fetch,
    DateTime Function()? now,
  })  : _db = db,
        _active = active,
        _fetch = fetch ??
            (() async => await Supabase.instance.client
                .rpc<dynamic>('locked_question_ids') as List<dynamic>),
        _now = now ?? DateTime.now;

  final AppDatabase _db;

  /// Whether a backend is configured and a user is signed in (mirrors
  /// SyncEngine.isActive). When false, no fetch is attempted: a signed-out
  /// user has no cohort and therefore no locks beyond a stale cache, which
  /// over-blocks harmlessly until wipe or sign-in refresh.
  final bool _active;
  final Future<List<dynamic>> Function() _fetch;
  final DateTime Function() _now;

  /// AppMeta key. Also listed in wipeLocalUserState (restore_service.dart)
  /// so one account's locks never constrain the next.
  static const metaKey = 'fcle.locked_qids';
  static const staleness = Duration(minutes: 15);

  /// The current locked set (server UUIDs). Never throws.
  Future<Set<String>> current() async {
    final cached = await _readCache();
    final fresh = cached != null &&
        _now().difference(cached.at) < staleness;
    if (!_active || fresh) return cached?.ids ?? const <String>{};
    try {
      final ids = <String>{
        for (final id in await _fetch())
          if (id is String) id,
      };
      await _db.metaDao.set(
        metaKey,
        jsonEncode({
          'at': _now().millisecondsSinceEpoch,
          'ids': ids.toList(),
        }),
      );
      return ids;
    } catch (_) {
      return cached?.ids ?? const <String>{};
    }
  }

  Future<({DateTime at, Set<String> ids})?> _readCache() async {
    final raw = await _db.metaDao.get(metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        at: DateTime.fromMillisecondsSinceEpoch(map['at'] as int),
        ids: {
          for (final id in map['ids'] as List<dynamic>)
            if (id is String) id,
        },
      );
    } catch (_) {
      return null;
    }
  }
}
