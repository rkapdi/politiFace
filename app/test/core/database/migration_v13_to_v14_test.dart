// Migration test: v13 -> v14 (deck subscription flag + category).
//
// The top acceptance criterion for the delegation-deck feature: existing
// users' curated decks stay subscribed and nothing they had in rotation
// disappears. The fixture seeds a REAL v13 database (DDL captured from the
// pre-v14 table definitions) with decks, cards, and in-flight FSRS state,
// then opens it with the current AppDatabase and asserts the new columns
// land with the safe defaults while every user row survives.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// v13 DDL for the tables this migration and test touch. local_decks is the
// pre-v14 definition: no is_subscribed, no category.
const _v13Ddl = '''
CREATE TABLE "local_decks" ("id" TEXT NOT NULL, "node_id" TEXT NULL, "government_id" TEXT NULL, "external_id" TEXT NOT NULL UNIQUE, "name" TEXT NOT NULL, "description" TEXT NULL, "tier_order" INTEGER NOT NULL DEFAULT 0, "is_premium" INTEGER NOT NULL DEFAULT 0 CHECK ("is_premium" IN (0, 1)), "status" TEXT NOT NULL DEFAULT 'published', "card_count" INTEGER NOT NULL DEFAULT 0, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "local_cards" ("id" TEXT NOT NULL, "deck_id" TEXT NOT NULL, "external_id" TEXT NOT NULL UNIQUE, "politician_name" TEXT NOT NULL, "photo_url" TEXT NULL, "lqip_base64" TEXT NULL, "title" TEXT NOT NULL, "party" TEXT NULL, "jurisdiction" TEXT NULL, "one_liner" TEXT NULL, "source_url" TEXT NOT NULL, "gender" TEXT NULL, "card_type" TEXT NOT NULL DEFAULT 'face', "body" TEXT NULL, "recall_prompt" TEXT NULL, "tags" TEXT NOT NULL DEFAULT '[]', "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "card_memory_states" ("card_id" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "difficulty" REAL NOT NULL DEFAULT 5.0, "stability" REAL NOT NULL DEFAULT 1.0, "retrievability" REAL NOT NULL DEFAULT 1.0, "last_reviewed_at" INTEGER NOT NULL DEFAULT 0, "next_review_at" INTEGER NOT NULL DEFAULT 0, "interval_days" INTEGER NOT NULL DEFAULT 1, "lapses" INTEGER NOT NULL DEFAULT 0, "review_count" INTEGER NOT NULL DEFAULT 0, "is_new" INTEGER NOT NULL DEFAULT 1 CHECK ("is_new" IN (0, 1)), "practice_count_since_review" INTEGER NOT NULL DEFAULT 0, "last_grade" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("card_id"));
CREATE TABLE "review_logs" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL DEFAULT 'local-user', "card_id" TEXT NOT NULL, "reviewed_at" INTEGER NOT NULL, "grade" INTEGER NOT NULL, "stability" REAL NOT NULL, "difficulty" REAL NOT NULL, "retrievability" REAL NOT NULL, "interval_days" INTEGER NOT NULL, "synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)));
CREATE TABLE "app_meta" ("key" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "value" TEXT NOT NULL, PRIMARY KEY ("key"));
''';

void main() {
  late Directory tmpDir;
  late File dbFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('politiface_migration_v14_');
    dbFile = File('${tmpDir.path}/v13.db');

    final raw = sqlite.sqlite3.open(dbFile.path);
    for (final stmt in _v13Ddl.split(';\n')) {
      if (stmt.trim().isEmpty) continue;
      raw.execute(stmt);
    }
    raw.execute('PRAGMA user_version = 13');

    // Two curated decks with cards in rotation, exactly what an existing
    // install carries.
    raw.execute('''
      INSERT INTO local_decks (id, external_id, name, tier_order, card_count, updated_at)
      VALUES ('deck_us-executive', 'us-executive', 'The Executive', 1, 2, 1717000000)
    ''');
    raw.execute('''
      INSERT INTO local_decks (id, external_id, name, tier_order, card_count, updated_at)
      VALUES ('deck_us-senate', 'us-senate', 'The Senate', 2, 1, 1717000000)
    ''');
    raw.execute('''
      INSERT INTO local_cards (id, deck_id, external_id, politician_name, title, source_url, updated_at)
      VALUES ('card-1', 'deck_us-executive', 'card-1', 'Jane Doe', 'President', 'about:blank', 1717000000)
    ''');
    // Card mid-learning: due in the past, so it must stay in rotation.
    raw.execute('''
      INSERT INTO card_memory_states
        (card_id, difficulty, stability, retrievability, last_reviewed_at,
         next_review_at, interval_days, lapses, review_count, is_new)
      VALUES ('card-1', 4.2, 18.5, 0.93, 1717000000, 1717086400, 19, 1, 12, 0)
    ''');
    raw.execute('''
      INSERT INTO review_logs
        (card_id, reviewed_at, grade, stability, difficulty, retrievability, interval_days)
      VALUES ('card-1', 1717000000, 2, 18.5, 4.2, 0.93, 19)
    ''');
    raw.execute(
      "INSERT INTO app_meta (key, value) VALUES ('profile.streak_count', '9')",
    );
    raw.dispose();
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  test('v13 -> v14 keeps every deck subscribed and categorized curated',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final decks = await db.decksDao.allDecks();
    expect(decks, hasLength(2));
    for (final deck in decks) {
      expect(
        deck.isSubscribed,
        isTrue,
        reason: 'existing curated decks must stay in rotation',
      );
      expect(deck.category, 'curated');
    }

    // The mid-learning card is still in the global due pool: nothing an
    // existing user had in rotation disappears.
    final due = await db.reviewsDao.dueAtSubscribed(1718600000);
    expect(due.map((s) => s.cardId), contains('card-1'));

    // FSRS state and logs survive bit-for-bit.
    final memory = await db.reviewsDao.stateFor('card-1');
    expect(memory, isNotNull);
    expect(memory!.stability, 18.5);
    expect(memory.reviewCount, 12);
    final logs = await db.reviewsDao.logsForCard('card-1');
    expect(logs, hasLength(1));
    expect(await db.metaDao.get('profile.streak_count'), '9');

    // Schema is at v14 with the two new columns present.
    final version = (await db.customSelect('PRAGMA user_version').get())
        .single
        .read<int>('user_version');
    expect(version, 14);
    final deckCols =
        (await db.customSelect('PRAGMA table_info(local_decks)').get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(deckCols, containsAll(['is_subscribed', 'category']));
  });
}
