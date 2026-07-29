// lib/features/class_inbox/application/class_inbox_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/sync/supabase_config.dart';
import '../data/class_inbox_api.dart';

final classInboxApiProvider = Provider<ClassInboxApi?>(
  (ref) => SupabaseConfig.isConfigured
      ? SupabaseClassInboxApi(Supabase.instance.client)
      : null,
);

/// The signed-in student's class inbox, grouped by class. Empty when
/// unconfigured or no class has sent a message yet. [ClassInboxScreen]
/// gates the signed-out case before this is ever watched, mirroring
/// [ClassInboxApi.fetchInbox] itself returning empty for no session.
final classInboxProvider = FutureProvider<List<ClassInboxGroup>>((ref) async {
  final api = ref.watch(classInboxApiProvider);
  if (api == null) return const [];
  return api.fetchInbox();
});
