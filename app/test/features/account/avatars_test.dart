// Pure determinism tests for the avatar system: same id always yields the
// same (color, glyph) pair, every id 0..47 renders without crashing, and
// the 48 combinations are distinct enough to tell apart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/account/domain/avatars.dart';

void main() {
  test('same id always yields the same color and glyph', () {
    for (var id = 0; id < kAvatarCount; id++) {
      final a = avatarSpecFor(id);
      final b = avatarSpecFor(id);
      expect(a.backgroundColor, b.backgroundColor);
      expect(a.icon, b.icon);
    }
  });

  test('all 48 ids produce a distinct (color, glyph) combination', () {
    final seen = <String>{};
    for (var id = 0; id < kAvatarCount; id++) {
      final spec = avatarSpecFor(id);
      final key = '${spec.backgroundColor.value}-${spec.icon.codePoint}';
      expect(
        seen.add(key),
        isTrue,
        reason: 'avatar $id collided with an earlier id: $key',
      );
    }
    expect(seen, hasLength(kAvatarCount));
  });

  test('every id in range yields an opaque, non-transparent color', () {
    for (var id = 0; id < kAvatarCount; id++) {
      expect(avatarSpecFor(id).backgroundColor.opacity, greaterThan(0));
    }
  });

  test('out-of-range and negative ids never crash, and wrap deterministically',
      () {
    expect(() => avatarSpecFor(-1), returnsNormally);
    expect(() => avatarSpecFor(48), returnsNormally);
    expect(() => avatarSpecFor(1000), returnsNormally);
    expect(() => avatarSpecFor(-1000), returnsNormally);

    // Wrapping is deterministic (mod arithmetic), not just crash-free.
    expect(avatarSpecFor(48).backgroundColor, avatarSpecFor(0).backgroundColor);
    expect(avatarSpecFor(48).icon, avatarSpecFor(0).icon);
    expect(
      avatarSpecFor(-1).backgroundColor,
      avatarSpecFor(kAvatarCount - 1).backgroundColor,
    );
    expect(avatarSpecFor(-1).icon, avatarSpecFor(kAvatarCount - 1).icon);
  });

  testWidgets('PolitifaceAvatar renders every id 0..47 without crashing',
      (tester) async {
    for (var id = 0; id < kAvatarCount; id++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PolitifaceAvatar(avatarId: id)),
        ),
      );
      expect(find.byType(PolitifaceAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
