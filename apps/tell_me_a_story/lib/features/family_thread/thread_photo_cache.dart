import 'dart:typed_data';

/// About one screen of built beats. P4a leaves the capacity unnamed.
const threadPhotoCacheCapacity = 24;

class ThreadPhotoCache {
  ThreadPhotoCache({this.capacity = threadPhotoCacheCapacity})
    : assert(capacity > 0);

  final int capacity;
  final _entries = <String, Uint8List>{};

  static String keyFor(String path, int editVersion) => '$path#$editVersion';

  int get length => _entries.length;

  Uint8List? read(String key) {
    final hit = _entries.remove(key);
    if (hit == null) return null;
    _entries[key] = hit;
    return hit;
  }

  void put(String key, Uint8List bytes) {
    _entries.remove(key);
    _entries[key] = bytes;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}
