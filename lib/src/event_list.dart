import 'dart:collection';

import 'package:eventory/eventory.dart';

import 'eventory_base.dart';

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

  Event findEvent({String attribute, DateTime instant}) {
    instant ??= DateTime.now();
    var at = instant;
    var events = _events[instant];
    while (true) {
      if (at == null) return null;
      events = _events[at];
      final result = events?.firstWhere((e) => e.attribute == attribute,
          orElse: () => null);
      if (result != null) {
        return result;
      }

      // continue search from the previous instant
      at = _events.lastKeyBefore(at);
    }
  }
}
