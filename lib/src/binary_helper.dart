/// Helper class for binary operations.
/// Note: JavaScript bitwise operators convert operands to 32-bit signed integers.
/// For values that may exceed 2^31, we use arithmetic instead of bitwise ops.
class BinaryHelper {
  /// Returns a binary string of bits representing [n].
  static String binaryOf(int n) => n.toRadixString(2);

  /// Returns true if bit is set in [n] at [bitPosition].
  /// Works for large values in JavaScript by using arithmetic.
  static bool isSet(int n, int bitPosition) {
    // Use division to extract the bit - works for all sizes in JS
    final divisor = _pow2(bitPosition);
    return ((n ~/ divisor) % 2) == 1;
  }

  /// Returns the bottom [bits] bits from [n].
  static int bottomBits(int n, int bits) {
    // Use modulo instead of & to avoid JS 32-bit conversion
    return n % _pow2(bits);
  }

  /// Returns an int with the given [numBits] set at the bottom.
  static int setBottomBits(int? numBits) {
    if (numBits == 0) return 0;
    return _pow2(numBits!) - 1;
  }

  /// Sets a bit in [n] at bit position [bit].
  /// Works for large values in JavaScript by using arithmetic.
  static int set(int n, int bit) {
    if (!isSet(n, bit)) {
      n += _pow2(bit);
    }
    return n;
  }

  /// Unsets a bit in [n] at bit position [bit].
  /// Works for large values in JavaScript by using arithmetic.
  static int unset(int n, int bit) {
    if (isSet(n, bit)) {
      n -= _pow2(bit);
    }
    return n;
  }

  /// Helper: returns 2^exp as int. Works for all exp values in JavaScript.
  static int _pow2(int exp) {
    // Use multiplication chain to avoid << overflow in JavaScript
    if (exp <= 30) {
      return 1 << exp;
    }
    int result = 1 << 30; // 2^30
    for (int i = 30; i < exp; i++) {
      result *= 2;
    }
    return result;
  }
}
