import 'dart:async';

import 'package:eventory/eventory.dart';

/// An [EventSource] backed by a delegate [EventSource] which attempts to make
/// queries faster by keeping internal snapshots of the data contained in the
/// delegate.
class SnapshotBackedEventSource with EventSource {
  final EventSource _delegateSource;
  final List<EntitiesSnapshot> _snapshots = [];

  // TODO actually take snapshots
  SnapshotBackedEventSource(this._delegateSource);

  EntitiesSnapshot _latestSnapshotAt(DateTime instant) => _snapshots.reversed
      .firstWhere((s) => s.instant.isBefore(instant), orElse: () => null);

  @override
  Stream<Event> get allEvents => _delegateSource.allEvents;

  @override
  FutureOr<Map<String, dynamic>> getEntity(String key,
      [DateTime instant]) async {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      final entity = latestSnapshot[key];
      entity
          .addAll(await _delegateSource.getEntity(key, latestSnapshot.instant));
      return entity;
    } else {
      // snapshot is not helpful here, just ask the delegate
      return _delegateSource.getEntity(key, instant);
    }
  }

  @override
  FutureOr<EntitiesSnapshot> getSnapshot([DateTime instant]) async {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      final sinceSnapshot = await _delegateSource.partial(
          from: latestSnapshot.instant, to: instant);
      return latestSnapshot + await sinceSnapshot.getSnapshot(instant);
    }
    return _delegateSource.getSnapshot(instant);
  }

  @override
  FutureOr getValue(String key, String attribute, [DateTime instant]) {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      return (latestSnapshot[key] ?? const {})[attribute];
    } else {
      return _delegateSource.getValue(key, attribute, instant);
    }
  }

  @override
  FutureOr<EventSource> partial({DateTime from, DateTime to}) {
    return _delegateSource.partial(from: from, to: to);
  }
}
