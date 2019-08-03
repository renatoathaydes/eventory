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

  Iterable<Event> partial({DateTime from, DateTime to}) {
    if (from == null && to == null) {
      return all;
    }
    if (from == null) {
      return _events.values.expand((e) => e).takeWhile(
          (e) => e.instant.isBefore(to) || e.instant.isAtSameMomentAs(to));
    }
    if (to == null) {
      return _events.values
          .expand((e) => e)
          .skipWhile((e) => e.instant.isBefore(from));
    }
    // both from and to are non-null
    return _events.values
        .expand((e) => e)
        .skipWhile((e) => e.instant.isBefore(from))
        .takeWhile(
            (e) => e.instant.isBefore(to) || e.instant.isAtSameMomentAs(to));
  }

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
