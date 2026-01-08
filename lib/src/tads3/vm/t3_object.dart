import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';

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

  /// sets a property value by property ID.
  ///
  /// Throws if the property cannot be set on this object type.
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager});

  /// Returns info about this object for debugging.
  Map<String, dynamic> get debugInfo;

  /// Serializes the object-specific data to a byte array for saving.
  Uint8List save();
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
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    if (undoManager != null && undoManager.isActive) {
      final oldValue = getProperty(propId);
      undoManager.addRecord(T3UndoPropRecord(objectId, propId, oldValue));
    }
    modifiedProperties[propId] = value;
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();

    // Get all current property values (merging static and modified)
    final allProps = <int, T3Value>{};
    for (final p in loadImageProperties) {
      allProps[p.propId] = p.value;
    }
    allProps.addAll(modifiedProperties);

    // Header: flags(2), superclasses(2), properties(2)
    builder.add(Uint8List(6)..buffer.asByteData().setUint16(0, flags, Endian.little));
    // Note: superclasses are already at offset 2 in builder.
    // We'll fix them up after.

    builder.add(Uint8List(2)..buffer.asByteData().setUint16(2, superclasses.length, Endian.little));
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(4, allProps.length, Endian.little));

    // Superclasses
    for (final scId in superclasses) {
      builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, scId, Endian.little));
    }

    // Properties
    for (final entry in allProps.entries) {
      builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, entry.key, Endian.little));
      final valBuf = Uint8List(5);
      entry.value.toPortable(valBuf, 0);
      builder.add(valBuf);
    }

    return builder.toBytes();
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
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
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

  @override
  Uint8List save() {
    final bytes = Uint8List.fromList(text.codeUnits);
    final builder = BytesBuilder();
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, bytes.length, Endian.little));
    builder.add(bytes);
    return builder.toBytes();
  }
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
    // 68 is List.createIterator
    if (propId == 68) {
      // In a real VM we'd return a method pointer or similar.
      // But TADS3 often handles these as intrinsics or "metaclass methods".
      // We can return a special internal value or handle it in evalProperty.
      // HOWEVER, the error was "attempted to get property 68 of nil".
      // This implies we returned null here.
      // If we are to support `val.createIterator()`, we need to return something that IS callable.
      // But wait - usually intrinsic methods are called via OPC_CALLPROP.
      // If `getProperty` returns null, the VM might think the property doesn't exist.
      // Let's implement this by registering an intrinsic function?
      // Or, better yet, we might need a `T3IntrinsicMethodObject` if we want to return a "function".
      // But wait: `createIterator` IS a method.
      // If we return NULL, it means the property is missing.
      // We should perhaps return a special value that the interpreter knows how to invoke?
      // OR, simpler: The VM loop calls `evalProperty`. If we return null, it fails.
      // If we return a "function pointer", it calls it.
      // But `createIterator` is native code.
      // Let's try to handle this at the `execEvalProperty` level in execution_helpers.
      // Returning null here tells the lookup mechanism "not found".
      return null;
    }
    return null;
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, elements.length, Endian.little));
    for (final val in elements) {
      final buf = Uint8List(5);
      val.toPortable(buf, 0);
      builder.add(buf);
    }
    return builder.toBytes();
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
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

  /// Internal iterator index (1-based) for when Vector is used as an iterator.
  int iteratorIndex = 0;

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
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
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

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, allocatedSize, Endian.little));
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, length, Endian.little));
    for (final val in elements) {
      final buf = Uint8List(5);
      val.toPortable(buf, 0);
      builder.add(buf);
    }
    return builder.toBytes();
  }
}

/// Anonymous function pointer object.
///
/// Inherits from Vector. Element 0 is usually the method pointer (CodeOffset).
/// Elements 1..N are the closure environment.
class T3AnonFnObject extends T3VectorObject {
  T3AnonFnObject({required super.objectId, required super.elements, required super.allocatedSize, super.isTransient})
    : super();

  @override
  String get metaclass => 'anon-func-ptr';

  /// Parses an anonymous function object from image file data.
  factory T3AnonFnObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final vector = T3VectorObject.fromData(objectId, data, isTransient: isTransient);
    return T3AnonFnObject(
      objectId: objectId,
      elements: vector.elements,
      allocatedSize: vector.allocatedSize,
      isTransient: isTransient,
    );
  }

  @override
  String toString() => 'T3AnonFnObject(#$objectId, length: $length)';
}

/// Iterator object.
///
/// Used for iterating over collections. Supports both:
/// - Static element list (snapshot at creation time)
/// - Dynamic element getter (live access to collection)
class T3IteratorObject extends T3Object {
  final T3Value collection;
  final List<T3Value>? _staticElements;
  final List<T3Value> Function()? _elementGetter;
  int _index = 0;

  /// Creates iterator with static element list (snapshot).
  T3IteratorObject({
    required super.objectId,
    required this.collection,
    required List<T3Value> elements,
    super.isTransient,
  }) : _staticElements = elements,
       _elementGetter = null,
       super(metaclass: 'iterator');

  /// Creates iterator with dynamic element getter (live access).
  T3IteratorObject.live({
    required super.objectId,
    required this.collection,
    required List<T3Value> Function() elementGetter,
    super.isTransient,
  }) : _staticElements = null,
       _elementGetter = elementGetter,
       super(metaclass: 'iterator');

  /// Gets current elements (static or dynamic).
  List<T3Value> get elements => _elementGetter?.call() ?? _staticElements ?? [];

  @override
  T3Value? getProperty(int propId) {
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('Iterator properties are read-only');
  }

  /// Advances to next item and returns its value.
  T3Value getNext() {
    final elems = elements;
    if (_index < elems.length) {
      return elems[_index++];
    }
    return T3Value.nil();
  }

  bool isNextAvailable() => _index < elements.length;

  void reset() => _index = 0;

  T3Value getCurKey() => T3Value.fromInt(_index);

  T3Value getCurVal() {
    final elems = elements;
    if (_index > 0 && _index <= elems.length) {
      return elems[_index - 1];
    }
    return T3Value.nil();
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'collection': collection.toString(),
    'index': _index,
  };

  @override
  String toString() => 'T3IteratorObject(#$objectId, collection: $collection, index: $_index)';

  factory T3IteratorObject.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    var offset = 0;

    // Collection
    final collection = T3Value.fromPortable(data, offset);
    offset += T3Value.portableSize;

    // Index
    final index = view.getUint32(offset, Endian.little);
    offset += 4;

    // Has static elements?
    final hasStatic = view.getUint8(offset) != 0;
    offset += 1;

    List<T3Value> elements = [];
    if (hasStatic) {
      final count = view.getUint32(offset, Endian.little);
      offset += 4;
      for (var i = 0; i < count; i++) {
        elements.add(T3Value.fromPortable(data, offset));
        offset += T3Value.portableSize;
      }
    }

    final iter = T3IteratorObject(
      objectId: objectId,
      collection: collection,
      elements: elements,
      isTransient: isTransient,
    );
    iter._index = index;
    return iter;
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();

    // Collection
    final colBuf = Uint8List(5);
    collection.toPortable(colBuf, 0);
    builder.add(colBuf);

    // Index
    builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, _index, Endian.little));

    // Has static elements
    final hasStatic = _staticElements != null;
    builder.addByte(hasStatic ? 1 : 0);

    if (hasStatic) {
      // Count
      builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, _staticElements.length, Endian.little));
      // Elements
      for (final el in _staticElements) {
        final elBuf = Uint8List(5);
        el.toPortable(elBuf, 0);
        builder.add(elBuf);
      }
    }

    return builder.toBytes();
  }
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
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('Cannot set properties on unknown metaclass: $metaclass');
  }

  @override
  Map<String, dynamic> get debugInfo => {'objectId': objectId, 'metaclass': metaclass, 'dataSize': rawData.length};

  @override
  String toString() => 'T3GenericObject(#$objectId, $metaclass, ${rawData.length} bytes)';

  @override
  Uint8List save() => rawData;
}

/// StringBuffer object - mutable string.
///
/// Data format:
/// - UINT4: Current length in characters
/// - UINT4: Allocated buffer size (in characters)
/// - UINT2: Increment size
/// - Bytes: UTF-8 string content
class T3StringBuffer extends T3Object {
  final StringBuffer _buffer = StringBuffer();
  int allocatedSize;
  int increment;

  T3StringBuffer({
    required super.objectId,
    String initialText = '',
    this.allocatedSize = 256,
    this.increment = 256,
    super.isTransient,
  }) : super(metaclass: 'string-buffer') {
    _buffer.write(initialText);
  }

  void append(String text) {
    _buffer.write(text);
  }

  String get content => _buffer.toString();
  int get length => _buffer.length;

  @override
  T3Value? getProperty(int propId) {
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('StringBuffer properties are read-only via setProperty');
  }

  factory T3StringBuffer.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final length = view.getUint32(0, Endian.little);
    final alloc = view.getUint32(4, Endian.little);
    final incr = view.getUint16(8, Endian.little);

    // String data starts at offset 10
    final strBytes = data.sublist(10, 10 + length);
    // Assuming 1 byte per char for now as per simple encoding, but T3 uses UTF8.
    // The data format from `save` writes bytes, so we read bytes.
    // Spec says 'utf8'.
    final str = String.fromCharCodes(strBytes); // Simple decoding, enhance if full UTF8 needed

    return T3StringBuffer(
      objectId: objectId,
      initialText: str,
      allocatedSize: alloc,
      increment: incr,
      isTransient: isTransient,
    );
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    final bytes = Uint8List.fromList(content.codeUnits);

    // Length (UINT4)
    builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, bytes.length, Endian.little));
    // Alloc (UINT4)
    builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, allocatedSize, Endian.little));
    // Increment (UINT2)
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, increment, Endian.little));
    // Data
    builder.add(bytes);

    return builder.toBytes();
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'length': length,
    'content': content.length > 50 ? '${content.substring(0, 50)}...' : content,
  };
}
