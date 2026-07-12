import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/benchmark/data/benchmark_loader.dart';
import 'package:politiface/features/benchmark/domain/benchmark.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late Benchmarks benchmarks;

  setUpAll(() async {
    benchmarks = await BenchmarkLoader().load();
  });

  test('bundled benchmarks.yaml loads with entries', () {
    expect(benchmarks.all, isNotEmpty);
  });

  test('every benchmark is fully sourced', () {
    for (final b in benchmarks.all) {
      expect(b.stat, isNotEmpty, reason: '${b.id} stat');
      expect(b.youLine, isNotEmpty, reason: '${b.id} you_line');
      expect(b.source, isNotEmpty, reason: '${b.id} source');
      expect(b.chapterIds, isNotEmpty, reason: '${b.id} chapter_ids');
      // Sourcing is the credibility premise — every stat must cite a URL.
      expect(b.url, isNotNull, reason: '${b.id} url');
      expect(b.url, isNotEmpty, reason: '${b.id} url');
      expect(b.year, greaterThanOrEqualTo(2000));
      expect(b.year, lessThanOrEqualTo(2026));
    }
  });

  test('ids are unique', () {
    final ids = benchmarks.all.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  group('forChapter selection', () {
    test('returns a chapter-relevant benchmark', () {
      final b = benchmarks.forChapter(
        'ch3.three-branches',
        dateIso: '2026-06-14',
      );
      expect(b, isNotNull);
      expect(b!.chapterIds, contains('ch3.three-branches'));
    });

    test('is deterministic for the same chapter + date', () {
      final a = benchmarks.forChapter(
        'ch5.rights-and-the-court',
        dateIso: '2026-06-14',
      );
      final b = benchmarks.forChapter(
        'ch5.rights-and-the-court',
        dateIso: '2026-06-14',
      );
      expect(a!.id, b!.id);
    });

    test('returns null for a chapter with no benchmark', () {
      // An unknown chapter must degrade to null, not throw.
      final b = benchmarks.forChapter(
        'ch99.nonexistent',
        dateIso: '2026-06-14',
      );
      expect(b, isNull);
    });
  });
}
