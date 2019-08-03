class EventDecodingException implements Exception {
  final Object cause;

  const EventDecodingException(this.cause);

  @override
  String toString() {
    return 'EventDecodingException{$cause}';
  }
}

class ClosedException implements Exception {
  const ClosedException();

  @override
  String toString() => 'ClosedException';
}
