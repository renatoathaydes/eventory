import 'dart:async';

import 'package:collection/collection.dart';
import 'package:eventory/src/snapshot_map.dart';
import 'package:eventory/src/util.dart';

import 'event_list.dart';
import 'eventory_base.dart';

/// A simple in-memory [EventorySink] and [EventSource].
///
/// Implementation is kept as simple as possible intentionally, so that more
/// advanced capabilities can be built on top of it.
///
/// Most of the time, users will prefer to use more those more advanced
/// implementations instead of this one directly, as they might offer trade-offs
/// that are more appropriate for the intended usage, such as caching for fast
/// queries (at the cost of memory).
class InMemoryEventSink extends EventorySink with EventSource {
  final Map<String, EventList> _db = {};

  // FIXME must return events in order by instant
  Stream<Event> _all({Set<String> keys, DateTime from, DateTime to}) async* {
    var all = _db.values.expand((e) => e.partial(from: from, to: to));
    if (keys?.isNotEmpty ?? false) {
      // TODO may be faster to only go through the entries for the keys
      all = all.where((e) => keys.contains(e.key));
    }
    for (var event in all) {
      yield event;
    }
  }

  @override
  void add(Event event) {
    assertNotClosed();
    _db.putIfAbsent(event.key, () => EventList()).add(event);
  }

  @override
  void addBatch(Iterable<Event> events) {
    assertNotClosed();
    for (var event in events) {
      _db.putIfAbsent(event.key, () => EventList()).add(event);
    }
  }

  @override
  dynamic getValue(String key, String attribute, [DateTime instant]) {
    return _db[key]?.findEvent(attribute: attribute, instant: instant)?.value;
  }

  @override
  Future<Map<String, dynamic>> getEntity(String key, [DateTime instant]) async {
    instant ??= DateTime.now();
    final result = Map<String, dynamic>();
    final events =
        _db[key]?.all?.takeWhile((event) => event.instant.isBefore(instant)) ??
            const [];
    events.forEach((event) => result[event.attribute] = event.value);
    return result;
  }

  @override
  Stream<Event> get allEvents => _all();

  @override
  Future<EventSource> partial(
      {Set<String> keys = const {}, DateTime from, DateTime to}) async {
    final result = InMemoryEventSink();
    await for (var event in _all(keys: keys, from: from, to: to)) {
      result.add(event);
    }
    return result;
  }

  @override
  Future<InMemoryEntitiesSnapshot> getSnapshot([DateTime instant]) async {
    instant ??= DateTime.now();
    final result = Map<String, Map<String, dynamic>>();
    for (var key in _db.keys) {
      final entity = await Future(() => getEntity(key, instant));
      if (entity.isNotEmpty) {
        result[key] = entity;
      }
    }
    return InMemoryEntitiesSnapshot(instant, UnmodifiableMapView(result));
  }
}

class InMemoryEntitiesSnapshot implements EntitiesSnapshot {
  final UnmodifiableMapView<String, Map<String, dynamic>> _entities;
  final DateTime instant;

  InMemoryEntitiesSnapshot(
      this.instant, UnmodifiableMapView<String, Map<String, dynamic>> entities)
      : _entities = entities;

  InMemoryEntitiesSnapshot.fromEvents(List<Event> events,
      [InMemoryEntitiesSnapshot previousSnapshot])
      : this(events.last.instant, _entitiesIn(events, previousSnapshot));

  static Map<String, dynamic> _combineEntities(
          Map<String, dynamic> top, Map<String, dynamic> bottom) =>
      CombinedMapView([top, bottom]);

  static UnmodifiableMapView<String, Map<String, dynamic>> _copy(
      EntitiesSnapshot snapshot, Map<String, Map<String, dynamic>> into) {
    if (snapshot is InMemoryEntitiesSnapshot) {
      into.addAll(snapshot._entities);
    } else {
      snapshot.keys.forEach((key) {
        into[key] = snapshot[key];
      });
    }
    return UnmodifiableMapView(into);
  }

  static UnmodifiableMapView<String, Map<String, dynamic>> _entitiesIn(
      List<Event> events, InMemoryEntitiesSnapshot previousSnapshot) {
    final result = <String, Map<String, dynamic>>{};
    for (final event in events) {
      result.putIfAbsent(event.key, () => {})[event.attribute] = event.value;
    }
    if (previousSnapshot == null) {
      return UnmodifiableMapView(result);
    } else {
      return SnapshotMap(
        result,
        previousSnapshot._entities,
        _combineEntities,
      ).view;
    }
  }

  @override
  Set<String> get keys => _entities.keys.toSet();

  int get length => _entities.length;

  @override
  Map<String, dynamic> operator [](String key) => _entities[key] ?? const {};

  @override
  InMemoryEntitiesSnapshot operator +(EntitiesSnapshot other) {
    return InMemoryEntitiesSnapshot(mostRecentOf(instant, other.instant),
        _copy(other, {}..addAll(_entities)));
  }
}
