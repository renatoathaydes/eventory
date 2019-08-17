# Eventory

> Work in progress

An event sourcing-inspired library targeting offline-first use, with automatic synchronization with remote
instances when connection is available.

## Design Principles

* All events are acceptable. Errors are managed when _looking_ at the data, not when writing.
* Writers control the instant events happen.
* Event value serialization mechanism can be chosen by library users.
* EventSource is immutable and represents the state of the world at a precise moment in time.
* EventorySink must be able to write as fast as possible.
* Snapshots allow EventSources to be extremely efficient at querying data.
* EventSource and EventorySink are always separate entities even when using the same storage mechanism.
* Reloading an EventSource with new events from an EventorySink or remote stream must be extremely cheap.
