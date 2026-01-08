import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// BigNumber object - arbitrary precision floating point.
///
/// Data format (based on reference VM):
/// - UINT2: Available precision (digits)
/// - UINT2: Actual precision (digits)
/// - INT2: Exponent (scale)
/// - UINT2: Flags
/// - Bytes: Digits (BCD packed or similar)
///
/// For this initial implementation, we store the raw data and handle
/// basic property retrieval. Arithmetic operations will be implemented later.
class T3BigNumber extends T3Object {
  // We keep the raw data buffer because full BigNumber implementation
  // is complex and we want to preserve exact binary representation for now.
  // We can add a Dart BigDecimal equivalent later if needed.
  final Uint8List _data;

  // Parsed fields
  int get availablePrecision => ByteData.view(
    _data.buffer,
    _data.offsetInBytes,
  ).getUint16(0, Endian.little);
  int get actualPrecision => ByteData.view(
    _data.buffer,
    _data.offsetInBytes,
  ).getUint16(2, Endian.little);
  int get exponent => ByteData.view(
    _data.buffer,
    _data.offsetInBytes,
  ).getInt16(4, Endian.little);
  int get flags => ByteData.view(
    _data.buffer,
    _data.offsetInBytes,
  ).getUint16(6, Endian.little);

  T3BigNumber({
    required super.objectId,
    required Uint8List data,
    super.isTransient,
  }) : _data = data,
       super(metaclass: 'bignumber');

  /// Creates a new BigNumber from minimal parameters.
  factory T3BigNumber.create(
    int objectId, {
    int precision = 16,
    int exponent = 0,
    bool isTransient = false,
  }) {
    // Basic header: 8 bytes
    final data = Uint8List(8);
    final view = ByteData.view(data.buffer);
    view.setUint16(0, precision, Endian.little);
    view.setUint16(2, precision, Endian.little); // Actual = Available?
    view.setInt16(4, exponent, Endian.little);
    view.setUint16(6, 0, Endian.little); // Flags

    return T3BigNumber(
      objectId: objectId,
      data: data,
      isTransient: isTransient,
    );
  }

  factory T3BigNumber.fromData(
    int objectId,
    Uint8List data, {
    bool isTransient = false,
  }) {
    // Copy data to ensure immutability if needed, or just wrap
    return T3BigNumber(
      objectId: objectId,
      data: Uint8List.fromList(data),
      isTransient: isTransient,
    );
  }

  @override
  Uint8List save() {
    return _data;
  }

  @override
  T3Value? getProperty(int propId) {
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('BigNumber properties are read-only');
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'precision': availablePrecision,
    'actual': actualPrecision,
    'exponent': exponent,
    'flags': flags,
  };

  @override
  String toString() =>
      'T3BigNumber(#$objectId, prec: $availablePrecision, exp: $exponent)';
}
