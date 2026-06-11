import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// In-memory [AssetBundle] for seeding tests. Construct a fresh instance per
/// "app launch" you simulate — [CachingAssetBundle] caches loadString results,
/// which is exactly what the real rootBundle does within one process.
class FakeAssetBundle extends CachingAssetBundle {
  FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('FakeAssetBundle: no asset for "$key"');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
