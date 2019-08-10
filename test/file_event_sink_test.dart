import 'dart:io';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';
import 'package:test/test.dart';

void main() {
  group('FileEventSink writes', () {
    FileEventSink sink;
    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('file_event_sink_test');
      final tempFile = File("${dir.path}/my_test.txt");
      sink = FileEventSink(tempFile);
    });

    test('simple event', () async {
      await sink.add(Event('hello', "p1/p2", 42, DateTime.parse('2010-02-03')));
      await sink.close();
      final fileContents = await sink.file.readAsString();

      expect(fileContents, equals(//
          '"2010-02-03T00:00:00.000","hello","p1/p2",42\n'));
    });

    test('batched events', () async {
      await sink.add(Event('hello', "p1/p2", 42, DateTime.parse('2010-02-03')));
      await sink.addBatch([
        Event('hello', 'a', "A", DateTime.parse('2010-02-03')),
        Event('hello', 'b', "B", DateTime.parse('2010-02-03')),
        Event('hello', 'c', "C", DateTime.parse('2010-02-04')),
        Event('bye', 'd', "DD", DateTime.parse('2010-02-05')),
        Event('bye', 'e', "EE", DateTime.parse('2010-02-06')),
        Event('bye', 'f', "FF", DateTime.parse('2010-02-07')),
      ]);
      await sink.close();

      final fileContents = await sink.file.readAsString();

      expect(
          fileContents,
          equals(//
              '"2010-02-03T00:00:00.000","hello","p1/p2",42\n'
              '["2010-02-03T00:00:00.000","hello","a","A",'
              '"2010-02-03T00:00:00.000","hello","b","B",'
              '"2010-02-04T00:00:00.000","hello","c","C",'
              '"2010-02-05T00:00:00.000","bye","d","DD",'
              '"2010-02-06T00:00:00.000","bye","e","EE",'
              '"2010-02-07T00:00:00.000","bye","f","FF"]\n'));
    });
  });
}
