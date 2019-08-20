import 'dart:math';

import 'package:eventory/eventory.dart';
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
  final watch = Stopwatch();
  final restart = () => watch
    ..reset()
    ..start();

  var events = List<Event>(eventCount.toInt());
  print(DateTime.now());
  var t = DateTime.parse("1990-01-01 08:00:00");

  print("Generating random events");
  watch.start();
  for (int i = 0; i < eventCount; i++) {
    events[i] = Event(i.toString(), fields[i % fields.length], randomString(),
        t.add(Duration(seconds: i)));
    if (verbose && i == eventCount.toInt() - 1) {
      print("LAST EVENT: ${events[i]}");
    }
  }
  watch.stop();
  print(
      "Created ${eventCount.toInt()} events in ${watch.elapsedMilliseconds} ms.");

  if (verbose) {
    print("Sample events:\n${events.sublist(0, 10)}\n"
        "${events.sublist(eventCount.toInt() - 10, eventCount.toInt())}");
  }

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

  // warmup run
  var time = await _averageMicroSecondsRunningGetEntity(source, firstIndex: 0);

  time = await _averageMicroSecondsRunningGetEntity(source, firstIndex: 0);
  print("Entity at the beginning of the source took $time us to find");
  time = await _averageMicroSecondsRunningGetEntity(source,
      firstIndex: eventCount.toInt() ~/ 2);
  print("Entity at the middle of the source took $time us to find");
  time = await _averageMicroSecondsRunningGetEntity(source,
      firstIndex: eventCount.toInt() - 10);
  print("Entity at the end of the source took $time us to find");
}

Future<int> _averageMicroSecondsRunningGetEntity(EventSource source,
    {int firstIndex, int count = 10}) async {
  final totalTime = await withTimer(() async {
    for (var i = firstIndex; i < count + firstIndex; i++) {
      final entity = await source.getEntity(i.toString());
      if (verbose) {
        print("Key = $i => $entity");
      }
    }
  });
  return totalTime.inMicroseconds ~/ count;
}
