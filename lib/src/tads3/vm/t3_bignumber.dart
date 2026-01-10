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
  int get availablePrecision => ByteData.view(_data.buffer, _data.offsetInBytes).getUint16(0, Endian.little);
  int get actualPrecision => ByteData.view(_data.buffer, _data.offsetInBytes).getUint16(2, Endian.little);
  int get exponent => ByteData.view(_data.buffer, _data.offsetInBytes).getInt16(4, Endian.little);
  int get flags => ByteData.view(_data.buffer, _data.offsetInBytes).getUint16(6, Endian.little);

  T3BigNumber({required super.objectId, required Uint8List data, super.isTransient})
    : _data = data,
      super(metaclass: 'bignumber');

  /// Creates a new BigNumber from minimal parameters.
  factory T3BigNumber.create(int objectId, {int precision = 16, int exponent = 0, bool isTransient = false}) {
    // Basic header: 8 bytes
    final data = Uint8List(8);
    final view = ByteData.view(data.buffer);
    view.setUint16(0, precision, Endian.little);
    view.setUint16(2, precision, Endian.little); // Actual = Available?
    view.setInt16(4, exponent, Endian.little);
    view.setUint16(6, 0, Endian.little); // Flags

    return T3BigNumber(objectId: objectId, data: data, isTransient: isTransient);
  }

  factory T3BigNumber.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    // Copy data to ensure immutability if needed, or just wrap
    return T3BigNumber(objectId: objectId, data: Uint8List.fromList(data), isTransient: isTransient);
  }

  @override
  Uint8List save() {
    return _data;
  }

  @override
  T3Value? getProperty(int propId) {
    // BigNumber properties are handled through intrinsic system
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

  /// Formats the BigNumber as a decimal string.
  ///
  /// This extracts digits from the BCD representation and builds a string.
  /// Works on both Dart VM and JavaScript targets without BigInt dependencies.
  ///
  /// [maxDigits] - Maximum number of digits to include (0 = use actual precision)
  String formatString({int maxDigits = 0}) {
    final precision = actualPrecision;
    final exp = exponent;
    final isNegative = (flags & 0x0001) != 0; // Bit 0 = negative sign

    // Calculate number of digits to output
    final digitsToOutput = maxDigits > 0 && maxDigits < precision ? maxDigits : precision;

    // Extract BCD digits from data (starting at byte 8)
    final digits = StringBuffer();
    final headerSize = 8;

    for (int i = 0; i < digitsToOutput; i++) {
      final byteIndex = headerSize + (i ~/ 2);
      if (byteIndex >= _data.length) break;

      final byteVal = _data[byteIndex];
      // High nibble first, then low nibble (BCD packed format)
      final digit = (i % 2 == 0) ? (byteVal >> 4) & 0x0F : byteVal & 0x0F;
      digits.write(digit.toString());
    }

    final digitStr = digits.toString();
    if (digitStr.isEmpty) return isNegative ? '-0' : '0';

    // Build the formatted number with decimal point placement
    // The exponent indicates the position of the decimal point
    // exp=1 means one digit before decimal (e.g., 3.14159...)
    // exp=0 means decimal is before all digits (e.g., 0.314159...)
    // exp=-1 means 0.0314159..., etc.

    final result = StringBuffer();
    if (isNegative) result.write('-');

    if (exp <= 0) {
      // Need leading zeros: 0.000...digits
      result.write('0.');
      for (int i = 0; i < -exp; i++) {
        result.write('0');
      }
      result.write(digitStr);
    } else if (exp >= digitStr.length) {
      // All digits are before decimal, may need trailing zeros
      result.write(digitStr);
      for (int i = digitStr.length; i < exp; i++) {
        result.write('0');
      }
    } else {
      // Decimal point is within the digits
      result.write(digitStr.substring(0, exp));
      result.write('.');
      result.write(digitStr.substring(exp));
    }

    return result.toString();
  }

  @override
  String toString() => 'T3BigNumber(#$objectId, prec: $availablePrecision, exp: $exponent)';
}
