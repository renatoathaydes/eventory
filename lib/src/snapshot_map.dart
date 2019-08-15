import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:eventory/src/util.dart';

// TODO remove this once https://github.com/dart-lang/collection/pull/110 is merged
class SnapshotMap<K, V> extends CombinedMapView<K, V> {
  Iterable<K> Function() _lazyKeys;

  SnapshotMap(Map<K, V> topMap, Map<K, V> bottomMap)
      : super([topMap, bottomMap]) {
    values;
    _lazyKeys = lazy(() => super.keys.toSet());
  }

  UnmodifiableMapView<K, V> get view => UnmodifiableMapView(this);

  @override
  Iterable<K> get keys => _lazyKeys();

  @override
  int get length => keys.length;
}
