import 'dart:typed_data';

/// Helper class for 32-bit binary operations that work correctly in JavaScript.
///
/// JavaScript only has 64-bit IEEE 754 floating-point numbers. Bitwise operators
/// convert operands to 32-bit signed integers, causing issues:
/// - `(-1) & 0xFFFFFFFF` returns `-1` in dart2js instead of `4294967295`
/// - Values with bit 31 set are treated as negative
///
/// This class uses `Uint32List` to guarantee correct 32-bit unsigned semantics
/// in both native Dart and JavaScript environments.
class GlulxBinaryHelper {
  /// Shared buffer for 32-bit conversions.
  /// Using a static instance avoids allocation overhead on each operation.
  static final Uint32List _temp = Uint32List(1);

  /// Wraps value to 32-bit unsigned.
  /// Replaces `& 0xFFFFFFFF` pattern which fails in JavaScript.
  ///
  /// Examples:
  /// - Native Dart: `(-1) & 0xFFFFFFFF` → `4294967295` ✓
  /// - dart2js: `(-1) & 0xFFFFFFFF` → `-1` ✗
  /// - Both: `toU32(-1)` → `4294967295` ✓
  static int toU32(int value) {
    _temp[0] = value;
    return _temp[0];
  }

  /// Bitwise AND that works in JavaScript.
  /// Spec Section 2.4.2: "bitand L1 L2 S1: Compute the bitwise AND of L1 and L2."
  static int and32(int a, int b) {
    _temp[0] = a;
    a = _temp[0];
    _temp[0] = b;
    b = _temp[0];
    _temp[0] = a & b;
    return _temp[0];
  }

  /// Bitwise OR that works in JavaScript.
  /// Spec Section 2.4.2: "bitor L1 L2 S1: Compute the bitwise OR of L1 and L2."
  static int or32(int a, int b) {
    _temp[0] = a;
    a = _temp[0];
    _temp[0] = b;
    b = _temp[0];
    _temp[0] = a | b;
    return _temp[0];
  }

  /// Bitwise XOR that works in JavaScript.
  /// Spec Section 2.4.2: "bitxor L1 L2 S1: Compute the bitwise XOR of L1 and L2."
  static int xor32(int a, int b) {
    _temp[0] = a;
    a = _temp[0];
    _temp[0] = b;
    b = _temp[0];
    _temp[0] = a ^ b;
    return _temp[0];
  }

  /// Bitwise NOT that works in JavaScript.
  /// Spec Section 2.4.2: "bitnot L1 S1: Compute the bitwise negation of L1."
  static int not32(int a) {
    _temp[0] = a;
    _temp[0] = ~_temp[0];
    return _temp[0];
  }

  /// Left shift that works in JavaScript.
  /// Spec Section 2.4.2: "shiftl L1 L2 S1: Shift the bits of L1 to the left by L2 places.
  /// If L2 is 32 or more, the result is always zero."
  static int shl32(int a, int shift) {
    if (shift >= 32) return 0;
    _temp[0] = a;
    _temp[0] = _temp[0] << shift;
    return _temp[0];
  }

  /// Unsigned right shift that works in JavaScript.
  /// Spec Section 2.4.2: "ushiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
  /// The top L2 bits are filled with zeroes. If L2 is 32 or more, the result is always zero."
  static int shr32(int a, int shift) {
    if (shift >= 32) return 0;
    _temp[0] = a;
    // Dart's >> on Uint32List values is unsigned (fills with 0s)
    _temp[0] = _temp[0] >> shift;
    return _temp[0];
  }

  /// Signed arithmetic right shift that works in JavaScript.
  /// Spec Section 2.4.2: "sshiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
  /// The top L2 bits are filled with copies of the top bit of L1.
  /// If L2 is 32 or more, the result is always zero or FFFFFFFF, depending on the top bit."
  static int sar32(int a, int shift) {
    _temp[0] = a;
    final val = _temp[0];
    // Check sign bit (bit 31)
    final signBit = (val >> 31) & 1;

    if (shift >= 32) {
      // Result depends on sign bit
      return signBit == 1 ? 0xFFFFFFFF : 0;
    }

    // Convert to signed for arithmetic shift
    final signed = val.toSigned(32);
    _temp[0] = signed >> shift;
    return _temp[0];
  }

  /// Wraps addition to 32-bit.
  /// Spec Section 2.4.1: "add L1 L2 S1: Add L1 and L2, using standard 32-bit addition.
  /// Truncate the result to 32 bits if necessary."
  static int add32(int a, int b) {
    _temp[0] = a + b;
    return _temp[0];
  }

  /// Wraps subtraction to 32-bit.
  /// Spec Section 2.4.1: "sub L1 L2 S1: Compute (L1 - L2)."
  static int sub32(int a, int b) {
    _temp[0] = a - b;
    return _temp[0];
  }

  /// Wraps multiplication to 32-bit.
  /// Spec Section 2.4.1: "mul L1 L2 S1: Compute (L1 * L2).
  /// Truncate the result to 32 bits if necessary."
  static int mul32(int a, int b) {
    _temp[0] = a * b;
    return _temp[0];
  }

  /// Negation that works in JavaScript.
  /// Spec Section 2.4.1: "neg L1 S1: Compute the negative of L1."
  static int neg32(int a) {
    _temp[0] = -a;
    return _temp[0];
  }
}
