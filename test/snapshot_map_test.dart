import 'package:eventory/src/snapshot_map.dart';
import 'package:test/test.dart';

void main() {
  test('SnapshotMap can be empty', () {
    final map = SnapshotMap({}, {});
    expect(map.isEmpty, isTrue);
    expect(map.length, equals(0));
  });

  test('SnapshotMap can contain elements in only bottom map', () {
    final map = SnapshotMap({}, {'1': 1, '2': 2});
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
    final map = SnapshotMap({'1': 1, '2': 2}, {});
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
    final map = SnapshotMap({'1': 1}, {'2': 2});
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

  test('SnapshotMap - top Map overrides bottom Map elements', () {
    final map = SnapshotMap({'1': 1, '2': 2, '3': 3}, {'2': 22, '4': 44});
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(4));
    expect(map.keys.toList(), equals(['1', '2', '3', '4']));
    expect(map.values.toList(), equals([1, 2, 3, 44]));
    expect(map['1'], equals(1));
    expect(map['2'], equals(2));
    expect(map['3'], equals(3));
    expect(map['4'], equals(44));
  });

  test('SnapshotMap - members can also be SnapshotMap', () {
    final topMap = SnapshotMap({'1': 1, '2': 2}, {'2': 22, '4': 44});
    final bottomMap = SnapshotMap({'1': 11, '3': 3}, // keep line
        {'1': 111, '4': 4, '5': 5});
    final map = SnapshotMap(topMap, bottomMap);
    expect(map.isEmpty, isFalse);
    expect(map.length, equals(5));
    expect(map.keys, equals({'1', '2', '3', '4', '5'}));
    expect(map.values.toSet(), equals({1, 2, 3, 44, 5}));
    expect(map['1'], equals(1));
    expect(map['2'], equals(2));
    expect(map['3'], equals(3));
    expect(map['4'], equals(44));
    expect(map['5'], equals(5));
  });
}
