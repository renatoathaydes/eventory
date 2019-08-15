import 'package:eventory/src/snapshot_map.dart';
import 'package:test/test.dart';

int combiner(int a, int b) => a + b;

void main() {
  test('SnapshotMap can be empty', () {
    final map = SnapshotMap(<int, int>{}, <int, int>{}, combiner);
    expect(map.isEmpty, isTrue);
    expect(map.length, equals(0));
  });

  test('SnapshotMap can contain elements in only bottom map', () {
    final map = SnapshotMap<String, int>({}, {'1': 1, '2': 2}, combiner);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(2));
    expect(map.keys.toList(), equals(['1', '2']));
    expect(map.values.toList(), equals([1, 2]));
    expect(map.containsKey('1'), isTrue);
    expect(map.containsKey('2'), isTrue);
    expect(map.containsKey('3'), isFalse);
    expect(map['1'], equals(1));
    expect(map['2'], equals(2));
    expect(map['3'], isNull);
  });

  test('SnapshotMap can contain elements in only top map', () {
    final map = SnapshotMap<String, int>({'1': 1, '2': 2}, {}, combiner);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(2));
    expect(map.keys.toList(), equals(['1', '2']));
    expect(map.values.toList(), equals([1, 2]));
    expect(map.containsKey('1'), isTrue);
    expect(map.containsKey('2'), isTrue);
    expect(map.containsKey('3'), isFalse);
    expect(map['1'], equals(1));
    expect(map['2'], equals(2));
    expect(map['3'], isNull);
  });

  test('SnapshotMap can contain elements in both maps', () {
    final map = SnapshotMap<String, int>({'1': 1}, {'2': 2}, combiner);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(2));
    expect(map.keys.toList(), equals(['1', '2']));
    expect(map.values.toList(), equals([1, 2]));
    expect(map.containsKey('1'), isTrue);
    expect(map.containsKey('2'), isTrue);
    expect(map.containsKey('3'), isFalse);
    expect(map['1'], equals(1));
    expect(map['2'], equals(2));
    expect(map['3'], isNull);
  });

  test('SnapshotMap - top Map combines with bottom Map elements', () {
    final map = SnapshotMap<String, int>(
        {'1': 1, '2': 2, '3': 3}, {'2': 22, '4': 44}, combiner);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(4));
    expect(map.keys.toList(), equals(['1', '2', '3', '4']));
    expect(map.values.toList(), equals([1, 24, 3, 44]));
    expect(map['1'], equals(1));
    expect(map['2'], equals(24));
    expect(map['3'], equals(3));
    expect(map['4'], equals(44));
  });

  test('SnapshotMap - members can also be SnapshotMap', () {
    final topMap = SnapshotMap<String, int>(
        {'1': 1, '2': 2}, {'2': 22, '4': 44}, combiner);
    final bottomMap = SnapshotMap<String, int>({'1': 11, '3': 3}, // keep line
        {'1': 111, '4': 4, '5': 5}, combiner);
    final map = SnapshotMap<String, int>(topMap, bottomMap, combiner);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(5));
    expect(map.keys.toList(), equals(['1', '2', '4', '3', '5']));
    expect(map.values.toList(), equals([123, 24, 48, 3, 5]));
    expect(map['1'], equals(123));
    expect(map['2'], equals(24));
    expect(map['3'], equals(3));
    expect(map['4'], equals(48));
    expect(map['5'], equals(5));
  });
}
