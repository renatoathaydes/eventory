import 'dart:async';

import 'package:collection/collection.dart';
import 'package:eventory/eventory.dart';

/// An [EventSource] backed by a delegate [EventSource] which attempts to make
/// queries faster by keeping internal snapshots of the data contained in the
/// delegate.
class SnapshotBackedEventSource with EventSource {
  final List<InMemoryEntitiesSnapshot> _snapshots;
  final InMemoryEventSource _delegate;

  SnapshotBackedEventSource._create(this._snapshots, this._delegate);

  static Future<SnapshotBackedEventSource> load(Stream<Event> events,
      {int eventsPerSnapshot = 1000}) async {
    final snapshots = <InMemoryEntitiesSnapshot>[];
    final sink = InMemoryEventSink();
    final batch = List<Event>(eventsPerSnapshot);
    var index = 0;
    InMemoryEntitiesSnapshot snapshot;
    await events.forEach((event) {
      sink.add(event);
      batch[index] = event;
      index++;
      if (index == eventsPerSnapshot) {
        snapshot = InMemoryEntitiesSnapshot.fromEvents(batch, snapshot);
        snapshots.add(snapshot);
        index = 0;
      }
    });
    if (index > 0) {
      snapshots.add(InMemoryEntitiesSnapshot.fromEvents(
          batch.sublist(0, index), snapshot));
    }
    return SnapshotBackedEventSource._create(
        snapshots, await sink.toEventSource());
  }

  InMemoryEntitiesSnapshot _latestSnapshotAt(DateTime instant) =>
      _snapshots.reversed
          .firstWhere((s) => s.instant.isBefore(instant), orElse: () => null);

  @override
  Future<Map<String, dynamic>> getEntity(String key, [DateTime instant]) async {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      final entityFromSnapshot = latestSnapshot[key];
      final updatesSinceSnapshot =
          await partial(keys: {key}, from: latestSnapshot.instant, to: instant);
      final entityUpdates = await updatesSinceSnapshot.getEntity(key, instant);
      return CombinedMapView([entityUpdates, entityFromSnapshot]);
    } else {
      // snapshot is not helpful here, just ask the delegate
      return await _delegate.getEntity(key, instant);
    }
  }

  @override
  Future<InMemoryEntitiesSnapshot> getSnapshot([DateTime instant]) async {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      final sinceSnapshot =
          await partial(from: latestSnapshot.instant, to: instant);
      return latestSnapshot + await sinceSnapshot.getSnapshot(instant);
    }
    return _delegate.getSnapshot(instant);
  }

  @override
  FutureOr getValue(String key, String attribute, [DateTime instant]) async {
    instant ??= DateTime.now();
    final latestSnapshot = _latestSnapshotAt(instant);
    if (latestSnapshot != null) {
      final updatesSinceSnapshot =
          await partial(keys: {key}, from: latestSnapshot.instant, to: instant);
      return await updatesSinceSnapshot.getValue(key, attribute, instant) ??
          (latestSnapshot[key] ?? const {})[attribute];
    } else {
      return await _delegate.getValue(key, attribute, instant);
    }
  }

  @override
  Stream<Event> get allEvents => _delegate.allEvents;

  @override
  FutureOr<EventSource> partial(
          {Set<String> keys, DateTime from, DateTime to}) =>
      _delegate.partial(keys: keys, from: from, to: to);
}
