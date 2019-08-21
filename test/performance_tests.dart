import 'dart:math';

import 'package:eventory/eventory.dart';
import 'package:eventory/src/snapshot_backed_event_source.dart';
import 'package:eventory/src/util.dart';

const eventCount = 1e6;
const fields = ['value', 'other', 'example', 'test'];

final rand = Random();
bool verbose = false;

String randomString() => Iterable.generate(
        rand.nextInt(30) + 2, (c) => String.fromCharCode(rand.nextInt(25) + 65))
    .join();

void main(List<String> args) async {
  if (args.isNotEmpty && args[0] == '--verbose') {
    verbose = true;
  }

  final keys = ['joe', 'longer key example', 'mary', 'adam', 'bob', 'lisa'];

  var events = List<Event>(eventCount.toInt());
  final date = DateTime.parse("1990-01-01 08:00:00");

  print("Generating random events");
  var t = await withTimer(() {
    for (int i = 0; i < eventCount; i++) {
      events[i] = Event(keys[i % keys.length], fields[i % fields.length],
          randomString(), date.add(Duration(seconds: i)));
    }
  });
  print("Created ${eventCount.toInt()} events in ${t.inMilliseconds} ms.");

  if (verbose) {
    print("Sample events:\n${events.sublist(0, 10)}\n"
        "${events.sublist(eventCount.toInt() - 10, eventCount.toInt())}");
  }

  EventorySink sink = InMemoryEventSink();

  await _runTests(events, sink, keys, date);

  print("Creating snapshot-backed EventSource from events");
  SnapshotBackedEventSource snapshotSource;
  t = await withTimer(() async => snapshotSource =
      await SnapshotBackedEventSource.load(Stream.fromIterable(events)));
  print("Done in ${t.inMilliseconds} ms.");

  await _runQueries(snapshotSource, keys, date);
}

Future<void> _runTests(List<Event> events, EventorySink sink, List<String> keys,
    DateTime initialTime) async {
  print("Sending events to ${sink}");
  var t = await withTimer(() => events.forEach(sink.add));
  print("Done in ${t.inMilliseconds} ms.");

  print("Creating a new EventSource from the sink");
  EventSource source;
  t = await withTimer(() async => source = await sink.toEventSource());
  print("Done in ${t.inMilliseconds} ms.");

  await _runQueries(source, keys, initialTime);
}

Future<void> _runQueries(
    EventSource source, List<String> keys, DateTime initialTime) async {
  print("Querying entities in ${source}");

  // warmup run
  var time =
      await _averageMicroSecondsRunningGetEntity(source, keys, DateTime.now());

  time = await _averageMicroSecondsRunningGetEntity(
      source, keys, initialTime.add(Duration(minutes: 5)));
  print("Entity at the beginning of the source took $time us to find");
  time = await _averageMicroSecondsRunningGetEntity(
      source, keys, initialTime.add(Duration(days: 4)));
  print("Entity at the middle of the source took $time us to find");
  time = await _averageMicroSecondsRunningGetEntity(
      source, keys, initialTime.add(Duration(days: 10)));
  print("Entity at the end of the source took $time us to find");
}

Future<int> _averageMicroSecondsRunningGetEntity(
    EventSource source, List<String> keys, DateTime time) async {
  const count = 10;
  final totalTime = await withTimer(() async {
    for (var i = 0; i < count; i++) {
      final key = keys[i % keys.length];
      final entity = await source.getEntity(key, time);
      if (verbose) {
        print("Key = $key => $entity");
      }
    }
  });
  return totalTime.inMicroseconds ~/ count;
}
