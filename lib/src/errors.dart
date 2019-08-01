class EventDecodingException implements Exception {
  final cause;

  const EventDecodingException(this.cause);

  @override
  String toString() {
    return 'EventDecodingException{$cause}';
  }
}
