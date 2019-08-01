import 'dart:io';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';
import 'package:test/test.dart';

Future<FileEventSource> createEventSource({String contents}) async {
  final dir = await Directory.systemTemp.createTemp('file_event_source_test');
  final tempFile = File("${dir.path}/my_test.txt");
  if (contents?.isNotEmpty ?? false) {
    await tempFile.writeAsString(contents);
  } else {
    await tempFile.create();
  }
  return await FileEventSource.load(tempFile);
}

void main() {
  group('FileEventSource loading empty File', () {
    FileEventSource source;
    setUp(() async {
      source = await createEventSource();
    });

    test('has no content', () {
      expect(source.getValue('hello', Attribute(['p1', 'p2'])), isNull);
      expect(source.getValue('hello', Attribute(['p1'])), isNull);
      expect(source.getValue('hello', Attribute(['a'])), isNull);
      expect(source.getValue('bye', Attribute(['a'])), isNull);
    });
  });

  group('FileEventSource loading a single Event', () {
    FileEventSource source;
    setUp(() async {
      source = await createEventSource(
          contents: '"2010-02-03T00:00:00.000","hello",["p1","p2"],42\n');
    });

    test('has contents as expected', () {
      expect(source.getValue('hello', Attribute(['p1', 'p2'])), equals(42));

      expect(source.getValue('hello', Attribute(['p1'])), isNull);
      expect(source.getValue('hello', Attribute(['a'])), isNull);
      expect(source.getValue('bye', Attribute(['a'])), isNull);
    });
  });

  group('FileEventSource loading a single Event and some batched Events', () {
    FileEventSource source;
    setUp(() async {
      source = await createEventSource(
          contents: '"2010-02-03T00:00:00.000","hello",["p1","p2"],42\n'
              '["2010-02-03T00:00:00.000","hello",["a"],"A",'
              '"2010-02-03T00:00:00.000","hello",["b"],"B",'
              '"2010-02-04T00:00:00.000","hello",["c"],"C",'
              '"2010-02-05T00:00:00.000","bye",["d"],"DD",'
              '"2010-02-06T00:00:00.000","bye",["e"],"EE",'
              '"2010-02-07T00:00:00.000","bye",["f"],"FF"]\n');
    });

    test('has contents as expected', () {
      expect(source.getValue('hello', Attribute(['p1', 'p2'])), equals(42));
      expect(source.getValue('hello', Attribute(['a'])), equals('A'));
      expect(source.getValue('hello', Attribute(['b'])), equals('B'));
      expect(source.getValue('hello', Attribute(['c'])), equals('C'));
      expect(source.getValue('bye', Attribute(['d'])), equals('DD'));
      expect(source.getValue('bye', Attribute(['e'])), equals('EE'));
      expect(source.getValue('bye', Attribute(['f'])), equals('FF'));

      expect(source.getValue('hello', Attribute(['DD'])), isNull);
      expect(source.getValue('bye', Attribute(['a'])), isNull);
      expect(source.getValue('other', Attribute(['a'])), isNull);
    });
  });

  group('FileEventSource loading bad file', () {
    test('with random contents', () {
      expect(() async {
        await createEventSource(contents: 'askfjtjgelreptlkjer');
      },
          throwsA(isA<EventDecodingException>().having(
              (e) => e.cause?.toString(),
              'cause',
              startsWith('FormatException'))));
    });
    test('with single event with too many components', () {
      expect(() async {
        await createEventSource(
            contents: '"2010-02-03T00:00:00.000","hello",["p1"],42,43');
      },
          throwsA(isA<EventDecodingException>()
              .having((e) => e.cause, 'cause', equals('Too many components'))));
    });
    test('with single event with invalid instant', () {
      expect(() async {
        await createEventSource(contents: '"hi","hello",["p1"],42,43');
      },
          throwsA(isA<EventDecodingException>().having(
              (e) => e.cause,
              'cause',
              startsWith('Invalid instant component: '
                  'FormatException: Invalid date format'))));
    });
    test('with single event with invalid key', () {
      expect(() async {
        await createEventSource(
            contents: '"2010-02-03T00:00:00.000",234,["p1"],42');
      },
          throwsA(isA<EventDecodingException>().having(
              (e) => e.cause,
              'cause',
              equals("Invalid key component: "
                  "type 'int' is not a subtype of type 'String' in type cast"))));
    });
    test('with single event with invalid Attribute (not List)', () {
      expect(() async {
        await createEventSource(
            contents: '"2010-02-03T00:00:00.000","a",41,42');
      },
          throwsA(isA<EventDecodingException>().having(
              (e) => e.cause,
              'cause',
              equals("Invalid attribute component: "
                  "type 'int' is not a subtype of type 'List<dynamic>' in type cast"))));
    });
    test('with single event with invalid Attribute (List item)', () {
      expect(() async {
        await createEventSource(
            contents: '"2010-02-03T00:00:00.000","a",[41],42');
      },
          throwsA(isA<EventDecodingException>().having((e) => e.cause, 'cause',
              equals("Invalid attribute component: item is not a String"))));
    });
  });
}
