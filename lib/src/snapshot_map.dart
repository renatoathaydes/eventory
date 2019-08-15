import 'dart:collection';

import 'package:collection/collection.dart';

class SnapshotMap<K, V> extends UnmodifiableMapBase<K, V> {
  final Map<K, V> topMap;
  final Map<K, V> bottomMap;
  final V Function(V top, V bottom) combine;

  SnapshotMap(this.topMap, this.bottomMap, this.combine);

  UnmodifiableMapView<K, V> get view => UnmodifiableMapView(this);

  @override
  Iterable<K> get keys {
    return topMap.keys
        .followedBy(bottomMap.keys.where((k) => !topMap.containsKey(k)));
  }

  @override
  int get length => keys.length;

  @override
  V operator [](Object key) {
    final top = topMap[key];
    final bottom = bottomMap[key];
    if (top == null) return bottom;
    if (bottom == null) return top;
    return combine(top, bottom);
  }
}
