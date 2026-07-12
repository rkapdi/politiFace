// lib/features/fcle/application/mock_session_provider.dart
//
// Chooses where a Mock FCLE lives. Signed in with a backend: the server
// assembles the attempt (mock_attempts is the efficacy instrument; the
// first completed mock is the baseline). Anything fails or the user is
// offline/signed out: a local mock from the bundled bank, always available.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../app/providers.dart';
import '../data/server_mock_api.dart';
import '../data/server_mock_session.dart';
import '../domain/mock_engine.dart';
import '../domain/mock_session.dart';
import '../domain/server_ids.dart';
import 'fcle_providers.dart';

/// AppMeta key counting locally completed mocks; 0 -> next server mock is
/// the cohort baseline, afterwards 'practice'. ('final' stays reserved for
/// educator-timed end-of-term mocks.)
const kCompletedMocksMetaKey = 'fcle.completed_mocks';

final mockSessionProvider = FutureProvider.autoDispose<MockSession>(
  (ref) async {
    final bank = await ref.watch(questionBankProvider.future);
    final db = ref.watch(databaseProvider);
    final sync = ref.watch(syncEngineProvider);
    void tick() => ref.read(fcleTickProvider.notifier).state++;

    if (sync.isActive) {
      try {
        final completed =
            int.tryParse(await db.metaDao.get(kCompletedMocksMetaKey) ?? '0') ??
                0;
        return await ServerMockSession.start(
          kind: completed == 0 ? 'baseline' : 'practice',
          bank: bank,
          api: SupabaseMockApi(Supabase.instance.client),
          dao: db.fcleAnswersDao,
          sync: sync,
          onAnswerRecorded: tick,
        );
      } catch (_) {
        // Server unreachable or bank not ingested yet: local is fine.
      }
    }

    return LocalMockSession(
      assembly: const MockEngine().assemble(bank),
      dao: db.fcleAnswersDao,
      enqueueAnswer: ({required serverQuestionId, required chosenKey}) =>
          sync.enqueueAnswer(
        questionId: serverQuestionId,
        chosenKey: chosenKey,
      ),
      onAnswerRecorded: tick,
      serverIdOf: serverUuidForQuestion,
    );
  },
);
