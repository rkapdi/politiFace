// lib/features/session/data/delegation_deck_service.dart
//
// Generates one "delegation" deck per state from the People table (which
// PeopleSeedService keeps current from bundled legislators.yaml). Card id
// equals the person's bioguide id, so FSRS memory state survives weekly
// roster refreshes and even chamber or state switches. Decks are seeded
// UNSUBSCRIBED: they never enter the global rotation until the user opts
// in, and a re-seed never touches the subscription flag.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../core/content/content_checksum.dart';
import '../../../core/content/us_states.dart';
import '../../../core/database/drift/app_database.dart';

class DelegationDeckService {
  DelegationDeckService(this._db, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AppDatabase _db;
  final AssetBundle _bundle;

  static const _hashKey = 'seed.delegations.hash';
  static const _generatorVersion = 'v1';
  static const _asset = 'assets/content/people/legislators.yaml';

  /// Must run AFTER PeopleSeedService.ensureSeeded so the people table
  /// reflects the bundled roster this hash was computed from.
  Future<void> ensureSeeded() async {
    final raw = await _bundle.loadString(_asset);
    final hash = '$_generatorVersion|${contentChecksum({_asset: raw})}';
    if (await _db.metaDao.get(_hashKey) == hash) return;

    final people = await _db.select(_db.people).get();
    final byState = <String, List<Person>>{};
    for (final p in people) {
      final state = p.state;
      if (state == null || p.personType != 'legislator') continue;
      byState.putIfAbsent(state, () => []).add(p);
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rosterIds = <String>{};

    await _db.transaction(() async {
      for (final st in byState.keys.toList()..sort()) {
        final members = byState[st]!;
        final deckId = 'deck_delegation-${st.toLowerCase()}';
        final externalId = 'delegation-${st.toLowerCase()}';
        final stateName = usStateName(st);
        final name = '$stateName Delegation';
        final description =
            'The senators and representatives currently serving $stateName.';

        final existing = await _db.decksDao.deckById(deckId);
        if (existing == null) {
          // First insert only: unsubscribed by default (opt-in decks).
          await _db.decksDao.upsertDeck(
            LocalDecksCompanion.insert(
              id: deckId,
              externalId: externalId,
              name: name,
              description: Value(description),
              nodeId: const Value(null),
              tierOrder: const Value(0),
              cardCount: Value(members.length),
              isSubscribed: const Value(false),
              category: const Value('delegation'),
              updatedAt: nowSeconds,
            ),
          );
        } else {
          // Metadata-only refresh: NEVER write isSubscribed here, or a
          // weekly roster re-seed would silently reset the user's choice.
          await (_db.update(_db.localDecks)..where((d) => d.id.equals(deckId)))
              .write(
            LocalDecksCompanion(
              name: Value(name),
              description: Value(description),
              cardCount: Value(members.length),
              updatedAt: Value(nowSeconds),
            ),
          );
        }

        // Senators first alphabetically by name, then house members by
        // district then name.
        final sorted = [...members]..sort((a, b) {
            final aSen = a.chamber == 'senate' ? 0 : 1;
            final bSen = b.chamber == 'senate' ? 0 : 1;
            if (aSen != bSen) return aSen - bSen;
            if (aSen == 1) {
              final d = (a.district ?? 0).compareTo(b.district ?? 0);
              if (d != 0) return d;
            }
            return a.name.compareTo(b.name);
          });

        for (var i = 0; i < sorted.length; i++) {
          final p = sorted[i];
          rosterIds.add(p.id);
          await _db.cardsDao.upsertCard(
            LocalCardsCompanion.insert(
              id: p.id,
              deckId: deckId,
              externalId: p.id,
              politicianName: p.name,
              title: _titleFor(p, st, stateName),
              party: Value(p.party),
              jurisdiction: Value(stateName),
              photoUrl: Value(p.portraitAsset),
              gender: const Value(null),
              cardType: const Value('face'),
              oneLiner: Value(_oneLinerFor(p)),
              sourceUrl: p.officialUrl ??
                  'https://bioguide.congress.gov/search/bio/${p.id}',
              sortOrder: Value(i),
              updatedAt: nowSeconds,
              isActive: const Value(true),
            ),
          );

          // Only init memory state if this card is genuinely new, exactly
          // like the YAML seeder: re-seeding must not wipe review history.
          final state = await _db.reviewsDao.stateFor(p.id);
          if (state == null) {
            await _db.reviewsDao.upsertState(
              CardMemoryStatesCompanion(
                cardId: Value(p.id),
                isNew: const Value(true),
              ),
            );
          }
        }
      }

      // Roster departures: deactivate delegation cards absent from the
      // current roster. FSRS rows are retained on purpose.
      final delegationDecks = await _db.decksDao.decksByCategory('delegation');
      await _db.cardsDao.deactivateDeckCardsNotIn(
        deckIds: delegationDecks.map((d) => d.id).toSet(),
        keepCardIds: rosterIds,
      );

      await _db.metaDao.set(_hashKey, hash);
    });
  }

  static String _titleFor(Person p, String st, String stateName) {
    if (p.chamber == 'senate') return 'U.S. Senator from $stateName';
    if (st == 'PR') return 'Resident Commissioner of Puerto Rico';
    if (const {'DC', 'GU', 'VI', 'AS', 'MP'}.contains(st)) {
      return 'Delegate to the U.S. House from $stateName';
    }
    if (p.district == null || p.district == 0) {
      return 'U.S. Representative from $stateName (at large)';
    }
    return 'U.S. Representative, $st-${p.district}';
  }

  static String? _oneLinerFor(Person p) {
    try {
      final decoded = json.decode(p.committees);
      if (decoded is! List) return null;
      for (final c in decoded) {
        if (c is Map && c['name'] is String) {
          return 'Serves on the ${c['name']}.';
        }
      }
    } catch (_) {
      // Malformed committees JSON: no one-liner.
    }
    return null;
  }
}
