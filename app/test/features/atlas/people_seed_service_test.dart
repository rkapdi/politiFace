import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/core/database/drift/app_database.dart';
import 'package:politiface/features/atlas/data/people_seed_service.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = files[key];
    if (content == null) throw StateError('missing asset $key');
    return content;
  }
}

const _yaml = '''
updated: '2026-07-06'
source: test
people:
  - id: S000001
    name: Test Senator
    first: Test
    last: Senator
    birthday: '1970-01-01'
    wikidata: Q1
    chamber: senate
    state: FL
    district: null
    party: Republican
    current_term:
      start: '2025-01-03'
      end: '2031-01-03'
      url: https://example.senate.gov
    terms:
      - {type: sen, start: '2025-01-03', end: '2031-01-03', state: FL, party: Republican}
      - {type: rep, start: '2019-01-03', end: '2025-01-03', state: FL, district: 5, party: Republican}
    committees:
      - {code: SSJU, name: Senate Committee on the Judiciary, rank: 3, title: null}
    citations:
      - https://bioguide.congress.gov/search/bio/S000001
  - id: R000002
    name: Test Rep
    first: Test
    last: Rep
    birthday: '1980-02-02'
    wikidata: Q2
    chamber: house
    state: CA
    district: 12
    party: Democrat
    current_term:
      start: '2025-01-03'
      end: '2027-01-03'
      url: https://example.house.gov
    terms:
      - {type: rep, start: '2025-01-03', end: '2027-01-03', state: CA, district: 12, party: Democrat}
    committees: []
    citations:
      - https://bioguide.congress.gov/search/bio/R000002
''';

const _manifest =
    '{"assets/content/portraits/congress/S000001.jpg":["assets/content/portraits/congress/S000001.jpg"]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  PeopleSeedService service() => PeopleSeedService(
        db,
        bundle: _FakeBundle({
          'assets/content/people/legislators.yaml': _yaml,
          'AssetManifest.json': _manifest,
        }),
      );

  test('seeds people with portraits, roles, and JSON payloads', () async {
    await service().ensureSeeded();
    expect(await db.peopleDao.count(), 2);

    final senator = (await db.peopleDao.byId('S000001'))!;
    expect(senator.name, 'Test Senator');
    expect(senator.currentRole, 'United States Senator from FL');
    expect(senator.portraitAsset,
        'assets/content/portraits/congress/S000001.jpg',);
    expect(senator.terms, contains('"district":5')); // full history kept
    expect(senator.committees, contains('Judiciary'));

    final rep = (await db.peopleDao.byId('R000002'))!;
    expect(rep.currentRole, 'U.S. Representative, CA district 12');
    expect(rep.portraitAsset, isNull); // not in the manifest -> initials
  });

  test('reseeding with unchanged content is a no-op (checksum)', () async {
    await service().ensureSeeded();
    final before = await db.metaDao.get('seed.people.hash');
    await service().ensureSeeded();
    expect(await db.metaDao.get('seed.people.hash'), before);
    expect(await db.peopleDao.count(), 2);
  });

  test('directory filters compose and states list is distinct', () async {
    await service().ensureSeeded();

    expect((await db.peopleDao.directory(chamber: 'senate')).single.id,
        'S000001',);
    expect((await db.peopleDao.directory(state: 'CA')).single.id, 'R000002');
    expect((await db.peopleDao.directory(party: 'Republican')).single.id,
        'S000001',);
    expect((await db.peopleDao.directory(query: 'rep')).single.id, 'R000002');
    expect(
      await db.peopleDao.directory(chamber: 'house', state: 'FL'),
      isEmpty,
    );
    expect(await db.peopleDao.states(), ['CA', 'FL']);
  });

  test('the real bundled roster seeds all 537 members with enrichment',
      () async {
    // Uses the actual shipped assets (rootBundle).
    await PeopleSeedService(db).ensureSeeded();
    expect(await db.peopleDao.count(), 537);
    final states = await db.peopleDao.states();
    expect(states, contains('FL'));
    final fl = await db.peopleDao.directory(state: 'FL');
    expect(fl.length, greaterThanOrEqualTo(29));

    // congress.gov enrichment merged into extras (offline, bundled).
    final enriched = fl.where((p) => p.extras.contains('sponsored_count'));
    expect(enriched.length, fl.length,
        reason: 'every member should carry enrichment',);
  });
}
