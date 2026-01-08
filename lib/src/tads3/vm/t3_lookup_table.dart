import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Hashable key wrapper for T3Value.
///
/// Used as keys in T3LookupTable.
class T3ValueKey {
  final T3Value value;

  T3ValueKey(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! T3ValueKey) return false;
    return value.equals(other.value);
  }

  @override
  int get hashCode {
    // Basic hash code - precise hashing requires type-specific handling
    if (value.isStringLike || value.isList) {
      // For reference types without access to content, we use the ID/offset
      return Object.hash(value.type, value.value);
    }
    return Object.hash(value.type, value.value);
  }
}

/// LookupTable object - associative array (hash table).
///
/// TADS 3 LookupTable maps keys (any value) to values (any value).
/// Keys are hashed.
class T3LookupTable extends T3Object {
  // Underlying storage: simplified to Map for Dart.
  // We use T3ValueKey to ensure correct equality.
  final Map<T3ValueKey, T3Value> _data = {};

  /// Bucket count (from image data). Ignored for Dart implementation but kept for compatibility.
  final int bucketCount;

  /// Default value for missing keys.
  T3Value defaultValue = T3Value.nil();

  T3LookupTable({required super.objectId, required this.bucketCount, super.isTransient})
    : super(metaclass: 'lookuptable');

  /// Gets the number of entries.
  int get entryCount => _data.length;

  /// Sets a value.
  void set(T3Value key, T3Value value) {
    _data[T3ValueKey(key)] = value;
  }

  /// Gets a value. Returns defaultValue if not found.
  T3Value get(T3Value key) {
    return _data[T3ValueKey(key)] ?? defaultValue;
  }

  /// Checks if key exists.
  bool isKeyPresent(T3Value key) {
    return _data.containsKey(T3ValueKey(key));
  }

  /// Removes a key.
  void remove(T3Value key) {
    _data.remove(T3ValueKey(key));
  }

  /// Iterates over all entries.
  void forEach(void Function(T3Value key, T3Value value) callback) {
    _data.forEach((k, v) => callback(k.value, v));
  }

  /// Returns a list of all keys.
  List<T3Value> get keys => _data.keys.map((k) => k.value).toList();

  /// Returns a list of all values.
  List<T3Value> get values => _data.values.toList();

  /// Gets the Nth key (index is 1-based, but internal map order is... arbitrary?
  /// TADS 3 docs say: "The order of elements in a LookupTable is arbitrary."
  /// But `nthKey` expects *some* consistency if the table hasn't changed.
  T3Value nthKey(int index) {
    if (index < 1 || index > _data.length) return T3Value.nil();
    return _data.keys.elementAt(index - 1).value;
  }

  /// Gets the Nth value.
  T3Value nthVal(int index) {
    if (index < 1 || index > _data.length) return T3Value.nil();
    return _data.values.elementAt(index - 1);
  }

  /// Creates an iterator for this table.
  /// Returns a new T3IteratorObject (which needs to be registered).
  /// For now, we return a stub or implement the iterator logic.
  /// TADS 3 LookupTable iterator iterates over *entries*? Or keys?
  /// vmlookup.h: "LookupTableIterator"
  /// It seems to iterate over the association.
  /// Let's return a T3Value representing the iterator.
  /// Since we can't easily create a T3IteratorObject here without ObjectTable access,
  /// we might need to handle this in ExecutionHelpers or inject a factory.
  /// For now, we'll expose a method to get the data snapshot for the iterator.
  List<T3Value> getIteratorSnapshot() {
    // Usually TADS iterators on LookupTables iterate keys?
    // Let's assume keys for now, as that's typical for map iteration in some languages.
    // Wait, vmlookup.h:748 `get_next`
    // It returns the Next Value.
    // But `is_next_avail` checks index.
    // Let's implement T3LookupTableIterator in t3_object.dart or here.
    return keys;
  }

  @override
  T3Value? getProperty(int propId) {
    // Intrinsic methods are handled by the interpreter via T3ExecutionHelpers
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    // Properties on LookupTable itself (not the contents)
    // TADS 3 LookupTables don't have user-settable properties on the object itself usually.
    throw UnsupportedError('LookupTable properties are read-only');
  }

  /// Parses a LookupTable object from image file data.
  factory T3LookupTable.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final bucketCount = view.getUint16(0, Endian.little);
    final valueCount = view.getUint16(2, Endian.little);

    final table = T3LookupTable(objectId: objectId, bucketCount: bucketCount, isTransient: isTransient);

    var offset = 4;
    for (var i = 0; i < valueCount; i++) {
      final key = T3Value.fromPortable(data, offset);
      offset += T3Value.portableSize;
      final value = T3Value.fromPortable(data, offset);
      offset += T3Value.portableSize;
      table.set(key, value);
    }

    return table;
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'entryCount': entryCount,
    'buckets': bucketCount,
  };

  @override
  String toString() => 'T3LookupTable(#$objectId, $entryCount entries)';

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, bucketCount, Endian.little));
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, entryCount, Endian.little));

    forEach((key, value) {
      final keyBuf = Uint8List(5);
      key.toPortable(keyBuf, 0);
      builder.add(keyBuf);

      final valBuf = Uint8List(5);
      value.toPortable(valBuf, 0);
      builder.add(valBuf);
    });

    return builder.toBytes();
  }
}
