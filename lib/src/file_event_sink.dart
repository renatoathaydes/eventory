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
    assertNotClosed();
    final json = jsonEncode(_encodedList(event));
    // persist single Event by removing the '[' and ']' from the JSON String
    // as that is reserved for batched Events.
    await _writeln(_removeEndChars(json));
  }

  @override
  Future<void> addBatch(Iterable<Event> events) async {
    assertNotClosed();
    if (events.isEmpty) return;
    // persist batched Events as a single JSON List where each 4 elements form
    // a single Event.
    final json = jsonEncode(
        events.map(_encodedList).expand(_identity).toList(growable: false));
    await _writeln(json);
  }
}

/// An immutable [EventSource] obtained by loading events persisted by a
/// [FileEventSink] from a [File].
class FileEventSource with EventSource {
  final File file;
  final EventValueDecoder decodeValue;
  final InMemoryEventSink _delegate;

  FileEventSource._create(this.file, this.decodeValue, this._delegate);

  /// Load a [File] into a [FileEventSource].
  ///
  /// Throws a [EventDecodingException] if the contents of the file are invalid.
  static Future<FileEventSource> load(File file,
      {EventValueDecoder decodeValue = _identity}) async {
    final instance =
        FileEventSource._create(file, decodeValue, InMemoryEventSink());
    await instance._load();
    return instance;
  }

  Future<void> _load() async {
    await file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach(_addLine);
  }

  Attribute _decodeAttribute(List list) {
    final path = list.map((item) {
      try {
        return item as String;
      } catch (e) {
        throw "item is not a String";
      }
    }).toList(growable: false);
    return Attribute(path);
  }

  Event _decodeEventList(Iterator list) {
    // Example: ["2010-02-03T00:00:00.000","hello",["p1","p2"],42]
    DateTime instant;
    String key;
    Attribute attribute;
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
      attribute = _decodeAttribute(moveNext() as List);
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

  void _addLine(String line) {
    try {
      if (line.startsWith('[')) {
        // batched events line
        final persistedList = jsonDecode(line) as List;
        for (var i = 0; i < persistedList.length; i += 4) {
          _delegate
              .add(_decodeEventList(persistedList.getRange(i, i + 4).iterator));
        }
      } else {
        // single event line
        final persistedList = jsonDecode("[$line]") as List;
        _delegate.add(_decodeEventList(persistedList.iterator));
      }
    } catch (e) {
      throw EventDecodingException(e);
    }
  }

  @override
  Map<Attribute, dynamic> getEntity(String key, [DateTime instant]) {
    return _delegate.getEntity(key, instant);
  }

  @override
  dynamic getValue(String key, Attribute attribute, [DateTime instant]) {
    return _delegate.getValue(key, attribute, instant);
  }

  @override
  Stream<Event> get allEvents => _delegate.allEvents;

  @override
  EntitiesSnapshot getSnapshot([DateTime instant]) {
    return _delegate.getSnapshot(instant);
  }

  @override
  EventSource partial({DateTime from, DateTime to}) {
    return _delegate.partial(from: from, to: to);
  }
}
