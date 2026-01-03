import 'dart:typed_data';

/// A single parsed static object from an OBJS block.
///
/// Contains the raw metaclass-specific data that will be parsed
/// differently depending on the metaclass type.
class T3StaticObject {
  /// The object ID assigned by the compiler.
  final int objectId;

  /// The metaclass dependency table index for this object.
  final int metaclassIndex;

  /// Whether this is a transient object.
  final bool isTransient;

  /// The raw metaclass-specific data for this object.
  final Uint8List data;

  T3StaticObject({required this.objectId, required this.metaclassIndex, required this.isTransient, required this.data});

  @override
  String toString() =>
      'T3StaticObject(id: $objectId, metaclass: $metaclassIndex, transient: $isTransient, dataSize: ${data.length})';
}

/// Parsed OBJS (Static Object) block.
///
/// Each OBJS block contains objects of a single metaclass.
/// The image file may contain multiple OBJS blocks for different metaclasses
/// or even multiple blocks for the same metaclass.
///
/// OBJS block format:
/// - UINT2: Number of objects in block
/// - UINT2: Metaclass dependency table index
/// - UINT2: Flags (0x0001 = large objects, 0x0002 = transient)
/// - For each object:
///   - UINT4: Object ID
///   - UINT2 or UINT4: Data size (depends on large objects flag)
///   - Metaclass-specific data
///
/// See spec section "OBJS Static Object Block".
class T3ObjsBlock {
  /// Flag: per-object size field is UINT4 instead of UINT2.
  static const int flagLargeObjects = 0x0001;

  /// Flag: all objects in this block are transient.
  static const int flagTransient = 0x0002;

  /// The metaclass dependency table index for all objects in this block.
  final int metaclassIndex;

  /// Whether this block uses 32-bit size fields per object.
  final bool isLargeObjects;

  /// Whether all objects in this block are transient.
  final bool isTransient;

  /// The block-level flags.
  final int flags;

  /// The parsed objects in this block.
  final List<T3StaticObject> objects;

  T3ObjsBlock({
    required this.metaclassIndex,
    required this.isLargeObjects,
    required this.isTransient,
    required this.flags,
    required this.objects,
  });

  /// Number of objects in this block.
  int get objectCount => objects.length;

  /// Parses an OBJS block from raw data.
  ///
  /// The [data] should be the block content (not including the block header).
  factory T3ObjsBlock.parse(Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);

    // Read header
    final objectCount = view.getUint16(0, Endian.little);
    final metaclassIndex = view.getUint16(2, Endian.little);
    final flags = view.getUint16(4, Endian.little);

    final isLargeObjects = (flags & flagLargeObjects) != 0;
    final isTransient = (flags & flagTransient) != 0;

    // Parse each object
    final objects = <T3StaticObject>[];
    var offset = 6; // After header

    for (var i = 0; i < objectCount; i++) {
      // Read object ID (always UINT4)
      final objectId = view.getUint32(offset, Endian.little);
      offset += 4;

      // Read data size (UINT2 or UINT4 depending on large objects flag)
      int dataSize;
      if (isLargeObjects) {
        dataSize = view.getUint32(offset, Endian.little);
        offset += 4;
      } else {
        dataSize = view.getUint16(offset, Endian.little);
        offset += 2;
      }

      // Extract metaclass-specific data
      final objData = data.sublist(offset, offset + dataSize);
      offset += dataSize;

      objects.add(
        T3StaticObject(objectId: objectId, metaclassIndex: metaclassIndex, isTransient: isTransient, data: objData),
      );
    }

    return T3ObjsBlock(
      metaclassIndex: metaclassIndex,
      isLargeObjects: isLargeObjects,
      isTransient: isTransient,
      flags: flags,
      objects: objects,
    );
  }

  @override
  String toString() =>
      'T3ObjsBlock(metaclass: $metaclassIndex, objects: $objectCount, large: $isLargeObjects, transient: $isTransient)';
}
