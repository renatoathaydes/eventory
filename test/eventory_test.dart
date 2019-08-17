import 'dart:async';
import 'dart:io';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';
import 'package:eventory/src/snapshot_backed_event_source.dart';
import 'package:test/test.dart';

abstract class _TestSubject {
  EventorySink createEventSink();

  FutureOr<EventSource> createEventSource(EventorySink sink) =>
      sink.toEventSource();
}

class _InMemoryTestSubject with _TestSubject {
  @override
  EventorySink createEventSink() => InMemoryEventSink();

  @override
  String toString() => 'InMemoryTestSubject';
}

class _FileTestSubject with _TestSubject {
  final dir = Directory.systemTemp.createTempSync('file_test_subject');
  int _index = 0;

  _FileTestSubject() {
    print("FileTestSubject writing file to ${tempFile.path}");
  }

  File get tempFile => File("${dir.path}/my_test${_index}.txt");

  @override
  EventorySink createEventSink() {
    _index++;
    return FileEventSink(tempFile);
  }

  @override
  Future<EventSource> createEventSource(EventorySink sink) async =>
      FileEventSource.load(tempFile);

  @override
  String toString() => 'FileTestSubject';
}

class _SnapshotBackedTestSubject extends _TestSubject {
  @override
  EventorySink createEventSink() => InMemoryEventSink();

  Future<EventSource> createEventSource(EventorySink sink) async =>
      SnapshotBackedEventSource.load((await sink.toEventSource()).allEvents,
          eventsPerSnapshot: 4);

  @override
  String toString() => 'SnapshotBackedTestSubject';
}

void main() {
  final testSubjects = <_TestSubject>[
    _InMemoryTestSubject(),
    _FileTestSubject(),
    _SnapshotBackedTestSubject(),
  ];

  for (final testSubject in testSubjects) {
    group('$testSubject with a few immediate events', () {
      EventorySink sink;
      EventSource source;

      setUp(() async {
        sink = testSubject.createEventSink();

        // given some events
        await sink.add(Event('joe', "age", 24));
        await sink.add(Event('mary', "age", 26));
        await sink.add(Event('adam', "age", 53));
        await sink.add(Event('joe', "address/street", 'High Street'));
        await sink.add(Event('joe', "address/street_number", 32));
        await sink.add(Event('mary', "address/street", 'Low Street'));
        await sink.add(Event('mary', "address/street_number", 423));

        // updates Joe's address
        await sink.add(Event('joe', "address/street", 'Medium Street'));
        await sink.add(Event('joe', "address/street_number", 12));

        await sink.close();
        source = await testSubject.createEventSource(sink);
      });

      test('can use simple event lookup', () async {
        expect(await source.getValue('joe', "age"), equals(24));
        expect(await source.getValue('mary', "age"), equals(26));
        expect(await source.getValue('adam', "age"), equals(53));

        expect(await source.getValue('joe', "number"), isNull);
        expect(await source.getValue('joe', "address"), isNull);
        expect(await source.getValue('other', "age"), isNull);
        expect(await source.getValue('other', "xxx"), isNull);
      });

      test('can see updates in event lookup', () async {
        expect(await source.getValue('joe', "address/street"),
            equals('Medium Street'));
        expect(
            await source.getValue('joe', "address/street_number"), equals(12));
        expect(await source.getValue('mary', "address/street"),
            equals('Low Street'));
        expect(await source.getValue('mary', "address/street_number"),
            equals(423));
      });
      test('can re-constitute a full entity', () async {
        final expectedJoe = {
          "age": 24,
          "address/street": 'Medium Street',
          "address/street_number": 12,
        };

        final joe = await source.getEntity('joe');

        expect(joe, equals(expectedJoe));

        final expectedMary = {
          "age": 26,
          "address/street": 'Low Street',
          "address/street_number": 423,
        };

        final mary = await source.getEntity('mary');

        expect(mary, equals(expectedMary));

        final expectedAdam = {
          "age": 53,
        };

        final adam = await source.getEntity('adam');

        expect(adam, equals(expectedAdam));
      });
    });

    group('$testSubject with time-spaced events', () {
      EventorySink sink;
      EventSource source;

      setUp(() async {
        sink = testSubject.createEventSink();

        // given some events
        await sink.add(
            Event('brazil', "population", 90e6, DateTime.parse('1970-01-01')));
        await sink.add(
            Event('brazil', "population", 100e6, DateTime.parse('1972-03-15')));
        await sink.add(
            Event('brazil', "population", 150e6, DateTime.parse('1990-06-02')));
        await sink.add(
            Event('brazil', "population", 200e6, DateTime.parse('2012-01-02')));
        await sink.add(
            Event('sweden', "population", 7e6, DateTime.parse('1955-01-01')));
        await sink.add(
            Event('sweden', "population", 8e6, DateTime.parse('1970-01-01')));
        await sink.add(
            Event('sweden', "population", 9e6, DateTime.parse('2005-06-01')));
        await sink.add(
            Event('sweden', "population", 10e6, DateTime.parse('2019-01-01')));

        await sink.add(Event('sweden', "languages", {'swedish', 'sami'},
            DateTime.parse('0912-01-01')));
        await sink.add(Event('brazil', "languages", {'portuguese'},
            DateTime.parse('1500-01-01')));

        await sink.close();
        source = await testSubject.createEventSource(sink);
      });

      test('can use simple event lookup at different points in time', () async {
        expect(await source.getValue('brazil', "population"), equals(200e6));
        expect(
            await source.getValue(
                'brazil', "population", DateTime.parse('1970-01-01')),
            equals(90e6));
        expect(
            await source.getValue(
                'brazil', "population", DateTime.parse('1970-06-01')),
            equals(90e6));
        expect(
            await source.getValue(
                'brazil', "population", DateTime.parse('1990-06-01')),
            equals(100e6));
        expect(
            await source.getValue(
                'brazil', "population", DateTime.parse('1990-06-05')),
            equals(150e6));
        expect(
            await source.getValue(
                'sweden', "population", DateTime.parse('1960-01-01')),
            equals(7e6));

        expect(
            await source.getValue(
                'brazil', "population", DateTime.parse('1930-01-01')),
            isNull);
        expect(
            await source.getValue(
                'sweden', "population", DateTime.parse('1930-01-01')),
            isNull);
        expect(await source.getValue('brazil', "number"), isNull);
        expect(await source.getValue('sweden', "address"), isNull);
        expect(await source.getValue('australia', "population"), isNull);
        expect(await source.getValue('sweden', "xxx/yyy"), isNull);
      });

      test('can re-constitute a full entity at different points in time',
          () async {
        final expectedBrazilIn1200 = <String, dynamic>{};

        final expectedBrazilIn1971 = {
          "population": 90e6,
          "languages": {'portuguese'},
        };

        final expectedBrazilIn2020 = {
          "population": 200e6,
          "languages": {'portuguese'},
        };

        final expectedSwedenIn2020 = {
          "population": 10e6,
          "languages": {'swedish', 'sami'},
        };

        final expectedSwedenIn1200 = {
          "languages": {'swedish', 'sami'},
        };

        final brazilIn1200 =
            await source.getEntity('brazil', DateTime.parse('1200-01-01'));

        expect(brazilIn1200, equals(expectedBrazilIn1200));

        final brazilIn1971 =
            await source.getEntity('brazil', DateTime.parse('1971-01-01'));

        expect(brazilIn1971, equals(expectedBrazilIn1971));

        final brazilIn2020 =
            await source.getEntity('brazil', DateTime.parse('2020-01-01'));

        expect(brazilIn2020, equals(expectedBrazilIn2020));

        final swedenIn2020 =
            await source.getEntity('sweden', DateTime.parse('2020-01-01'));

        expect(swedenIn2020, equals(expectedSwedenIn2020));

        final swedenIn1200 =
            await source.getEntity('sweden', DateTime.parse('1200-01-01'));

        expect(swedenIn1200, equals(expectedSwedenIn1200));
      });
    });
    group('$testSubject errors', () {
      EventorySink sink;
      setUp(() {
        sink = testSubject.createEventSink();
      });
      test('cannot add Event after closed', () {
        sink.close();
        expect(() async {
          await sink.add(Event('a', "b", 1));
        }, throwsA(isA<ClosedException>()));
      });
    });

    group('$testSubject history', () {
      EventorySink sink;
      EventSource source;
      DateTime t1 = DateTime.parse('1970-01-01');
      DateTime t2 = t1.add(Duration(seconds: 5));
      DateTime t3 = t1.add(Duration(seconds: 15));
      setUp(() async {
        sink = testSubject.createEventSink();

        await sink.add(Event('joe', 'age', 33, t1));
        await sink.add(Event('joe', 'age', 34, t2));
        await sink.add(Event('mary', 'age', 39, t3));

        await sink.close();
        source = await testSubject.createEventSource(sink);
      });
      test('keeps all events', () async {
        expect(
            await source.allEvents.toList(),
            equals([
              Event('joe', "age", 33, t1),
              Event('joe', "age", 34, t2),
              Event('mary', "age", 39, t3),
            ]));
      });
      test('partial view (full)', () async {
        expect(
            await (await source.partial()).allEvents.toList(),
            equals([
              Event('joe', "age", 33, t1),
              Event('joe', "age", 34, t2),
              Event('mary', "age", 39, t3),
            ]));
      });
      test('partial views (from instant)', () async {
        expect(
            await (await source.partial(from: t2)).allEvents.toList(),
            equals([
              Event('joe', "age", 34, t2),
              Event('mary', "age", 39, t3),
            ]));
      });
      test('partial views (to instant)', () async {
        expect(
            await (await source.partial(to: t2)).allEvents.toList(),
            equals([
              Event('joe', "age", 33, t1),
              Event('joe', "age", 34, t2),
            ]));
      });
      test('partial views (from and to instants)', () async {
        expect(
            await (await source.partial(from: t2, to: t2)).allEvents.toList(),
            equals([
              Event('joe', "age", 34, t2),
            ]));
      });
      test('snapshot (full)', () async {
        final snapshot = await source.getSnapshot();
        expect(snapshot['joe'], equals({'age': 34}));
        expect(snapshot['mary'], equals({'age': 39}));
        expect(snapshot.keys, equals({'joe', 'mary'}));
        expect(snapshot.length, equals(2));
      });
    });

    group('$testSubject concurrency', () {
      EventorySink sink;
      EventSource source;
      setUp(() {
        sink = testSubject.createEventSink();
      });
      tearDown(() async {
        await sink.close();
      });
      test(
          'creation of EventSource from a sink while it keeps receiving events',
          () async {
        await sink.add(Event('a', 'b', 1));
        await sink.add(Event('a', 'b', 2));
        await sink.add(Event('b', 'a', 3));
        await sink.add(Event('b', 'c', 4));
        await sink.add(Event('b', 'd', 5));

        final futureSource = sink.toEventSource();

        await sink.add(Event('c', 'd', 6));
        await sink.add(Event('d', 'e', 7));
        await sink.add(Event('e', 'f', 8));

        source = await futureSource;

        final allEvents = await source.allEvents.toList();

        // only events up to the time we called toEventSource() must be included
        expect(allEvents, hasLength(greaterThanOrEqualTo(5)));
        expect(allEvents, hasLength(lessThan(9)));

        expect(allEvents[0].value, equals(1));
        expect(allEvents[1].value, equals(2));
        expect(allEvents[2].value, equals(3));
        expect(allEvents[3].value, equals(4));
        expect(allEvents[4].value, equals(5));

        if (allEvents.length > 5) expect(allEvents[5].value, equals(6));
        if (allEvents.length > 6) expect(allEvents[6].value, equals(7));
        if (allEvents.length > 7) expect(allEvents[7].value, equals(8));
      });
    });
  }
}
