import 'event_list.dart';
import 'eventory_base.dart';

/// A simple in-memory [EventSink] and [EventSource].
class InMemoryEventSink extends EventSink with EventSource {
  final Map<String, EventList> _db = {};

  @override
  void add(Event event) {
    _db.putIfAbsent(event.key, () => EventList()).add(event);
  }

  @override
  void close() {
    // no op
  }

  @override
  dynamic getValue(String key, Attribute attribute, [DateTime instant]) {
    return _db[key]?.findEvent(attribute: attribute, instant: instant)?.value;
  }
}
