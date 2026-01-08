import 'dart:convert';
import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Dictionary entry representation.
class T3DictEntry {
  final int objectId;
  final int propId;

  T3DictEntry(this.objectId, this.propId);
}

/// TADS 3 Dictionary Metaclass.
/// matches "dictionary2/030001"
class T3Dictionary extends T3Object {
  static const String metaclassName = 'dictionary2';

  /// Comparator object (T3Value, typically an object reference or One).
  /// Defaults to nil (no comparator).
  T3Value comparator = T3Value.nil();

  /// The dictionary content: keys map to lists of entries.
  /// Keys are stored in UTF-8 string format.
  final Map<String, List<T3DictEntry>> _entries = {};

  T3Dictionary({required super.objectId, super.isTransient = false})
    : super(metaclass: metaclassName);

  /// Creates a new dictionary.
  static T3Dictionary create(int objectId) {
    return T3Dictionary(objectId: objectId);
  }

  /// Restoration from saved data.
  /// Data format:
  /// UINT4 comparator_object_id
  /// UINT2 entry_count
  /// Entries...
  static T3Dictionary fromData(int objectId, Uint8List data) {
    final dict = T3Dictionary(objectId: objectId);
    final reader = ByteData.sublistView(data);
    var offset = 0;

    // 1. Comparator Object ID (UINT4)
    final compId = reader.getUint32(offset, Endian.little);
    offset += 4;
    if (compId != 0) {
      // Assuming 0 means nil/invalid for serialization
      // Actually TADS object IDs are non-zero.
      dict.comparator = T3Value.fromObject(compId);
    }

    // 2. Entry Count (UINT2)
    final entryCount = reader.getUint16(offset, Endian.little);
    offset += 2;

    // 3. Entries
    for (var i = 0; i < entryCount; i++) {
      // UCHAR key_byte_length
      final keyLen = reader.getUint8(offset);
      offset += 1;

      // Key String (XOR 0xBD)
      final keyBytes = Uint8List(keyLen);
      for (var k = 0; k < keyLen; k++) {
        keyBytes[k] = reader.getUint8(offset + k) ^ 0xBD;
      }
      offset += keyLen;
      // In practice TADS uses UTF-8, but with XOR obfuscation.
      final key = utf8.decode(keyBytes);

      // UINT2 sub-entry count
      final subCount = reader.getUint16(offset, Endian.little);
      offset += 2;

      final entries = <T3DictEntry>[];
      for (var j = 0; j < subCount; j++) {
        // UINT4 associated_object_id
        final objId = reader.getUint32(offset, Endian.little);
        offset += 4;

        // UINT2 defining_property_id
        final propId = reader.getUint16(offset, Endian.little);
        offset += 2;

        entries.add(T3DictEntry(objId, propId));
      }
      dict._entries[key] = entries;
    }

    return dict;
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    final scratch = ByteData(4);

    // 1. Comparator ID (UINT4)
    // If nil, write 0 (VM_INVALID_OBJ placeholder)
    int compId = 0;
    if (comparator.isObject) {
      compId = comparator.value;
    }
    scratch.setUint32(0, compId, Endian.little);
    builder.add(scratch.buffer.asUint8List());

    // 2. Entry Count (UINT2)
    scratch.setUint16(0, _entries.length, Endian.little);
    builder.add(scratch.buffer.asUint8List(0, 2));

    // 3. Entries
    for (final entry in _entries.entries) {
      final keyBytes = utf8.encode(entry.key);

      // UCHAR key length
      builder.addByte(keyBytes.length);

      // Key string (XOR 0xBD)
      for (final b in keyBytes) {
        builder.addByte(b ^ 0xBD);
      }

      // UINT2 sub-entry count
      final subEntries = entry.value;
      scratch.setUint16(0, subEntries.length, Endian.little);
      builder.add(scratch.buffer.asUint8List(0, 2));

      // Sub-entries
      for (final sub in subEntries) {
        // UINT4 obj ID
        scratch.setUint32(0, sub.objectId, Endian.little);
        builder.add(scratch.buffer.asUint8List());

        // UINT2 prop ID
        scratch.setUint16(0, sub.propId, Endian.little);
        builder.add(scratch.buffer.asUint8List(0, 2));
      }
    }

    return builder.toBytes();
  }

  /// Sets the comparator object.
  void setComparator(T3Value comp) {
    comparator = comp.copy();
  }

  /// Adds a word to the dictionary.
  void addWord(String str, int objId, int propId) {
    final list = _entries.putIfAbsent(str, () => []);
    // Check for duplicate
    for (final entry in list) {
      if (entry.objectId == objId && entry.propId == propId) return;
    }
    list.add(T3DictEntry(objId, propId));
  }

  /// Removes a word from the dictionary.
  void delWord(String str, int objId, int propId) {
    final list = _entries[str];
    if (list == null) return;
    list.removeWhere((e) => e.objectId == objId && e.propId == propId);
    if (list.isEmpty) {
      _entries.remove(str);
    }
  }

  /// Checks if a word is defined.
  bool isWordDefined(String str) {
    return _entries.containsKey(str);
  }

  /// Finds a word.
  List<T3DictEntry> findWord(String str) {
    return _entries[str] ?? [];
  }

  @override
  T3Value? getProperty(int propId) {
    // Dictionary has no accessible properties via property ID
    throw T3Exception('Dictionary: getProperty not supported for prop $propId');
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError(
      'Dictionary objects are immutable (via setProperty). Use intrinsic methods.',
    );
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'entries': _entries.length,
    'comparator': comparator.toString(),
  };
}
