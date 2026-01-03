import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_value.dart';

/// Base class for all T3 runtime objects.
///
/// Each metaclass has its own subclass that implements the specific
/// data format and behavior for that metaclass type.
abstract class T3Object {
  /// The unique object ID assigned by the compiler.
  final int objectId;

  /// The metaclass name (e.g., "tads-object", "string", "list").
  final String metaclass;

  /// Whether this is a transient object (not saved in saved games).
  final bool isTransient;

  T3Object({required this.objectId, required this.metaclass, this.isTransient = false});

  /// Gets a property value by property ID.
  ///
  /// Returns null if the property is not defined on this object.
  T3Value? getProperty(int propId);

  /// Sets a property value by property ID.
  ///
  /// Throws if the property cannot be set on this object type.
  void setProperty(int propId, T3Value value);

  /// Returns info about this object for debugging.
  Map<String, dynamic> get debugInfo;
}

/// Property value in a TADS object, stored with original image data.
class T3ObjectProperty {
  /// The property ID.
  final int propId;

  /// The property value.
  final T3Value value;

  T3ObjectProperty(this.propId, this.value);

  @override
  String toString() => 'prop($propId: $value)';
}

/// TADS Object - the standard object type with superclasses and properties.
///
/// This is the most common metaclass used in TADS programs. It stores:
/// - A list of superclass object IDs for inheritance
/// - Properties from the load image (immutable)
/// - Modified properties (changed at runtime)
///
/// Image file data format:
/// - UINT2: Superclass count
/// - UINT2: Load image property count
/// - UINT2: Object flags (0x0001 = isClass)
/// - UINT4 × N: Superclass object IDs
/// - For each property:
///   - UINT2: Property ID
///   - DATAHOLDER (5 bytes): Property value
///
/// See spec section "The TADS Object Metaclass".
class T3TadsObject extends T3Object {
  /// Object flag: this object represents a class, not an instance.
  static const int flagIsClass = 0x0001;

  /// Superclass object IDs, in search order.
  final List<int> superclasses;

  /// Properties loaded from the image file (immutable).
  final List<T3ObjectProperty> loadImageProperties;

  /// Properties modified at runtime.
  final Map<int, T3Value> modifiedProperties = {};

  /// Object flags from the image file.
  final int flags;

  T3TadsObject({
    required super.objectId,
    required this.superclasses,
    required this.loadImageProperties,
    required this.flags,
    super.isTransient,
  }) : super(metaclass: 'tads-object');

  /// Whether this object represents a class definition.
  bool get isClass => (flags & flagIsClass) != 0;

  /// Number of superclasses.
  int get superclassCount => superclasses.length;

  /// Number of properties in the load image.
  int get propertyCount => loadImageProperties.length;

  @override
  T3Value? getProperty(int propId) {
    // First check modified properties
    final modified = modifiedProperties[propId];
    if (modified != null) return modified;

    // Then search load image properties (sorted by propId for binary search)
    // For now, use linear search - can optimize later
    for (final prop in loadImageProperties) {
      if (prop.propId == propId) return prop.value;
    }

    return null;
  }

  @override
  void setProperty(int propId, T3Value value) {
    modifiedProperties[propId] = value;
  }

  /// Parses a TADS object from image file data.
  ///
  /// The [data] should be the metaclass-specific data from the OBJS block.
  factory T3TadsObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);

    // Read header
    final superclassCount = view.getUint16(0, Endian.little);
    final propCount = view.getUint16(2, Endian.little);
    final flags = view.getUint16(4, Endian.little);

    var offset = 6;

    // Read superclass IDs
    final superclasses = <int>[];
    for (var i = 0; i < superclassCount; i++) {
      superclasses.add(view.getUint32(offset, Endian.little));
      offset += 4;
    }

    // Read properties
    final properties = <T3ObjectProperty>[];
    for (var i = 0; i < propCount; i++) {
      final propId = view.getUint16(offset, Endian.little);
      offset += 2;

      final value = T3Value.fromPortable(data, offset);
      offset += T3Value.portableSize;

      properties.add(T3ObjectProperty(propId, value));
    }

    return T3TadsObject(
      objectId: objectId,
      superclasses: superclasses,
      loadImageProperties: properties,
      flags: flags,
      isTransient: isTransient,
    );
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'isClass': isClass,
    'isTransient': isTransient,
    'superclasses': superclasses,
    'propertyCount': propertyCount,
    'modifiedCount': modifiedProperties.length,
  };

  @override
  String toString() =>
      'T3TadsObject(#$objectId, ${isClass ? "class" : "instance"}, supers: $superclassCount, props: $propertyCount)';
}

/// String object - immutable character string.
///
/// Strings in T3 are typically stored in the constant pool, but
/// dynamically created strings use this metaclass.
///
/// Data format:
/// - UINT2: String length in bytes
/// - bytes: String content (UTF-8 or other encoding)
class T3StringObject extends T3Object {
  /// The string content.
  final String text;

  T3StringObject({required super.objectId, required this.text, super.isTransient}) : super(metaclass: 'string');

  @override
  T3Value? getProperty(int propId) {
    // String metaclass methods would be handled here
    return null;
  }

  @override
  void setProperty(int propId, T3Value value) {
    throw UnsupportedError('String objects are immutable');
  }

  /// Parses a string object from image file data.
  factory T3StringObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final length = view.getUint16(0, Endian.little);
    final textBytes = data.sublist(2, 2 + length);
    final text = String.fromCharCodes(textBytes);

    return T3StringObject(objectId: objectId, text: text, isTransient: isTransient);
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'length': text.length,
    'text': text.length > 50 ? '${text.substring(0, 50)}...' : text,
  };

  @override
  String toString() => 'T3StringObject(#$objectId, "${text.length > 20 ? '${text.substring(0, 20)}...' : text}")';
}

/// List object - immutable ordered collection.
///
/// Like strings, lists are typically stored in the constant pool,
/// but dynamically created lists use this metaclass.
///
/// Data format:
/// - UINT2: Element count
/// - DATAHOLDER × N: Elements
class T3ListObject extends T3Object {
  /// The list elements.
  final List<T3Value> elements;

  T3ListObject({required super.objectId, required this.elements, super.isTransient}) : super(metaclass: 'list');

  /// Number of elements.
  int get length => elements.length;

  @override
  T3Value? getProperty(int propId) {
    // List metaclass methods would be handled here
    return null;
  }

  @override
  void setProperty(int propId, T3Value value) {
    throw UnsupportedError('List objects are immutable');
  }

  /// Parses a list object from image file data.
  factory T3ListObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final count = view.getUint16(0, Endian.little);

    final elements = <T3Value>[];
    var offset = 2;
    for (var i = 0; i < count; i++) {
      elements.add(T3Value.fromPortable(data, offset));
      offset += T3Value.portableSize;
    }

    return T3ListObject(objectId: objectId, elements: elements, isTransient: isTransient);
  }

  @override
  Map<String, dynamic> get debugInfo => {'objectId': objectId, 'metaclass': metaclass, 'length': length};

  @override
  String toString() => 'T3ListObject(#$objectId, $length elements)';
}

/// Vector object - mutable ordered collection.
///
/// Unlike List, Vector is mutable and can be resized.
///
/// Data format (from reference VM vmvec.cpp):
/// - UINT2: Allocated size
/// - UINT2: Element count
/// - DATAHOLDER × N: Elements
class T3VectorObject extends T3Object {
  /// The vector elements.
  final List<T3Value> elements;

  /// Allocated capacity.
  int allocatedSize;

  T3VectorObject({required super.objectId, required this.elements, required this.allocatedSize, super.isTransient})
    : super(metaclass: 'vector');

  /// Number of elements.
  int get length => elements.length;

  @override
  T3Value? getProperty(int propId) {
    // Vector metaclass methods would be handled here
    return null;
  }

  @override
  void setProperty(int propId, T3Value value) {
    // TODO: Implement vector property setting
    throw UnimplementedError('Vector property setting not yet implemented');
  }

  /// Parses a vector object from image file data.
  factory T3VectorObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    // Note: allocated count comes FIRST, then element count (per reference VM)
    final allocated = view.getUint16(0, Endian.little);
    final count = view.getUint16(2, Endian.little);

    final elements = <T3Value>[];
    var offset = 4;
    for (var i = 0; i < count; i++) {
      elements.add(T3Value.fromPortable(data, offset));
      offset += T3Value.portableSize;
    }

    return T3VectorObject(objectId: objectId, elements: elements, allocatedSize: allocated, isTransient: isTransient);
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'length': length,
    'allocated': allocatedSize,
  };

  @override
  String toString() => 'T3VectorObject(#$objectId, $length elements, alloc: $allocatedSize)';
}

/// Generic/unknown object for metaclasses we don't have specific implementations for.
///
/// Stores the raw data for potential future parsing.
class T3GenericObject extends T3Object {
  /// The raw metaclass-specific data.
  final Uint8List rawData;

  T3GenericObject({required super.objectId, required super.metaclass, required this.rawData, super.isTransient});

  @override
  T3Value? getProperty(int propId) {
    // Unknown metaclass - can't access properties
    return null;
  }

  @override
  void setProperty(int propId, T3Value value) {
    throw UnsupportedError('Cannot set properties on unknown metaclass: $metaclass');
  }

  @override
  Map<String, dynamic> get debugInfo => {'objectId': objectId, 'metaclass': metaclass, 'dataSize': rawData.length};

  @override
  String toString() => 'T3GenericObject(#$objectId, $metaclass, ${rawData.length} bytes)';
}
