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
class InMemoryEventSink extends EventorySink with LiveEventSource {
  final Map<String, EventList> _db = {};

  Stream<Event> _all({DateTime from, DateTime to}) async* {
    final all = _db.values.expand((e) => e.partial(from: from, to: to));
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
  Map<String, dynamic> getEntity(String key, [DateTime instant]) {
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
  Future<EventSource> partial({DateTime from, DateTime to}) async {
    final result = InMemoryEventSink();
    final batch = <Event>[];
    await for (var event in _all(from: from, to: to)) {
      batch.add(event);
      if (batch.length == 100) {
        result.addBatch(batch);
        batch.clear();
      }
    }
    result.addBatch(batch);
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
    return InMemoryEntitiesSnapshot(instant, result);
  }
}

class InMemoryEntitiesSnapshot implements EntitiesSnapshot {
  final Map<String, Map<String, dynamic>> _entities;
  final DateTime instant;

  InMemoryEntitiesSnapshot(this.instant, [this._entities = const {}]);

  @override
  Set<String> get keys => _entities.keys.toSet();

  int get length => _entities.length;

  @override
  Map<String, dynamic> operator [](String key) => _entities[key];
}
