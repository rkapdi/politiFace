import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/curriculum/data/curriculum_loader.dart';
import 'package:yaml/yaml.dart';

/// Validates the chapter-to-deck mapping declared in us_civics.yaml against
/// the deck YAML files on disk: every non-planned deck ref must name a real
/// deck file whose meta.id matches the ref id. Planned refs (ch4-6 backlog)
/// are exempt until authored.
///
/// Reads files relative to the app/ working directory used by flutter test.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('every non-planned chapter deck ref resolves to a deck YAML file',
      () async {
    final curriculum = await CurriculumLoader().load();
    for (final chapter in curriculum.chapters) {
      for (final ref in chapter.decks) {
        if (ref.planned) continue;
        final file = File('assets/content/decks/${ref.id}.yaml');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'chapter ${chapter.id} declares deck ${ref.id} but '
              '${file.path} does not exist',
        );
        final doc = loadYaml(file.readAsStringSync()) as Map;
        final meta = doc['meta'] as Map?;
        expect(
          meta,
          isNotNull,
          reason: '${file.path} has no meta block',
        );
        expect(
          meta!['id'],
          ref.id,
          reason: '${file.path} meta.id does not match chapter '
              '${chapter.id} deck ref ${ref.id}',
        );
      }
    }
  });

  test('planned deck refs are exactly the ch4-6 authoring backlog', () async {
    final curriculum = await CurriculumLoader().load();
    final planned = <String>[
      for (final chapter in curriculum.chapters)
        for (final ref in chapter.decks)
          if (ref.planned) ref.id,
    ];
    expect(planned, [
      'us-concepts-lawmaking',
      'us-concepts-rights-cases',
      'us-concepts-participation',
    ]);
  });
}
