import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Attribute of an entity.
///
/// An [Attribute] represents a property of an entity and can be updated via
/// an [Event].
@immutable
class Attribute {
  /// Symbols identifying an attribute.
  final List<Symbol> _symbols;

  const Attribute(this._symbols);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attribute &&
          const ListEquality().equals(this._symbols, other._symbols));

  @override
  int get hashCode => _symbols.hashCode;

  bool get isEmpty => _symbols.isEmpty;

  @override
  String toString() => 'Attribute{$_symbols}';
}

/// Event is the most basic element of knowledge about a certain domain which
/// allows the state of the system to be constructed over time.
@immutable
class Event {
  /// key identifying the entity this event affects.
  final String key;

  /// the attribute affected by this event.
  final Attribute attribute;

  /// the new value of the attribute. If null, the attribute is removed.
  final dynamic value;

  /// the instant at which the event happened. Defaults to the current time.
  final DateTime instant;

  Event(this.key, this.attribute, this.value, [DateTime instant])
      : instant = instant ?? DateTime.now();

  @override
  String toString() {
    return 'Event{key: $key, attribute: $attribute, value: $value, instant: $instant}';
  }
}

/// A [Sink] of [Event]s.
///
/// It is used to publish events.
abstract class EventSink extends Sink<Event> {}

/// A source of [Event]s.
///
/// It is used to retrieve events.
mixin EventSource {
  /// Get the value for an [Attribute] of an entity with the given key,
  /// at the given instant.
  ///
  /// If no instant is given, the current instant is used.
  ///
  /// If no entity with the given key exists, or it has no such attribute at
  /// the relevant instant, null is returned.
  dynamic getValue(String key, Attribute attribute, [DateTime instant]);

  /// Get the entity with the given key.
  ///
  /// An entity is built up from all of the events that have affected it up
  /// to the given instant (current instant by default). Each event sets or
  /// unsets the value for an attribute, so over time an entity may have
  /// several attributes, where each one has the value set by the latest event
  /// affecting it.
  ///
  /// If no event has ever affected an entity with the given key, an empty
  /// [Map] is returned.
  Map<Attribute, dynamic> getEntity(String key, [DateTime instant]);
}
