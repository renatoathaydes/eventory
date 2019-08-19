import 'dart:math';

import 'package:eventory/eventory.dart';

const eventCount = 1e6;
const fields = ['value', 'other', 'example', 'test'];

final rand = Random();

String randomString() => Iterable.generate(
        rand.nextInt(30) + 2, (c) => String.fromCharCode(rand.nextInt(25) + 65))
    .join();

void main() async {
  final watch = Stopwatch();
  final restart = () => watch
    ..reset()
    ..start();

  var events = List<Event>(eventCount.toInt());

  print("Generating random events");
  watch.start();
  for (int i = 0; i < eventCount; i++) {
    events[i] = Event(i.toString(), fields[i % fields.length], randomString());
  }
  watch.stop();
  print(
      "Created ${eventCount.toInt()} events in ${watch.elapsedMilliseconds} ms.");

  print("Sample events:\n${events.sublist(0, 10)}\n"
      "${events.sublist(eventCount.toInt() - 10, eventCount.toInt() - 1)}");

  final sink = InMemoryEventSink();

  print("Sending events to ${sink}");
  restart();
  events.forEach(sink.add);
  watch.stop();
  print("Done in ${watch.elapsedMilliseconds} ms.");

  print("Creating a new EventSource from the sink");
  restart();
  final source = await sink.toEventSource();
  watch.stop();
  print("Done in ${watch.elapsedMilliseconds} ms.");

  print("Querying entities in ${source}");
  restart();
  final firstEntity = await source.getEntity("0");
  watch.stop();
  print("Entity at the beginning of the source took "
      "${watch.elapsedMicroseconds} us to find: ${firstEntity}");
  restart();
  final middleEntity =
      await source.getEntity((eventCount.toInt() ~/ 2).toString());
  watch.stop();
  print("Entity at the middle of the source took "
      "${watch.elapsedMicroseconds} us to find: ${middleEntity}");
  restart();
  final endEntity = await source.getEntity((eventCount.toInt() - 2).toString());
  watch.stop();
  print("Entity at the end of the source took "
      "${watch.elapsedMicroseconds} us to find: ${endEntity}");
  restart();
  final firstEntity2 = await source.getEntity("10");
  watch.stop();
  print("Entity near the beginning of the source took "
      "${watch.elapsedMicroseconds} us to find: ${firstEntity2}");
}
