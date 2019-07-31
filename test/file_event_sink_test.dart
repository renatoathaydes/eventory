import 'dart:io';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';
import 'package:test/test.dart';

void main() {
  group('FileEventSink', () {
    FileEventSink sink;
    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('file_event_sink_test');
      final tempFile = File("${dir.path}/my_test.txt");
      sink = FileEventSink(tempFile);
    });

    test('can write simple event', () async {
      await sink.add(Event(
          'hello', Attribute(["p1", "p2"]), 42, DateTime.parse('2010-02-03')));
      final fileContents = await sink.file.readAsString();

      expect(fileContents, equals(//
          '"2010-02-03T00:00:00.000","hello",["p1","p2"],42\n'));
    });
  });
}
