import 'package:eventory/eventory.dart';
import 'package:test/test.dart';

mixin _TestSubject {
  EventSink createEventSink();

  EventSource createEventSource(EventSink sink);
}

class _InMemoryTestSubject with _TestSubject {
  @override
  EventSink createEventSink() => InMemoryEventSink();

  @override
  EventSource createEventSource(EventSink sink) => sink as EventSource;

  @override
  String toString() => 'InMemoryTestSubject';
}

void main() {
  final List<_TestSubject> testSubjects = [
    _InMemoryTestSubject(),
  ];

  for (final testSubject in testSubjects) {
    group('$testSubject with a few immediate events', () {
      EventSink sink;
      EventSource source;

      setUp(() {
        sink = testSubject.createEventSink();

        // given some events
        sink.add(Event('joe', const Attribute.unchecked(["age"]), 24));
        sink.add(Event('mary', const Attribute.unchecked(["age"]), 26));
        sink.add(Event('adam', const Attribute.unchecked(["age"]), 53));
        sink.add(Event('joe', const Attribute.unchecked(["address", "street"]),
            'High Street'));
        sink.add(Event('joe',
            const Attribute.unchecked(["address", "street_number"]), 32));
        sink.add(Event('mary', const Attribute.unchecked(["address", "street"]),
            'Low Street'));
        sink.add(Event('mary',
            const Attribute.unchecked(["address", "street_number"]), 423));

        // updates Joe's address
        sink.add(Event('joe', const Attribute.unchecked(["address", "street"]),
            'Medium Street'));
        sink.add(Event('joe',
            const Attribute.unchecked(["address", "street_number"]), 12));

        source = testSubject.createEventSource(sink);
      });

      test('can use simple event lookup', () {
        expect(source.getValue('joe', Attribute(["age"])), equals(24));
        expect(source.getValue('mary', const Attribute.unchecked(["age"])),
            equals(26));
        expect(source.getValue('adam', const Attribute.unchecked(["age"])),
            equals(53));

        expect(source.getValue('joe', const Attribute.unchecked(["number"])),
            isNull);
        expect(source.getValue('joe', const Attribute.unchecked(["address"])),
            isNull);
        expect(source.getValue('other', const Attribute.unchecked(["age"])),
            isNull);
        expect(source.getValue('other', const Attribute.unchecked(["xxx"])),
            isNull);
      });

      test('can see updates in event lookup', () {
        expect(source.getValue('joe', Attribute(["address", "street"])),
            equals('Medium Street'));
        expect(source.getValue('joe', Attribute(["address", "street_number"])),
            equals(12));
        expect(
            source.getValue(
                'mary', const Attribute.unchecked(["address", "street"])),
            equals('Low Street'));
        expect(
            source.getValue('mary',
                const Attribute.unchecked(["address", "street_number"])),
            equals(423));
      });
      test('can re-constitute a full entity', () {
        final expectedJoe = {
          const Attribute.unchecked(["age"]): 24,
          const Attribute.unchecked(["address", "street"]): 'Medium Street',
          const Attribute.unchecked(["address", "street_number"]): 12,
        };

        final joe = source.getEntity('joe');

        expect(joe, equals(expectedJoe));

        final expectedMary = {
          const Attribute.unchecked(["age"]): 26,
          const Attribute.unchecked(["address", "street"]): 'Low Street',
          const Attribute.unchecked(["address", "street_number"]): 423,
        };

        final mary = source.getEntity('mary');

        expect(mary, equals(expectedMary));

        final expectedAdam = {
          const Attribute.unchecked(["age"]): 53,
        };

        final adam = source.getEntity('adam');

        expect(adam, equals(expectedAdam));
      });
    });

    group('$testSubject with time-spaced events', () {
      EventSink sink;
      EventSource source;

      setUp(() {
        sink = testSubject.createEventSink();

        // given some events
        sink.add(Event('brazil', const Attribute.unchecked(["population"]),
            90e6, DateTime.parse('1970-01-01')));
        sink.add(Event('brazil', const Attribute.unchecked(["population"]),
            100e6, DateTime.parse('1972-03-15')));
        sink.add(Event('brazil', const Attribute.unchecked(["population"]),
            150e6, DateTime.parse('1990-06-02')));
        sink.add(Event('brazil', const Attribute.unchecked(["population"]),
            200e6, DateTime.parse('2012-01-02')));
        sink.add(Event('sweden', const Attribute.unchecked(["population"]), 7e6,
            DateTime.parse('1955-01-01')));
        sink.add(Event('sweden', const Attribute.unchecked(["population"]), 8e6,
            DateTime.parse('1970-01-01')));
        sink.add(Event('sweden', const Attribute.unchecked(["population"]), 9e6,
            DateTime.parse('2005-06-01')));
        sink.add(Event('sweden', const Attribute.unchecked(["population"]),
            10e6, DateTime.parse('2019-01-01')));

        sink.add(Event('sweden', const Attribute.unchecked(["languages"]),
            {'swedish', 'sami'}, DateTime.parse('0912-01-01')));
        sink.add(Event('brazil', const Attribute.unchecked(["languages"]),
            {'portuguese'}, DateTime.parse('1500-01-01')));

        source = testSubject.createEventSource(sink);
      });

      test('can use simple event lookup at different points in time', () {
        expect(source.getValue('brazil', Attribute(["population"])),
            equals(200e6));
        expect(
            source.getValue('brazil', Attribute(["population"]),
                DateTime.parse('1970-06-01')),
            equals(90e6));
        expect(
            source.getValue('brazil', Attribute(["population"]),
                DateTime.parse('1990-06-01')),
            equals(100e6));
        expect(
            source.getValue('brazil', Attribute(["population"]),
                DateTime.parse('1990-06-05')),
            equals(150e6));
        expect(
            source.getValue('sweden', Attribute(["population"]),
                DateTime.parse('1960-01-01')),
            equals(7e6));

        expect(
            source.getValue('brazil', const Attribute.unchecked(["population"]),
                DateTime.parse('1930-01-01')),
            isNull);
        expect(
            source.getValue('sweden', const Attribute.unchecked(["population"]),
                DateTime.parse('1930-01-01')),
            isNull);
        expect(source.getValue('brazil', const Attribute.unchecked(["number"])),
            isNull);
        expect(
            source.getValue('sweden', const Attribute.unchecked(["address"])),
            isNull);
        expect(
            source.getValue(
                'australia', const Attribute.unchecked(["population"])),
            isNull);
        expect(
            source.getValue(
                'sweden', const Attribute.unchecked(["xxx", "yyy"])),
            isNull);
      });

      test('can re-constitute a full entity at different points in time', () {
        final expectedBrazilIn1200 = <Attribute, dynamic>{};

        final expectedBrazilIn1971 = {
          const Attribute.unchecked(["population"]): 90e6,
          const Attribute.unchecked(["languages"]): {'portuguese'},
        };

        final expectedBrazilIn2020 = {
          const Attribute.unchecked(["population"]): 200e6,
          const Attribute.unchecked(["languages"]): {'portuguese'},
        };

        final expectedSwedenIn2020 = {
          const Attribute.unchecked(["population"]): 10e6,
          const Attribute.unchecked(["languages"]): {'swedish', 'sami'},
        };

        final expectedSwedenIn1200 = {
          const Attribute.unchecked(["languages"]): {'swedish', 'sami'},
        };

        final brazilIn1200 =
            source.getEntity('brazil', DateTime.parse('1200-01-01'));

        expect(brazilIn1200, equals(expectedBrazilIn1200));

        final brazilIn1971 =
            source.getEntity('brazil', DateTime.parse('1971-01-01'));

        expect(brazilIn1971, equals(expectedBrazilIn1971));

        final brazilIn2020 =
            source.getEntity('brazil', DateTime.parse('2020-01-01'));

        expect(brazilIn2020, equals(expectedBrazilIn2020));

        final swedenIn2020 =
            source.getEntity('sweden', DateTime.parse('2020-01-01'));

        expect(swedenIn2020, equals(expectedSwedenIn2020));

        final swedenIn1200 =
            source.getEntity('sweden', DateTime.parse('1200-01-01'));

        expect(swedenIn1200, equals(expectedSwedenIn1200));
      });
    });
    group('$testSubject errors', () {
      EventSink sink;
      setUp(() {
        sink = testSubject.createEventSink();
      });
      test('cannot add Event after closed', () {
        sink.close();
        expect(() {
          sink.add(Event('a', const Attribute.unchecked(['b']), 1));
        }, throwsA(isA<ClosedException>()));
      });
    });

    group('$testSubject history', () {
      EventSink sink;
      EventSource source;
      DateTime t1 = DateTime.now();
      DateTime t2 = DateTime.now().add(Duration(seconds: 5));
      setUp(() {
        sink = testSubject.createEventSink();

        sink.add(Event('joe', const Attribute.unchecked(['age']), 33, t1));
        sink.add(Event('joe', const Attribute.unchecked(['age']), 34, t2));

        source = testSubject.createEventSource(sink);
      });
      test('keeps all events', () async {
        expect(
            await source.allEvents.toList(),
            equals([
              Event('joe', const Attribute.unchecked(["age"]), 33, t1),
              Event('joe', const Attribute.unchecked(["age"]), 34, t2),
            ]));
      });
    });
  }
}
