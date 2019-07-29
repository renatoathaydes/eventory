import 'dart:collection';

import 'package:eventory/eventory.dart';

import 'eventory_base.dart';

typedef _AttributeLookup = bool Function(Event event);

/// A List of [Event] assumed to share the same key.
///
/// Events can bee looked up by attribute and instant.
class EventList {
  final _events = SplayTreeMap<DateTime, List<Event>>();

  void add(Event event) {
    _events.putIfAbsent(event.instant, () => []).add(event);
  }

  Iterable<Event> get all => _events.values.expand((e) => e);

  Event findEvent({Attribute attribute, DateTime instant}) {
    instant ??= DateTime.now();
    final attributeMatches = _attributeLookupFunction(attribute);
    while (true) {
      final at = _events.lastKeyBefore(instant);
      if (at == null) return null;
      final events = _events[at];
      final result = events.firstWhere(attributeMatches, orElse: () => null);
      if (result != null) {
        return result;
      }

      // continue search from the previous instant
      instant = at;
    }
  }

  _AttributeLookup _attributeLookupFunction(Attribute attribute) {
    if (attribute == null || attribute.isEmpty) {
      return (e) => true;
    } else {
      return (e) => e.attribute == attribute;
    }
  }
}
