import 'event_list.dart';
import 'eventory_base.dart';

/// A simple in-memory [EventSink] and [EventSource].
class InMemoryEventSink extends EventSink with EventSource {
  final Map<String, EventList> _db = {};

  @override
  void add(Event event) {
    assertNotClosed();
    _db.putIfAbsent(event.key, () => EventList()).add(event);
  }

  @override
  dynamic getValue(String key, Attribute attribute, [DateTime instant]) {
    return _db[key]?.findEvent(attribute: attribute, instant: instant)?.value;
  }

  @override
  Map<Attribute, dynamic> getEntity(String key, [DateTime instant]) {
    instant ??= DateTime.now();
    final result = <Attribute, dynamic>{};
    final events =
        _db[key]?.all?.takeWhile((event) => event.instant.isBefore(instant)) ??
            const [];
    events.forEach((event) => result[event.attribute] = event.value);
    return result;
  }

  @override
  Stream<Event> get allEvents {
    return Stream.fromIterable(
        _db.values.expand((e) => e.all).toList(growable: false));
  }
}
