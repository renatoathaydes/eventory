import 'dart:async';
import 'dart:collection';

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
class InMemoryEventSink extends EventorySink {
  final _events = DoubleLinkedQueue<Event>();

//  final List<DoubleLinkedQueue<Event>>

  @override
  void add(Event event) {
    assertNotClosed();
    _events.add(event);
  }

  @override
  void addBatch(Iterable<Event> events) {
    assertNotClosed();
    for (var event in events) {
      _events.add(event);
    }
  }

  @override
  Future<InMemoryEventSource> toEventSource() async {
    // TODO ensure concurrent modification of the _events list does not break this method
    return InMemoryEventSource.from(Stream.fromIterable(_events));
  }
}

class InMemoryEventSource with EventSource {
  final EventList _events;
  final UnmodifiableMapView<String, EventList> _db;

  InMemoryEventSource._create(this._events, this._db);

  static Future<InMemoryEventSource> from(Stream<Event> events) async {
    final eventList = EventList();
    final db = <String, EventList>{};
    await for (final event in events) {
      eventList.add(event);
      db.putIfAbsent(event.key, () => EventList()).add(event);
    }
    return InMemoryEventSource._create(eventList, UnmodifiableMapView(db));
  }

  @override
  dynamic getValue(String key, String attribute, [DateTime instant]) {
    return _db[key]?.findEvent(attribute: attribute, instant: instant)?.value;
  }

  @override
  Future<Map<String, dynamic>> getEntity(String key, [DateTime instant]) async {
    instant ??= DateTime.now();
    final events = _db[key]?.partial(to: instant) ?? const [];
    final result = Map<String, dynamic>();
    events.forEach((event) => result[event.attribute] = event.value);
    return result;
  }

  @override
  Stream<Event> get allEvents => Stream.fromIterable(_events.all);

  @override
  Future<EventSource> partial(
      {Set<String> keys = const {}, DateTime from, DateTime to}) async {
    Iterable<Event> events;
    if (keys?.isNotEmpty ?? false) {
      events = keys
          .map((k) => _db[k])
          .where((e) => e != null)
          .expand((e) => e.partial(from: from, to: to));
    } else {
      events = _events.partial(from: from, to: to);
    }
    return InMemoryEventSource.from(Stream.fromIterable(events));
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
