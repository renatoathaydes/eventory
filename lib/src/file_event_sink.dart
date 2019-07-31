import 'dart:convert';
import 'dart:io';

import 'package:eventory/eventory.dart';

/// A Function that encodes an [Event]'s value to an [Object] which can be
/// persisted with [jsonEncode].
///
/// It must not contain new-line characters because each line in the file used
/// for persistence is expected to represent a single [Event] or batch of events.
typedef EventValueEncoder = Object Function(Object);

T _identity<T>(T value) => value;

class FileEventSink extends EventSink {
  final File file;
  final EventValueEncoder encodeValue;

  FileEventSink(this.file, {this.encodeValue = _identity});

  List _encodedList(Event event) => [
        event.instant.toIso8601String(),
        event.key,
        event.attribute.path,
        encodeValue(event.value)
      ];

  String _removeEndChars(String s) => s.substring(1, s.length - 1);

  Future<void> _writeln(String line) async {
    await file.writeAsString("$line\n", mode: FileMode.append, flush: true);
  }

  @override
  Future<void> add(Event event) async {
    final json = jsonEncode(_encodedList(event));
    await _writeln(_removeEndChars(json));
  }

  @override
  Future<void> addBatch(List<Event> events) async {
    if (events.isEmpty) return;
    final json = jsonEncode(
        events.map(_encodedList).expand(_identity).toList(growable: false));
    await _writeln(json);
  }
}
