import 'package:eventory/eventory.dart';
import 'package:eventory/src/event_list.dart';
import 'package:test/test.dart';

void main() {
  group('EventList events are sorted by instant', () {
    test('(already sorted)', () {
      final events = [
        Event('', '', 1, DateTime.parse('1990-01-01')),
        Event('', '', 2, DateTime.parse('1990-01-02')),
        Event('', '', 3, DateTime.parse('1990-01-03')),
        Event('', '', 4, DateTime.parse('1990-01-04')),
        Event('', '', 5, DateTime.parse('1990-01-05')),
      ];
      final eventList = EventList();
      events.forEach(eventList.add);

      expect(
          eventList.all.map((e) => e.value).toList(), equals([1, 2, 3, 4, 5]));
    });

    test('(unsorted)', () {
      final events = [
        Event('', '', 3, DateTime.parse('1990-01-03')),
        Event('', '', 1, DateTime.parse('1990-01-01')),
        Event('', '', 4, DateTime.parse('1990-01-04')),
        Event('', '', 5, DateTime.parse('1990-01-05')),
        Event('', '', 2, DateTime.parse('1990-01-02')),
      ];
      final eventList = EventList();
      events.forEach(eventList.add);

      expect(
          eventList.all.map((e) => e.value).toList(), equals([1, 2, 3, 4, 5]));
    });
  });

  group('EventList partial', () {
    test('empty', () {
      expect(EventList().partial().toList(), equals([]));
    });
    test('with all combinations of bounds', () {
      final events = [
        Event('', '', 1, DateTime.parse('1990-01-01')),
        Event('', '', 2, DateTime.parse('1990-01-02')),
        Event('', '', 3, DateTime.parse('1990-01-03')),
        Event('', '', 4, DateTime.parse('1990-01-04')),
        Event('', '', 5, DateTime.parse('1990-01-05')),
        Event('', '', 100, DateTime.parse('3000-01-01')),
      ];
      final eventList = EventList();
      events.forEach(eventList.add);

      expect(eventList.partial().map((e) => e.value).toList(),
          equals([1, 2, 3, 4, 5, 100]));

      expect(
          eventList
              .partial(from: DateTime.parse('1990-01-03'))
              .map((e) => e.value)
              .toList(),
          equals([3, 4, 5, 100]));

      expect(
          eventList
              .partial(to: DateTime.parse('1990-01-03'))
              .map((e) => e.value)
              .toList(),
          equals([1, 2, 3]));

      expect(
          eventList
              .partial(
                  from: DateTime.parse('1990-01-02'),
                  to: DateTime.parse('1990-01-04'))
              .map((e) => e.value)
              .toList(),
          equals([2, 3, 4]));
    });
  });

  group('EventList findEvent', () {
    final events = [
      Event('', 'a', 1, DateTime.parse('1990-01-01')),
      Event('', 'a', 2, DateTime.parse('1990-01-02')),
      Event('', 'a', 3, DateTime.parse('1990-01-03')),
      Event('', 'b', 4, DateTime.parse('1990-01-04')),
      Event('', 'b', 5, DateTime.parse('1990-01-05')),
      Event('', 'a', 100, DateTime.parse('3000-01-01')),
    ];
    final eventList = EventList();
    events.forEach(eventList.add);

    test('no args', () {
      expect(eventList.findEvent()?.value, equals(5));
    });
    test('by attribute', () {
      expect(eventList.findEvent(attribute: 'a')?.value, equals(3));
      expect(eventList.findEvent(attribute: 'b')?.value, equals(5));
      expect(eventList.findEvent(attribute: 'c')?.value, isNull);
    });
    test('too far in the past', () {
      expect(eventList.findEvent(instant: DateTime.parse('1900-01-01'))?.value,
          isNull);
    });
    test('far in the future', () {
      expect(eventList.findEvent(instant: DateTime.parse('4000-01-01'))?.value,
          equals(100));
    });
    test('by attribute and instant', () {
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('1960-01-01'))
              ?.value,
          isNull);
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('1990-01-01'))
              ?.value,
          equals(1));
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('1990-01-02'))
              ?.value,
          equals(2));
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('1990-01-03'))
              ?.value,
          equals(3));
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('1990-01-04'))
              ?.value,
          equals(3));
      expect(
          eventList
              .findEvent(attribute: 'a', instant: DateTime.parse('4000-01-01'))
              ?.value,
          equals(100));

      expect(
          eventList
              .findEvent(attribute: 'b', instant: DateTime.parse('1990-01-03'))
              ?.value,
          isNull);
      expect(
          eventList
              .findEvent(attribute: 'b', instant: DateTime.parse('1990-01-04'))
              ?.value,
          equals(4));
      expect(
          eventList
              .findEvent(attribute: 'b', instant: DateTime.parse('1990-01-05'))
              ?.value,
          equals(5));
      expect(
          eventList
              .findEvent(attribute: 'b', instant: DateTime.parse('1990-01-06'))
              ?.value,
          equals(5));
      expect(
          eventList
              .findEvent(attribute: 'b', instant: DateTime.parse('4000-01-01'))
              ?.value,
          equals(5));

      expect(
          eventList
              .findEvent(attribute: 'c', instant: DateTime.parse('1990-01-06'))
              ?.value,
          isNull);
      expect(
          eventList
              .findEvent(attribute: 'c', instant: DateTime.parse('4000-01-01'))
              ?.value,
          isNull);
    });
  });
}
