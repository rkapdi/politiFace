import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Checksum-based seed versioning.
///
/// Each seeder hashes the bundled content it consumes and stores the digest
/// in app_meta. On launch, a differing digest triggers a re-seed (which
/// always preserves user memory state); a matching digest skips work.
/// Replaces the old manual flag bumping (`yaml_seed_v3_done`,
/// `gov_seed_v1_done`) that made it easy to ship content edits existing
/// installs never saw.
String contentChecksum(Map<String, String> contentByPath) {
  final paths = contentByPath.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final path in paths) {
    // Path and content lengths prefix every entry so concatenation is
    // unambiguous (no crafted content can collide with a path boundary).
    buffer
      ..write(path.length)
      ..write(':')
      ..write(path)
      ..write(contentByPath[path]!.length)
      ..write(':')
      ..write(contentByPath[path]);
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}
