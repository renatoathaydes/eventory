import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:actors/actors.dart';
import 'package:eventory/eventory.dart';
import 'package:eventory/src/file_event_sink.dart';

enum MonitorCommand { start, stop, ping }

/// Monitor the EventLoop of the CLI never becomes unresponsive.
///
/// The CLI Isolate sends a ping every second to the Monitor, which will
/// show an error if it doesn't receive two consecutive pings within 2 seconds.
class Monitor with Handler<MonitorCommand, void> {
  int monitorTick = 0;
  Timer timer;

  void handle(MonitorCommand signal) {
    switch (signal) {
      case MonitorCommand.start:
        int tick = monitorTick;
        timer?.cancel();
        timer = Timer.periodic(Duration(seconds: 2), (timer) {
          // monitor tick should have changed since last run!
          if (tick == monitorTick) {
            print("WARN: EventLoop has been blocked for some time!");
          } else {
//            print("Monitor: OK");
          }
          tick = monitorTick;
        });
        break;
      case MonitorCommand.stop:
        timer?.cancel();
        break;
      case MonitorCommand.ping:
        monitorTick++;
        break;
    }
  }
}

void main() async {
  final monitorActor = Actor(Monitor());
  await monitorActor.send(MonitorCommand.start);
  final ping = Timer.periodic(
      Duration(seconds: 1), (t) => monitorActor.send(MonitorCommand.ping));
  try {
    await startCliLoop(monitorActor);
  } finally {
    print("Bye!");
    ping.cancel();
    await monitorActor.send(MonitorCommand.stop);
    await monitorActor.close();
  }
}

void startCliLoop(Actor<MonitorCommand, void> monitorActor) async {
  final dir = await Directory.systemTemp.createTemp('eventory_file_example_');
  final tempFile = File("${dir.path}/my_test.txt");
  print("Events file: ${tempFile.path}");

  var sink = FileEventSink(tempFile);
  var source = await FileEventSource.load(tempFile);

  stdout.write('> ');
  loop:
  await for (final line
      in await stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final parts = line.split(" ");
    final command = parts[0];
    final args = parts.skip(1).toList();
    switch (command) {
      case 'event':
        await sink.add(Event(args.isEmpty ? randomString() : args[0], 'val',
            args.length > 1 ? args.skip(1).join(' ') : randomString()));
        break;
      case 'print':
        var readFrom = max(0, await tempFile.length() - 10000);
        await (await tempFile.openRead(readFrom))
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach(print);
        break;
      case 'flush':
        await sink.flush();
        break;
      case 'close':
        await sink.close();
        break;
      case 'reload':
        final time = await withTimer(
            () async => source = await FileEventSource.load(tempFile));
        print("Loaded FileEventSource in ${time.inMilliseconds} ms.");
        break;
      case 'query':
        if (args.isEmpty) {
          print("ERROR: provide at least the entity key to query.");
        } else {
          final time = await withTimer(() => print(source.getEntity(args[0])));
          print("Query took ${time.inMilliseconds} ms");
        }
        break;
      case 'block':
        print("Blocking until Enter is pressed");
        stdin.readLineSync();
        print("Unblocked.");
        break;
      case 'rb':
      case 'read-benchmark':
        await readBenchmark(source);
        break;
      case 'wb':
      case 'write-benchmark':
        await writeBenchmark(sink, args);
        break;
      case 'help':
        print('''
Available commands:
  event [<key> <value>] - publish a random event with optional key-value
  print - print the event log
  reload - reload all events from the file.
  query <key> - query event source
  read-benchmark (rb) - run a read benchmark
  write-benchmark (wb) [<event_count> <await> <flush>] - run a write benchmark:
              event_count - number of events to create
              await       - whether to await on each event
              flush       - whether to flush at the end
  flush - flush the FileEventSink
  close - close the FileEventSink
  block - block the event loop
  exit  - exit the program
  help  - print this message        
        ''');
        break;
      case 'exit':
        break loop;
      default:
        print("Unknown command: $command");
    }
    stdout.write('> ');
  }
}

final rand = Random();

String randomString() => Iterable.generate(
        rand.nextInt(30) + 2, (c) => String.fromCharCode(rand.nextInt(25) + 65))
    .join();

Future<void> readBenchmark(EventSource source) async {
  Event first, last;
  int count = 0;

  await for (var event in source.allEvents) {
    if (first == null) {
      first = event;
    }
    last = event;
    count++;
  }
  if (count < 2) {
    print("ERROR: Not enough events to benchmark");
    return;
  }
  var firstValue, lastValue;
  final firstValTime = await withTimer(() {
    firstValue = source.getValue(first.key, first.attribute, first.instant);
  });
  final lastValTime = await withTimer(() {
    lastValue = source.getValue(last.key, last.attribute, last.instant);
  });
  print("Total events: ${count}.");
  print("Time to get first value: ${firstValTime.inMicroseconds}e-6 seconds.");
  print("Time to get last value: ${lastValTime.inMicroseconds}e-6 seconds.");
  if (firstValue != first.value) {
    print("ERROR: First value was not correct:"
        "\nActual: ${firstValue}"
        "\nExpected: ${first.value}");
  }
  if (lastValue != last.value) {
    print("ERROR: Last value was not correct:"
        "\nActual: ${lastValue}"
        "\nExpected: ${last.value}");
  }
}

Future<void> writeBenchmark(FileEventSink sink, List<String> args) async {
  final eventCount = args.isEmpty ? 1000 : int.parse(args[0]);
  final doAwait = args.length <= 1 ? false : boolParse(args[1]);
  final doFlush = args.length <= 2 ? false : boolParse(args[2]);

  print("Generating $eventCount events");
  final events = Iterable.generate(
      eventCount, (_) => Event(randomString(), 'val', randomString())).toList();
  final lastEvent = events.removeLast();
  print("Writing events...");
  final time = await withTimer(() async {
    for (var event in events) {
      if (doAwait) {
        await sink.add(event);
      } else {
        sink.add(event);
      }
    }
    if (!doAwait) print("Awaiting on last event...");
    await sink.add(lastEvent);
    if (doFlush) {
      print("Awaiting on flush...");
      await sink.flush();
    }
  });
  print("Wrote $eventCount events in ${time.inMilliseconds} millis.");
}

bool boolParse(String s) => s.toLowerCase() == 'true';

Future<Duration> withTimer(FutureOr Function() callback) async {
  final watch = Stopwatch()..start();
  await callback();
  watch.stop();
  return watch.elapsed;
}
