import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/data/question_bank_loader.dart';
import 'package:politiface/features/fcle/domain/fcle_question.dart';

/// Serves in-memory YAML for the four bank asset paths.
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

const _usConstYaml = '''
domain: us_constitution
questions:
  - id: usconst-a-001
    stem: Published question?
    options:
      - key: a
        text: Yes
      - key: b
        text: No
    answer: a
    explanation: It is published.
    citation: https://constitution.congress.gov/
    difficulty: 2
    status: published
  - id: usconst-b-001
    stem: Draft question stays hidden?
    options:
      - key: a
        text: Yes
      - key: b
        text: No
    answer: a
    explanation: Never shown.
    citation: https://constitution.congress.gov/
    status: draft
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads published questions only; drafts never reach students',
      () async {
    final bundle = _FakeBundle({
      'assets/content/questions/american_democracy.yaml':
          'domain: american_democracy\nquestions: []\n',
      'assets/content/questions/us_constitution.yaml': _usConstYaml,
      'assets/content/questions/founding_documents.yaml':
          'domain: founding_documents\nquestions: []\n',
      'assets/content/questions/landmark_impact.yaml':
          'domain: landmark_impact\nquestions: []\n',
    });
    final bank = await QuestionBankLoader(bundle: bundle).load();

    expect(bank.countFor(FcleDomain.usConstitution), 1);
    final q = bank.byDomain[FcleDomain.usConstitution]!.single;
    expect(q.id, 'usconst-a-001');
    expect(q.answerKey, 'a');
    expect(q.isCorrect('a'), isTrue);
    expect(q.isCorrect('b'), isFalse);
    expect(q.difficulty, 2);
    expect(bank.canAssembleMock, isFalse);
  });

  test('loads the real bundled bank without errors', () async {
    // The actual shipped assets: all drafts today, so the bank is empty,
    // but the files must parse.
    final bank = await QuestionBankLoader().load();
    expect(bank.byDomain.length, 4);
  });
}
