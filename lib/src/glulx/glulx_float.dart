import 'dart:typed_data';

/// Helper class for IEEE-754 floating-point encoding per Glulx Spec Section 1.6.
///
/// Glulx uses big-endian, single-precision IEEE-754 encoding for floats,
/// and double-precision (64-bit) values stored as two 32-bit words (HI:LO).
class GlulxFloat {
  static final _buffer = Uint8List(8);
  static final _view = ByteData.view(_buffer.buffer);

  /// Converts a 32-bit Glulx integer (IEEE-754 single-precision) to a Dart double.
  ///
  /// Spec Section 1.6: "Glulx uses the big-endian, single-precision IEEE-754 encoding."
  static double fromInt32(int bits) {
    _view.setUint32(0, bits & 0xFFFFFFFF, Endian.big);
    return _view.getFloat32(0, Endian.big);
  }

  /// Converts a Dart double to a 32-bit Glulx integer (IEEE-754 single-precision).
  ///
  /// Spec Section 1.6: "Glulx uses the big-endian, single-precision IEEE-754 encoding."
  static int toInt32(double value) {
    _view.setFloat32(0, value, Endian.big);
    return _view.getUint32(0, Endian.big);
  }

  /// Converts a 64-bit Glulx double (HI:LO pair) to a Dart double.
  ///
  /// Spec Section 1.6.1: "The high 32 bits will be earlier in memory or closer to the top of the stack."
  static double fromInt64(int hi, int lo) {
    _view.setUint32(0, hi & 0xFFFFFFFF, Endian.big);
    _view.setUint32(4, lo & 0xFFFFFFFF, Endian.big);
    return _view.getFloat64(0, Endian.big);
  }

  /// Converts a Dart double to a 64-bit Glulx double (HI:LO pair).
  ///
  /// Spec Section 1.6.1: "The high 32 bits will be earlier in memory or closer to the top of the stack."
  /// Returns a record (hi, lo).
  static (int, int) toInt64(double value) {
    _view.setFloat64(0, value, Endian.big);
    return (_view.getUint32(0, Endian.big), _view.getUint32(4, Endian.big));
  }

  /// Checks if a 32-bit Glulx float is NaN.
  ///
  /// Spec Section 1.6: "If E is FF and M is nonzero, the value is a positive or negative NaN."
  /// NaN values are 7F800001-7FFFFFFF (+NaN) and FF800001-FFFFFFFF (-NaN).
  static bool isNaN32(int bits) {
    final exp = (bits >> 23) & 0xFF;
    final mantissa = bits & 0x7FFFFF;
    return exp == 0xFF && mantissa != 0;
  }

  /// Checks if a 32-bit Glulx float is infinity (+Inf or -Inf).
  ///
  /// Spec Section 1.6: "If E is FF and M is zero, the value is positive or negative infinity."
  /// +Inf is 7F800000; -Inf is FF800000.
  static bool isInf32(int bits) {
    final exp = (bits >> 23) & 0xFF;
    final mantissa = bits & 0x7FFFFF;
    return exp == 0xFF && mantissa == 0;
  }

  /// Checks if a 32-bit Glulx float is negative zero.
  ///
  /// Spec Section 1.6: "+0 is 00000000; −0 is 80000000."
  static bool isNegativeZero32(int bits) {
    return bits == 0x80000000;
  }

  /// Checks if a 64-bit Glulx double (HI:LO) is NaN.
  ///
  /// Spec Section 1.6.1: "For infinite and NaN values, E is 7FF."
  static bool isNaN64(int hi, int lo) {
    final exp = (hi >> 20) & 0x7FF;
    final mantissaHi = hi & 0xFFFFF;
    return exp == 0x7FF && (mantissaHi != 0 || lo != 0);
  }

  /// Checks if a 64-bit Glulx double (HI:LO) is infinity.
  ///
  /// Spec Section 1.6.1: "+Inf is 7FF00000:00000000; -Inf is FFF00000:00000000."
  static bool isInf64(int hi, int lo) {
    final exp = (hi >> 20) & 0x7FF;
    final mantissaHi = hi & 0xFFFFF;
    return exp == 0x7FF && mantissaHi == 0 && lo == 0;
  }

  /// Checks if a 64-bit Glulx double (HI:LO) is negative zero.
  static bool isNegativeZero64(int hi, int lo) {
    return hi == 0x80000000 && lo == 0;
  }
}
