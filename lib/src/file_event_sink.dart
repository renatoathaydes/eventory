import 'dart:convert';
import 'dart:io';

import 'package:eventory/eventory.dart';

typedef EventValueEncoder = Object Function(Object);

Object _identity(Object value) => value;

class FileEventSink extends InMemoryEventSink {
  final File file;
  final EventValueEncoder encoder;

  FileEventSink(this.file, {this.encoder = _identity});

  Future<void> init() async {
    final handle = await file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in handle) {
      await add(_parseLine(line));
    }
  }

  Event _parseLine(String line) {}

  @override
  Future<void> add(Event event) async {
    super.add(event);
    final jsonObject = [
      event.instant.toIso8601String(),
      event.key,
      // TODO serialize properly
      event.attribute.toString(),
      encoder(event.value)
    ];
    final json = jsonEncode(jsonObject);
    await file.writeAsString("${json.substring(1, json.length - 1)}\n");
  }

  @override
  void close() {
    // no op
  }

  @override
  dynamic getValue(String key, Attribute attribute, [DateTime instant]) {
    return super.getValue(key, attribute, instant);
  }

  @override
  Map<Attribute, dynamic> getEntity(String key, [DateTime instant]) {
    return super.getEntity(key, instant);
  }
}
