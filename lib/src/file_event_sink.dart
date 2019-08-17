import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eventory/eventory.dart';

/// A Function that encodes an [Event]'s value to an [Object] which can be
/// persisted with [jsonEncode].
///
/// It must not contain new-line characters because each line in the file used
/// for persistence is expected to represent a single [Event] or batch of events.
typedef EventValueEncoder = Object Function(Object);

/// A Function that decodes a persisted [Object] back to an [Event]'s value.
///
/// This function must perform the reverse operation of a [EventValueEncoder].
typedef EventValueDecoder = Object Function(Object);

T _identity<T>(T value) => value;

/// Adds support for some common types that the default jsonEncoder cannot
/// encode by itself.
Object _customJsonEncoder(Object value) {
  if (value is Set) {
    return value.toList(growable: false);
  }
  return value;
}

class FileEventSink extends EventorySink {
  final File file;
  final EventValueEncoder encodeValue;
  final IOSink _ioSink;

  FileEventSink(this.file, {this.encodeValue = _customJsonEncoder})
      : _ioSink = file.openWrite(mode: FileMode.append);

  void _write(String line) {
    _ioSink.write(line);
  }

  String _serializeEvent(Event event) {
    return '"${event.instant.toIso8601String()}",'
        '"${event.key}",'
        '"${event.attribute}",'
        '${jsonEncode(encodeValue(event.value))}';
  }

  @override
  void add(Event event) {
    assertNotClosed();
    _write("${_serializeEvent(event)}\n");
  }

  @override
  void addBatch(Iterable<Event> events) {
    assertNotClosed();
    if (events.isEmpty) return;
    // persist batched Events as a single JSON List where each 4 elements form
    // a single Event.
    final buffer = StringBuffer('[');
    buffer.write(_serializeEvent(events.first));
    for (final event in events.skip(1)) {
      buffer.write(',');
      buffer.write(_serializeEvent(event));
    }
    buffer.write(']\n');
    _write(buffer.toString());
  }

  Future<dynamic> flush() async {
    return _ioSink.flush();
  }

  @override
  Future<void> close() async {
    if (!isClosed) {
      super.close();
      await _ioSink.flush();
      await _ioSink.close();
    }
  }

  @override
  Future<FileEventSource> toEventSource() {
    return FileEventSource.load(file);
  }
}

/// An immutable [EventSource] obtained by loading events persisted by a
/// [FileEventSink] from a [File].
class FileEventSource with EventSource {
  final File file;
  final EventValueDecoder decodeValue;
  final InMemoryEventSource _delegate;

  FileEventSource._create(this.file, this.decodeValue, this._delegate);

  /// Load a [File] into a [FileEventSource].
  ///
  /// Throws a [EventDecodingException] if the contents of the file are invalid.
  static Future<FileEventSource> load(File file,
      {EventValueDecoder decodeValue = _identity}) async {
    return FileEventSource._create(
        file, decodeValue, await _load(file, decodeValue));
  }

  static Future<InMemoryEventSource> _load(
      File file, EventValueDecoder decodeValue) async {
    final events = await file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .expand((line) => _parseEvents(line, decodeValue));
    return await InMemoryEventSource.from(events);
  }

  static Event _decodeEventList(Iterator list, EventValueDecoder decodeValue) {
    // Example: ["2010-02-03T00:00:00.000","hello","p1/p2",42]
    DateTime instant;
    String key;
    String attribute;
    dynamic value;

    final moveNext = () {
      if (!list.moveNext()) {
        throw 'Event List representation contains wrong number of components';
      }
      return list.current;
    };

    try {
      instant = DateTime.parse(moveNext() as String);
    } catch (e) {
      throw 'Invalid instant component: $e';
    }
    try {
      key = moveNext() as String;
    } catch (e) {
      throw 'Invalid key component: $e';
    }
    try {
      attribute = moveNext() as String;
    } catch (e) {
      throw 'Invalid attribute component: $e';
    }
    try {
      value = decodeValue(moveNext());
    } catch (e) {
      throw 'Invalid value component: $e';
    }
    if (list.moveNext()) {
      throw 'Too many components';
    }
    return Event(key, attribute, value, instant);
  }

  static Iterable<Event> _parseEvents(
      String line, EventValueDecoder decodeValue) sync* {
    try {
      if (line.startsWith('[')) {
        // batched events line
        final persistedList = jsonDecode(line) as List;
        for (var i = 0; i < persistedList.length; i += 4) {
          yield _decodeEventList(
              persistedList.getRange(i, i + 4).iterator, decodeValue);
        }
      } else {
        // single event line
        final persistedList = jsonDecode("[$line]") as List;
        yield _decodeEventList(persistedList.iterator, decodeValue);
      }
    } catch (e) {
      throw EventDecodingException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getEntity(String key, [DateTime instant]) {
    return _delegate.getEntity(key, instant);
  }

  @override
  dynamic getValue(String key, String attribute, [DateTime instant]) {
    return _delegate.getValue(key, attribute, instant);
  }

  @override
  Stream<Event> get allEvents => _delegate.allEvents;

  @override
  Future<EntitiesSnapshot> getSnapshot([DateTime instant]) {
    return _delegate.getSnapshot(instant);
  }

  @override
  Future<EventSource> partial({Set<String> keys, DateTime from, DateTime to}) {
    return _delegate.partial(keys: keys, from: from, to: to);
  }
}
