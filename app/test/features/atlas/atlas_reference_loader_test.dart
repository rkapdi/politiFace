import 'package:flutter_test/flutter_test.dart';
import 'package:politiface/features/atlas/data/atlas_reference_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled executive orders and vocabulary', () async {
    final reference = await AtlasReferenceLoader().load();

    // Executive orders: real Federal Register data, newest first.
    expect(reference.orders.length, greaterThan(200));
    expect(reference.ordersUpdated, isNotNull);
    final first = reference.orders.first;
    expect(first.number, greaterThanOrEqualTo(reference.orders.last.number));
    for (final o in reference.orders.take(20)) {
      expect(o.url, startsWith('https://www.federalregister.gov/'));
      expect(o.title, isNotEmpty);
      expect(o.signingDate, matches(r'^\d{4}-\d{2}-\d{2}$'));
    }

    // Recent laws: real congress.gov data, newest first, sponsors linked.
    expect(reference.laws.length, greaterThan(50));
    expect(reference.lawsCongress, 119);
    final law = reference.laws.first;
    expect(law.lawNumber, isNotEmpty);
    expect(law.url, startsWith('https://www.congress.gov/'));
    expect(
      reference.laws.where((l) => l.sponsorBioguide != null).length,
      greaterThan(50),
    );

    // Recent bill actions: the Pulse feed source.
    expect(reference.bills.length, greaterThan(100));
    for (final b in reference.bills.take(10)) {
      expect(b.url, startsWith('https://www.congress.gov/'));
      expect(b.action, isNotEmpty);
      expect(b.actionDate, matches(r'^\d{4}-\d{2}-\d{2}$'));
    }

    // CRS summaries: quoted external content, stripped and capped by the
    // fetcher. Gated so the test passes before the first content refresh
    // with summaries lands in the bundle.
    final withSummaries =
        reference.bills.where((b) => b.summary != null).toList();
    if (withSummaries.isNotEmpty) {
      expect(withSummaries.length, greaterThan(20));
      final first = withSummaries.first;
      expect(first.summary!.length, lessThanOrEqualTo(2500));
      expect(
        first.summary!.contains('<'),
        isFalse,
        reason: 'summary should be stripped of HTML',
      );
      // No em-dash check here on purpose: CRS text is quoted external
      // content and exempt from house style.
    }

    // Vocabulary: alphabetical, every term cited.
    expect(reference.terms.length, greaterThanOrEqualTo(10));
    final names = [for (final t in reference.terms) t.term.toLowerCase()];
    expect(names, orderedEquals([...names]..sort()));
    for (final t in reference.terms) {
      expect(t.citation, startsWith('https://'));
      expect(t.definition.length, greaterThan(20));
      // House style: no em-dashes in student-facing text.
      expect(
        t.definition.contains('—'),
        isFalse,
        reason: '${t.id} definition contains an em-dash',
      );
    }
  });
}
