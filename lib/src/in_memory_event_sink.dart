import 'event_list.dart';
import 'eventory_base.dart';

/// A simple in-memory [EventSink] and [EventSource].
class InMemoryEventSink extends EventSink with EventSource {
  final Map<String, EventList> _db = {};

  Iterable<Event> _all({DateTime from, DateTime to}) =>
      _db.values.expand((e) => e.partial(from: from, to: to));

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
  dynamic getValue(String key, Attribute attribute, [DateTime instant]) {
    return _db[key]?.findEvent(attribute: attribute, instant: instant)?.value;
  }

  @override
  Map<Attribute, dynamic> getEntity(String key, [DateTime instant]) {
    instant ??= DateTime.now();
    final result = Map<Attribute, dynamic>();
    final events =
        _db[key]?.all?.takeWhile((event) => event.instant.isBefore(instant)) ??
            const [];
    events.forEach((event) => result[event.attribute] = event.value);
    return result;
  }

  @override
  Stream<Event> get allEvents {
    return Stream.fromIterable(_all().toList(growable: false));
  }

  @override
  EventSource partial({DateTime from, DateTime to}) =>
      InMemoryEventSink()..addBatch(_all(from: from, to: to));

  @override
  InMemoryEntitiesSnapshot getSnapshot([DateTime instant]) {
    instant ??= DateTime.now();
    final result = Map<String, Map<Attribute, dynamic>>();
    _db.keys.forEach((key) {
      final entity = getEntity(key, instant);
      if (entity.isNotEmpty) {
        result[key] = entity;
      }
    });
    return InMemoryEntitiesSnapshot(result);
  }
}

class InMemoryEntitiesSnapshot implements EntitiesSnapshot {
  final Map<String, Map<Attribute, dynamic>> _entities;

  InMemoryEntitiesSnapshot(this._entities);

  @override
  Set<String> get keys => _entities.keys.toSet();

  int get length => _entities.length;

  @override
  Map<Attribute, dynamic> operator [](String key) => _entities[key];
}
