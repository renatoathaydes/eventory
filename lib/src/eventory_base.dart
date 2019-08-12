import 'dart:async';

import 'package:meta/meta.dart';

import 'errors.dart';

/// Event is the most basic element of knowledge about a certain domain which
/// allows the state of the system to be constructed over time.
@immutable
class Event {
  /// key identifying the entity this event affects.
  final String key;

  /// the attribute affected by this event.
  final String attribute;

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
abstract class EventorySink extends Sink<Event> {
  bool _closed = false;

  /// Add an event to this sink.
  ///
  /// Returns a [FutureOr] to allow for possibly async ack on writes.
  FutureOr add(Event event);

  /// Add a batch of events to this sink.
  ///
  /// Returns a [FutureOr] to allow for possibly async ack on writes.
  FutureOr addBatch(Iterable<Event> events) async {
    for (var event in events) {
      await add(event);
    }
  }

  /// Returns a [StreamConsumer] that consumes events into this [EventorySink].
  StreamConsumer<Event> toStreamConsumer() {
    return _EventoryStreamConsumer(this);
  }

  /// Returns true if this [EventorySink] has been closed, false otherwise.
  bool get isClosed => _closed;

  @protected
  void assertNotClosed() {
    if (isClosed) {
      throw const ClosedException();
    }
  }

  /// Close this [EventorySink].
  @mustCallSuper
  @override
  FutureOr close() {
    _closed = true;
  }
}

class _EventoryStreamConsumer with StreamConsumer<Event> {
  final EventorySink sink;

  _EventoryStreamConsumer(this.sink);

  Future<void> addStream(Stream<Event> stream) async {
    final batch = <Event>[];
    const batchSize = 1024;
    await for (final event in stream) {
      batch.add(event);
      if (batch.length == batchSize) {
        await sink.addBatch(batch);
        batch.clear();
      }
    }
    await sink.addBatch(batch);
  }

  @override
  Future<void> close() async {}
}

/// A source of [Event]s.
///
/// It can be used to retrieve events and obtain the state of entities at certain
/// instants, which is re-constructed based on the events in this [EventSource].
///
/// If the state of the entities affected by events at a particular instant is
/// all that is of interest, a [EntitiesSnapshot] can be obtained, which can
/// be much more efficient for querying information.
mixin EventSource {
  /// All [Event]s known to this [EventSource] at the time this property
  /// is accessed.
  Stream<Event> get allEvents;

  /// Gets a snapshot of the state of the entities in this [EventSource] at
  /// a certain instant.
  ///
  /// If no instant is given, the current instant is used.
  FutureOr<EntitiesSnapshot> getSnapshot([DateTime instant]);

  /// Get the value for an attribute of an entity with the given key,
  /// at the given instant.
  ///
  /// If no instant is given, the current instant is used.
  ///
  /// If no entity with the given key exists, or it has no such attribute at
  /// the relevant instant, null is returned.
  FutureOr getValue(String key, String attribute, [DateTime instant]);

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
  FutureOr<Map<String, dynamic>> getEntity(String key, [DateTime instant]);

  /// Get a partial view of this [EventSource] containing all [Event]s within
  /// the time window given by the [from] and [to] instants.
  ///
  /// If [from] or [to] are not provided, the partial's time window is unbounded
  /// at the early or late edge, respectively.
  FutureOr<EventSource> partial({DateTime from, DateTime to});
}

/// A snapshot of all entities within an [EventSource] at a certain instant.
///
/// Snapshots provide all the information contained in an [EventSource] at
/// a single instant, but cannot look back or forth into the events which led
/// to that state. For this reason, they can be stored in a much more compact
/// format than a full [EventSource], and be more efficient at querying
/// information when only data at a certain instant matters.
mixin EntitiesSnapshot {
  /// The keys of all entities in this sna>pshot.
  Set<String> get keys;

  /// The number of entities in this snapshot.
  int get length;

  /// Get an entity's state from this snapshot by its key.
  ///
  /// Returns an empty [Map] if nothing is known about an entity with the given key.
  Map<String, dynamic> operator [](String key);
}
