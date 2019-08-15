import 'dart:io';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';

void main(List<String> args) async {
  int eventsPerCycle = args.isNotEmpty ? int.parse(args[0]) : 100000;
  int batchSize = args.length > 1 ? int.parse(args[1]) : 0;
  print(
      "Creating $eventsPerCycle events${batchSize > 0 ? ' using batches of $batchSize events' : ''}");

  var events = <Event>[];
  for (var i = 0; i < eventsPerCycle; i++) {
    events.add(Event(i.toString(), 'value', i));
  }

  final dir = await Directory.systemTemp.createTemp('file_example');
  final tempFile = File("${dir.path}/my_test.txt");
  final watch = Stopwatch();
  var sink = FileEventSink(tempFile);

  print("Starting to write events to file ${tempFile.path}.");

  watch.start();
  if (batchSize > 0) {
    await sendEventsInBatches(events, sink, batchSize);
  } else {
    await sendEventsOneByOne(events, sink);
  }
  print(
      "Done sending events in ${watch.elapsedMilliseconds} ms. Flushing events.");

  // will close and wait for file handle to get flushed
  await sink.close();
  watch.stop();

  events = null;
  sink = null;

  print("All events written in ${watch.elapsedMilliseconds} ms total.");
  print("Write throughput: "
      "${(await tempFile.length()).toDouble() * 1.0e-6 /
      (watch.elapsed.inMilliseconds * 1e-3)}"
      " MB/sec");

  print("Checking for correctness...");
  final source = await FileEventSource.load(tempFile);

  for (var i = 0; i < eventsPerCycle; i++) {
    final entity = await source.getEntity(i.toString());
    if (entity['value'] != i) {
      throw Exception("Error, expected entity with value $i, got $entity");
    }
  }
  print("OK!");
}

void sendEventsOneByOne(List<Event> events, Sink<Event> sink) async {
  for (var event in events) {
    await sink.add(event);
  }
}

void sendEventsInBatches(
    List<Event> events, EventorySink sink, int batchSize) async {
  final batch = <Event>[];
  for (var i = 0; i < events.length; i++) {
    batch.add(events[i]);
    if (i != 0 && i % batchSize == 0) {
      await sink.addBatch(batch);
      batch.clear();
    }
  }
  await sink.addBatch(batch);
}
