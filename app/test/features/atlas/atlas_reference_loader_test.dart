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

    // Vocabulary: alphabetical, every term cited.
    expect(reference.terms.length, greaterThanOrEqualTo(10));
    final names = [for (final t in reference.terms) t.term.toLowerCase()];
    expect(names, orderedEquals([...names]..sort()));
    for (final t in reference.terms) {
      expect(t.citation, startsWith('https://'));
      expect(t.definition.length, greaterThan(20));
      // House style: no em-dashes in student-facing text.
      expect(t.definition.contains('—'), isFalse,
          reason: '${t.id} definition contains an em-dash',);
    }
  });
}
