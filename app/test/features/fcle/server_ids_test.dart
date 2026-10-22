import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/fcle/domain/server_ids.dart';

void main() {
  // Fixtures generated with Python:
  //   NS = uuid.uuid5(uuid.NAMESPACE_URL, "politiface.app/content")
  //   uuid.uuid5(NS, "question:<id>")
  // They pin bit-for-bit parity with scripts/ingest_content.py. If these
  // ever fail, outbox events would reference ids the server never wrote.
  test('content namespace matches the Python ingest', () {
    expect(contentNamespace, 'a1536d43-5eb8-503b-afdf-e1f8cf9a2ceb');
  });

  test('question uuids match the Python ingest', () {
    expect(
      serverUuidForQuestion('amdem-separation-powers-001'),
      '1ee6ea7d-3d19-5c01-85d1-8d5051ea141e',
    );
    expect(
      serverUuidForQuestion('usconst-article1-congress-001'),
      '00f8a139-8200-5637-94f7-be962f60261c',
    );
    expect(
      serverUuidForQuestion('landmark-marbury-001'),
      '9dcfd184-33b5-5913-aa45-bc5c50c0f937',
    );
  });

  test('uuidV5 output shape', () {
    final id = serverUuidForQuestion('anything');
    expect(
      id,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );
    // Deterministic.
    expect(serverUuidForQuestion('anything'), id);
  });
}
