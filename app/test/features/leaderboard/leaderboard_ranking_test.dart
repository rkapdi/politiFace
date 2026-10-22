import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/leaderboard/data/leaderboard_api.dart';

void main() {
  test('rankEntries sorts descending and applies competition ranking', () {
    final entries = rankEntries([
      (userId: 'u1', handle: 'a', score: 10, avatarId: 0),
      (userId: 'u2', handle: 'b', score: 30, avatarId: 1),
      (userId: 'u3', handle: 'c', score: 20, avatarId: 2),
      (userId: 'u4', handle: 'd', score: 20, avatarId: 3),
      (userId: 'u5', handle: 'e', score: 5, avatarId: 4),
    ]);

    expect(
      entries.map((e) => e.userId).toList(),
      ['u2', 'u3', 'u4', 'u1', 'u5'],
    );
    // Ties share a rank; the next rank skips (1, 2, 2, 4, 5).
    expect(entries.map((e) => e.rank).toList(), [1, 2, 2, 4, 5]);
    // avatarId carries through unchanged.
    expect(entries.map((e) => e.avatarId).toList(), [1, 2, 3, 0, 4]);
  });

  test('rankEntries handles empty and single rows', () {
    expect(rankEntries([]), isEmpty);
    final one =
        rankEntries([(userId: 'u', handle: 'h', score: 0, avatarId: 5)]);
    expect(one.single.rank, 1);
    expect(one.single.avatarId, 5);
  });

  test('all tied means everyone is rank 1', () {
    final entries = rankEntries([
      (userId: 'u1', handle: 'a', score: 7, avatarId: 0),
      (userId: 'u2', handle: 'b', score: 7, avatarId: 0),
      (userId: 'u3', handle: 'c', score: 7, avatarId: 0),
    ]);
    expect(entries.map((e) => e.rank).toList(), [1, 1, 1]);
  });
}
