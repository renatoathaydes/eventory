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
      case 'block':
        print("Blocking until Enter is pressed");
        stdin.readLineSync();
        print("Unblocked.");
        break;
      case 'benchmark':
        await benchmark(sink, args);
        break;
      case 'help':
        print('''
Available commands:
  event [<key> <value>] - publish a random event with optional key-value
  print - print the event log
  benchmark [<event_count> <await> <flush>] - run a benchmark:
              event_count - number of events to create.
              await       - whether to await on each event.
              flush       - whether to flush at the end.
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

void benchmark(FileEventSink sink, List<String> args) async {
  final eventCount = args.isEmpty ? 1000 : int.parse(args[0]);
  final doAwait = args.length <= 1 ? false : boolParse(args[1]);
  final doFlush = args.length <= 2 ? false : boolParse(args[2]);

  print("Generating $eventCount events");
  final events = Iterable.generate(
      eventCount, (_) => Event(randomString(), 'val', randomString())).toList();
  final lastEvent = events.removeLast();
  print("Writing events...");
  final watch = Stopwatch()..start();
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
  watch.stop();
  print("Wrote $eventCount events in ${watch.elapsedMilliseconds} millis.");
}

bool boolParse(String s) => s.toLowerCase() == 'true';
