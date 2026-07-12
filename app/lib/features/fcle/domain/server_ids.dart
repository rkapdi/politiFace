// lib/features/fcle/domain/server_ids.dart
//
// Deterministic mapping from YAML content ids to server UUIDs. MUST stay
// bit-identical to scripts/ingest_content.py (uuid.uuid5 over the same
// namespace chain), because outbox events reference questions by the UUID
// the ingest wrote. Parity is pinned by fixtures in server_ids_test.dart
// generated with Python's uuid.uuid5.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// RFC 4122 NAMESPACE_URL.
const _namespaceUrl = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

/// uuid5(NAMESPACE_URL, 'politiface.app/content'), the content namespace.
final String contentNamespace = uuidV5(_namespaceUrl, 'politiface.app/content');

/// The server-side public.questions.id for a YAML question slug.
String serverUuidForQuestion(String yamlId) =>
    uuidV5(contentNamespace, 'question:$yamlId');

/// RFC 4122 version-5 (SHA-1, name-based) UUID.
String uuidV5(String namespace, String name) {
  final ns = _parse(namespace);
  final digest = sha1.convert([...ns, ...utf8.encode(name)]).bytes;
  final b = digest.sublist(0, 16);
  b[6] = (b[6] & 0x0f) | 0x50; // version 5
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  String hex(int start, int end) => b
      .sublist(start, end)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

List<int> _parse(String uuid) {
  final hex = uuid.replaceAll('-', '');
  return [
    for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
