import 'package:eventory/eventory.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryEventSink with a few events', () {
    InMemoryEventSink sink;
    setUp(() {
      sink = InMemoryEventSink();

      // given some events
      sink.add(Event('joe', const Attribute([#age]), 24));
      sink.add(Event('mary', const Attribute([#age]), 26));
      sink.add(Event('adam', const Attribute([#age]), 53));
      sink.add(
          Event('joe', const Attribute([#address, #street]), 'High Street'));
      sink.add(Event('joe', const Attribute([#address, #street_number]), 32));
      sink.add(
          Event('mary', const Attribute([#address, #street]), 'Low Street'));
      sink.add(Event('mary', const Attribute([#address, #street_number]), 423));

      // updates Joe's address
      sink.add(
          Event('joe', const Attribute([#address, #street]), 'Medium Street'));
      sink.add(Event('joe', const Attribute([#address, #street_number]), 12));
    });

    test('can use simple event lookup', () {
      expect(sink.getValue('joe', Attribute([#age])), equals(24));
      expect(sink.getValue('mary', const Attribute([#age])), equals(26));
      expect(sink.getValue('adam', const Attribute([#age])), equals(53));

      expect(sink.getValue('joe', const Attribute([#number])), isNull);
      expect(sink.getValue('joe', const Attribute([#address])), isNull);
      expect(sink.getValue('other', const Attribute([#age])), isNull);
      expect(sink.getValue('other', const Attribute([#xxx])), isNull);
    });

    test('can see updates', () {
      expect(sink.getValue('joe', Attribute([#address, #street])),
          equals('Medium Street'));
      expect(sink.getValue('joe', Attribute([#address, #street_number])),
          equals(12));
      expect(sink.getValue('mary', const Attribute([#address, #street])),
          equals('Low Street'));
      expect(sink.getValue('mary', const Attribute([#address, #street_number])),
          equals(423));
    });
  });
}
