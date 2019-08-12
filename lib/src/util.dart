import 'dart:async' show FutureOr;

DateTime mostRecentOf(DateTime a, DateTime b) => a.isBefore(b) ? b : a;

Future<Duration> withTimer(FutureOr Function() callback) async {
  final watch = Stopwatch()..start();
  await callback();
  watch.stop();
  return watch.elapsed;
}
