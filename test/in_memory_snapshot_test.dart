import 'package:eventory/eventory.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryEntitiesSnapshot', () {
    test('can be created without previous snapshot', () {
      final snapshot = InMemoryEntitiesSnapshot.fromEvents([
        Event('k', 'value', 'v1', DateTime.parse('2010-03-04')),
        Event('k', 'type', 'version', DateTime.parse('2001-03-04')),
        Event('k', 'value', 'v2', DateTime.parse('2017-12-23')),
        Event('j', 'value', 'v1', DateTime.parse('2015-09-31')),
      ]);
      expect(snapshot.keys, equals({'k', 'j'}));
      expect(snapshot.length, equals(2));
      expect(snapshot['k'], equals({'type': 'version', 'value': 'v2'}));
      expect(snapshot['j'], equals({'value': 'v1'}));
      expect(snapshot['f'], isEmpty);
    });

    test('can be created from previous snapshot', () {
      final previousSnapshot = InMemoryEntitiesSnapshot.fromEvents([
        Event('k', 'value', 'v1', DateTime.parse('2001-03-04')),
        Event('k', 'type', 'version', DateTime.parse('2001-03-04')),
        Event('k', 'value', 'v2', DateTime.parse('2007-12-23')),
        Event('i', 'value', 'v1', DateTime.parse('2005-09-31')),
      ]);
      final snapshot = InMemoryEntitiesSnapshot.fromEvents([
        Event('k', 'value', 'v3', DateTime.parse('2010-03-04')),
        Event('k', 'value', 'v4', DateTime.parse('2017-12-23')),
        Event('j', 'value', 'v5', DateTime.parse('2015-09-31')),
      ], previousSnapshot);
      expect(snapshot.keys, equals({'k', 'i', 'j'}));
      expect(snapshot.length, equals(3));
      expect(snapshot['k'], equals({'type': 'version', 'value': 'v4'}));
      expect(snapshot['i'], equals({'value': 'v1'}));
      expect(snapshot['j'], equals({'value': 'v5'}));
      expect(snapshot['f'], isEmpty);
    });
  });
}
