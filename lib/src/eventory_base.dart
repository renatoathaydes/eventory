import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'errors.dart';

/// Attribute of an entity.
///
/// An [Attribute] represents a property of an entity and can be updated via
/// an [Event].
@immutable
class Attribute {
  /// Path of an attribute.
  ///
  /// Each path component must not contain the new-line or '/' characters.
  final List<String> path;

  String get pathString => path.join('/');

  /// Create an [Attribute] without checking the given path for invalid
  /// characters.
  const Attribute.unchecked(this.path);

  /// Create an [Attribute] with the given path.
  ///
  /// Throws [ArgumentError] if the path is invalid.
  Attribute(List<String> path) : path = path {
    if (path.contains('[/|\n|\r]')) {
      throw ArgumentError.value(
          path, 'path', "Path must not contain new-line or '/' characters");
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attribute &&
          const ListEquality().equals(this.path, other.path));

  @override
  int get hashCode => path.hashCode;

  bool get isEmpty => path.isEmpty;

  @override
  String toString() => 'Attribute{${pathString}';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          attribute == other.attribute &&
          value == other.value &&
          instant == other.instant;

  @override
  int get hashCode =>
      key.hashCode ^ attribute.hashCode ^ value.hashCode ^ instant.hashCode;

  @override
  String toString() {
    return 'Event{key: $key, attribute: $attribute, value: $value, instant: $instant}';
  }
}

/// A [Sink] of [Event]s.
///
/// It is used to publish events.
abstract class EventSink extends Sink<Event> {
  bool _closed = false;

  /// Add an event to this sink.
  ///
  /// Returns a [FutureOr] to allow for possibly async ack on writes.
  FutureOr add(Event event);

  /// Add a batch of events to this sink.
  ///
  /// Returns a [FutureOr] to allow for possibly async ack on writes.
  FutureOr addBatch(List<Event> events) async {
    for (var event in events) {
      await add(event);
    }
  }

  bool get isClosed => _closed;

  @protected
  void assertNotClosed() {
    if (isClosed) {
      throw const ClosedException();
    }
  }

  @mustCallSuper
  @override
  void close() {
    _closed = true;
  }
}

/// A source of [Event]s.
///
/// It is used to retrieve events.
mixin EventSource {
  /// All [Event]s known to this [EventSource] at the time this property
  /// is accessed.
  Stream<Event> get allEvents;

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
