import 'package:eventory/eventory.dart';
import 'package:eventory/src/snapshot_backed_event_source.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotBackedEventSource', () {
    test('should be able to get the correct entity at different times',
        () async {
      final source = await SnapshotBackedEventSource.load(_testEvents(),
          eventsPerSnapshot: 3);

      expect(await source.getEntity('a', DateTime.parse('1990-12-01')),
          equals({'A': 1, 'E': 5, 'I': 9}));
      expect(await source.getEntity('a'), equals({'A': 1, 'E': 5, 'I': 9}));
    });
  });
}

Stream<Event> _testEvents() {
  final events = [
    Event('a', 'A', 1, DateTime.parse('1990-01-01')),
    Event('b', 'B', 2, DateTime.parse('1990-01-02')),
    Event('c', 'C', 3, DateTime.parse('1990-01-03')),
    Event('d', 'D', 4, DateTime.parse('1990-01-04')),
    //
    Event('a', 'E', 5, DateTime.parse('1990-01-05')),
    Event('b', 'F', 6, DateTime.parse('1990-01-06')),
    Event('c', 'G', 7, DateTime.parse('1990-01-07')),
    Event('d', 'H', 8, DateTime.parse('1990-01-08')),
    //
    Event('a', 'I', 9, DateTime.parse('1990-01-09')),
    Event('b', 'J', 10, DateTime.parse('1990-01-10')),
  ];
  return Stream.fromIterable(events);
}
