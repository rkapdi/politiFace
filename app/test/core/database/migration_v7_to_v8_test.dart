// Migration test: v7 → current (v8 rename/drop, v9 concept-card columns).
//
// v8 does two things:
//   1. Renames sync_meta → app_meta (the app's key-value store: streak, XP,
//      settings, seed flags, pending-session snapshot). Every row must survive.
//   2. Drops the legacy daily_challenge_caches table, which shipped TestFlight
//      builds may have populated.
//
// The fixture below seeds a REAL v7 database: the DDL is the verbatim
// sqlite_master dump of schema v7 (captured before the v8 change landed),
// not a hand-approximation. We then open it with the current AppDatabase and
// assert that all user data — FSRS memory state, review logs, streak/XP meta,
// chapter progress, daily rounds, completed runs, node progress — survives.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Verbatim v7 DDL (sqlite_master dump of a freshly created v7 database).
const _v7Ddl = '''
CREATE TABLE "card_memory_states" ("card_id" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "difficulty" REAL NOT NULL DEFAULT 5.0, "stability" REAL NOT NULL DEFAULT 1.0, "retrievability" REAL NOT NULL DEFAULT 1.0, "last_reviewed_at" INTEGER NOT NULL DEFAULT 0, "next_review_at" INTEGER NOT NULL DEFAULT 0, "interval_days" INTEGER NOT NULL DEFAULT 1, "lapses" INTEGER NOT NULL DEFAULT 0, "review_count" INTEGER NOT NULL DEFAULT 0, "is_new" INTEGER NOT NULL DEFAULT 1 CHECK ("is_new" IN (0, 1)), "practice_count_since_review" INTEGER NOT NULL DEFAULT 0, "last_grade" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("card_id"));
CREATE TABLE "chapter_progress" ("user_id" TEXT NOT NULL DEFAULT 'local-user', "season_id" TEXT NOT NULL, "chapter_id" TEXT NOT NULL, "day_in_chapter" INTEGER NOT NULL DEFAULT 1, "rounds_completed" INTEGER NOT NULL DEFAULT 0, "started_at" INTEGER NOT NULL, "completed_at" INTEGER NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("user_id", "season_id", "chapter_id"));
CREATE TABLE "completed_runs" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "mode" TEXT NOT NULL, "completed_at" INTEGER NOT NULL, "duration_ms" INTEGER NULL, "score" INTEGER NULL, "correct_count" INTEGER NULL, "total_count" INTEGER NULL, "summary" TEXT NULL, "payload" TEXT NOT NULL DEFAULT '{}', PRIMARY KEY ("id"));
CREATE TABLE "daily_challenge_caches" ("challenge_date" TEXT NOT NULL, "card_ids" TEXT NOT NULL, "share_template" TEXT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("challenge_date"));
CREATE TABLE "daily_rounds" ("user_id" TEXT NOT NULL DEFAULT 'local-user', "date_iso" TEXT NOT NULL, "chapter_id" TEXT NOT NULL, "day_in_chapter" INTEGER NOT NULL, "card_ids_json" TEXT NOT NULL DEFAULT '[]', "trivia_json" TEXT NOT NULL DEFAULT '[]', "grades_json" TEXT NOT NULL DEFAULT '[]', "answers_json" TEXT NOT NULL DEFAULT '[]', "phase" TEXT NOT NULL DEFAULT 'cards', "started_at" INTEGER NOT NULL, "completed_at" INTEGER NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("user_id", "date_iso"));
CREATE TABLE "gov_edges" ("id" TEXT NOT NULL, "government_id" TEXT NOT NULL, "from_node_id" TEXT NOT NULL, "to_node_id" TEXT NOT NULL, "relationship_type" TEXT NOT NULL, "description" TEXT NULL, "is_visible_on_map" INTEGER NOT NULL DEFAULT 1 CHECK ("is_visible_on_map" IN (0, 1)), "line_style" TEXT NOT NULL DEFAULT 'solid', "line_color" TEXT NULL, "arrow_direction" TEXT NOT NULL DEFAULT 'to', PRIMARY KEY ("id"));
CREATE TABLE "gov_nodes" ("id" TEXT NOT NULL, "government_id" TEXT NOT NULL, "external_id" TEXT NOT NULL UNIQUE, "name" TEXT NOT NULL, "short_name" TEXT NULL, "description" TEXT NULL, "node_type" TEXT NOT NULL, "is_head_of_state" INTEGER NOT NULL DEFAULT 0 CHECK ("is_head_of_state" IN (0, 1)), "is_head_of_govt" INTEGER NOT NULL DEFAULT 0 CHECK ("is_head_of_govt" IN (0, 1)), "is_elected" INTEGER NULL CHECK ("is_elected" IN (0, 1)), "map_x" REAL NULL, "map_y" REAL NULL, "map_width" REAL NULL, "map_height" REAL NULL, "map_shape" TEXT NOT NULL DEFAULT 'rectangle', "map_icon" TEXT NULL, "map_color" TEXT NULL, "map_label_pos" TEXT NOT NULL DEFAULT 'bottom', "tier_order" INTEGER NOT NULL, "unlock_requires" TEXT NOT NULL DEFAULT '[]', "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"));
CREATE TABLE "local_cards" ("id" TEXT NOT NULL, "deck_id" TEXT NOT NULL, "external_id" TEXT NOT NULL UNIQUE, "politician_name" TEXT NOT NULL, "photo_url" TEXT NULL, "lqip_base64" TEXT NULL, "title" TEXT NOT NULL, "party" TEXT NULL, "jurisdiction" TEXT NULL, "one_liner" TEXT NULL, "source_url" TEXT NOT NULL, "gender" TEXT NULL, "tags" TEXT NOT NULL DEFAULT '[]', "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "local_decks" ("id" TEXT NOT NULL, "node_id" TEXT NULL, "government_id" TEXT NULL, "external_id" TEXT NOT NULL UNIQUE, "name" TEXT NOT NULL, "description" TEXT NULL, "tier_order" INTEGER NOT NULL DEFAULT 0, "is_premium" INTEGER NOT NULL DEFAULT 0 CHECK ("is_premium" IN (0, 1)), "status" TEXT NOT NULL DEFAULT 'published', "card_count" INTEGER NOT NULL DEFAULT 0, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "politician_bios" ("card_id" TEXT NOT NULL, "wikidata_qid" TEXT NULL, "wikipedia_title" TEXT NULL, "wikipedia_url" TEXT NULL, "bio_extract" TEXT NULL, "fetched_at" INTEGER NULL, "last_error" INTEGER NULL, "last_error_message" TEXT NULL, PRIMARY KEY ("card_id"));
CREATE TABLE "review_logs" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL DEFAULT 'local-user', "card_id" TEXT NOT NULL, "reviewed_at" INTEGER NOT NULL, "grade" INTEGER NOT NULL, "stability" REAL NOT NULL, "difficulty" REAL NOT NULL, "retrievability" REAL NOT NULL, "interval_days" INTEGER NOT NULL, "synced" INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)));
CREATE TABLE "sync_meta" ("key" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "value" TEXT NOT NULL, PRIMARY KEY ("key"));
CREATE TABLE "user_node_progress" ("node_id" TEXT NOT NULL, "user_id" TEXT NOT NULL DEFAULT 'local-user', "government_id" TEXT NOT NULL, "status" TEXT NOT NULL DEFAULT 'locked', "unlocked_at" INTEGER NULL, "completed_at" INTEGER NULL, PRIMARY KEY ("node_id"));
''';

void main() {
  late Directory tmpDir;
  late File dbFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('politiface_migration_');
    dbFile = File('${tmpDir.path}/v7.db');

    // Seed a populated v7 database with raw sqlite — exactly what a
    // TestFlight install upgrading to this build would carry.
    final raw = sqlite.sqlite3.open(dbFile.path);
    for (final stmt in _v7Ddl.split(';\n')) {
      if (stmt.trim().isEmpty) continue;
      raw.execute(stmt);
    }
    raw.execute('PRAGMA user_version = 7');

    // FSRS memory state mid-flight: a well-learned card with real values.
    raw.execute('''
      INSERT INTO card_memory_states
        (card_id, difficulty, stability, retrievability, last_reviewed_at,
         next_review_at, interval_days, lapses, review_count, is_new,
         practice_count_since_review, last_grade)
      VALUES ('card-1', 4.2, 18.5, 0.93, 1717000000, 1718600000, 19, 1, 12, 0,
              3, 2)
    ''');
    raw.execute('''
      INSERT INTO review_logs
        (card_id, reviewed_at, grade, stability, difficulty, retrievability,
         interval_days)
      VALUES ('card-1', 1717000000, 2, 18.5, 4.2, 0.93, 19)
    ''');
    // Streak / XP / settings / seed flags — all live in sync_meta on v7.
    raw.execute(
        "INSERT INTO sync_meta (key, value) VALUES ('profile.streak_count', '42')",);
    raw.execute(
        "INSERT INTO sync_meta (key, value) VALUES ('profile.streak_last_review_date', '2026-06-10')",);
    raw.execute(
        "INSERT INTO sync_meta (key, value) VALUES ('profile.xp_total', '1337')",);
    raw.execute(
        "INSERT INTO sync_meta (key, value) VALUES ('yaml_seed_v3_done', '1')",);
    raw.execute(
        "INSERT INTO sync_meta (key, value) VALUES ('settings.theme_mode', 'dark')",);
    raw.execute('''
      INSERT INTO chapter_progress
        (season_id, chapter_id, day_in_chapter, rounds_completed, started_at,
         updated_at)
      VALUES ('us-civics', 'chapter-3', 4, 3, 1716000000, 1717000000)
    ''');
    raw.execute('''
      INSERT INTO completed_runs
        (id, mode, completed_at, score, correct_count, total_count, payload)
      VALUES ('run-1', 'trivia', 1717000000, 8, 8, 10, '{"answers":[1,2]}')
    ''');
    raw.execute('''
      INSERT INTO daily_rounds
        (date_iso, chapter_id, day_in_chapter, phase, started_at, updated_at)
      VALUES ('2026-06-10', 'chapter-3', 4, 'done', 1717000000, 1717000500)
    ''');
    raw.execute('''
      INSERT INTO user_node_progress (node_id, government_id, status, unlocked_at)
      VALUES ('us-node-senate', 'us-government', 'unlocked', 1716000000)
    ''');
    // Populated legacy daily-challenge row — the table being dropped.
    raw.execute('''
      INSERT INTO daily_challenge_caches
        (challenge_date, card_ids, share_template, cached_at)
      VALUES ('2026-06-01', '["card-1"]', '{"grades":[2,2,3,2,2]}', 1717000000)
    ''');
    raw.dispose();
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  test('v7 → v8 preserves all user data and applies the schema change',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // Force the database open (and therefore the migration) with a real query.
    final memory = await db.select(db.cardMemoryStates).get();

    // ── FSRS memory state survives bit-for-bit ──────────────────────────
    expect(memory, hasLength(1));
    final card = memory.single;
    expect(card.cardId, 'card-1');
    expect(card.difficulty, 4.2);
    expect(card.stability, 18.5);
    expect(card.retrievability, 0.93);
    expect(card.nextReviewAt, 1718600000);
    expect(card.intervalDays, 19);
    expect(card.lapses, 1);
    expect(card.reviewCount, 12);
    expect(card.isNew, false);
    expect(card.practiceCountSinceReview, 3);
    expect(card.lastGrade, 2);

    // ── Review log survives ─────────────────────────────────────────────
    final logs = await db.select(db.reviewLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.cardId, 'card-1');
    expect(logs.single.grade, 2);

    // ── Streak / XP / settings / seed flags survive the table rename ───
    expect(await db.metaDao.get('profile.streak_count'), '42');
    expect(
        await db.metaDao.get('profile.streak_last_review_date'), '2026-06-10',);
    expect(await db.metaDao.get('profile.xp_total'), '1337');
    expect(await db.metaDao.get('yaml_seed_v3_done'), '1');
    expect(await db.metaDao.get('settings.theme_mode'), 'dark');

    // ── Chapter progress, history, node progress survive ────────────────
    final chapters = await db.select(db.chapterProgress).get();
    expect(chapters.single.chapterId, 'chapter-3');
    expect(chapters.single.dayInChapter, 4);

    final runs = await db.select(db.completedRuns).get();
    expect(runs.single.id, 'run-1');
    expect(runs.single.score, 8);

    final rounds = await db.select(db.dailyRounds).get();
    expect(rounds.single.dateIso, '2026-06-10');
    expect(rounds.single.phase, 'done');

    final nodes = await db.select(db.userNodeProgress).get();
    expect(nodes.single.status, 'unlocked');

    // ── Schema change applied ───────────────────────────────────────────
    final tables = (await db
            .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",)
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(tables, contains('app_meta'));
    expect(tables, isNot(contains('sync_meta')));
    expect(tables, isNot(contains('daily_challenge_caches')));

    final version = (await db.customSelect('PRAGMA user_version').get())
        .single
        .read<int>('user_version');
    expect(version, 9);

    // v9 concept-card columns exist with safe defaults on migrated rows.
    final cardCols = (await db
            .customSelect('PRAGMA table_info(local_cards)')
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(cardCols, containsAll(['card_type', 'body', 'recall_prompt']));
  });

  test('fresh install (onCreate) gets the v8 schema directly', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.metaDao.set('probe', '1');
    expect(await db.metaDao.get('probe'), '1');

    final tables = (await db
            .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",)
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(tables, contains('app_meta'));
    expect(tables, isNot(contains('sync_meta')));
    expect(tables, isNot(contains('daily_challenge_caches')));
  });
}
