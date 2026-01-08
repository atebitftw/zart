import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';

/// ByteArray object - mutable byte array.
///
/// Data format:
/// - UINT4: Length in bytes
/// - bytes: Content
class T3ByteArray extends T3Object {
  final Uint8List data;

  T3ByteArray({required super.objectId, required this.data, super.isTransient}) : super(metaclass: 'bytearray');

  @override
  T3Value? getProperty(int propId) {
    // ByteArray methods are usually handled via intrinsics
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('ByteArray properties are read-only (use methods)');
  }

  /// Parses a ByteArray object from image file data.
  factory T3ByteArray.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final length = view.getUint32(0, Endian.little);
    final bytes = data.sublist(4, 4 + length);

    return T3ByteArray(objectId: objectId, data: bytes, isTransient: isTransient);
  }

  @override
  Map<String, dynamic> get debugInfo => {'objectId': objectId, 'metaclass': metaclass, 'length': data.length};

  @override
  String toString() => 'T3ByteArray(#$objectId, ${data.length} bytes)';

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, data.length, Endian.little));
    builder.add(data);
    return builder.toBytes();
  }
}
