import 'dart:math';

/// Helper class for binary operations
class BinaryHelper {
  // static String binaryOf(int n) {
  //   if (n < 0) throw Exception("negative numbers require 2s complement");
  //   if (n == 0) return "0";
  //   String res = "";
  //   while (n > 0) {
  //     res = (n % 2).toString() + res;
  //     n = (n ~/ 2);
  //   }
  //   return res;
  // }

  /// Returns a binary string of bits representing [n].
  static String binaryOf(int n) => n.toRadixString(2);

  /// Returns true if bit is set in [n] at [bitPosition].
  /// Works for bits >= 32 in JavaScript by using division instead of shifts.
  static bool isSet(int n, int bitPosition) {
    if (bitPosition < 32) {
      return (n >> bitPosition) & 1 == 1;
    } else {
      // For bits >= 32, use division to avoid JS 32-bit limit
      final divisor = _pow2(bitPosition);
      return (n ~/ divisor) & 1 == 1;
    }
  }

  /// Returns the bottom [bits] bits from [n].
  static int bottomBits(int n, int bits) => n & ((pow(2, bits)) - 1 as int);

  /// Returns an int with the given [numBits] set at the bottom.
  static int setBottomBits(int? numBits) {
    if (numBits == 0) return 0;

    var i = 1;

    for (int x = 1; x < numBits!; x++) {
      i = (i << 1) | 1;
    }

    return i;
  }

  /// Sets a bit in [n] at bit position [bit].
  /// Works for bits >= 32 in JavaScript by using multiplication instead of shifts.
  static int set(int n, int bit) {
    if (bit < 32) {
      n |= (1 << bit);
    } else {
      // For bits >= 32, use multiplication to avoid JS 32-bit limit
      n += _pow2(bit);
    }
    return n;
  }

  /// Unsets a bit in [n] at bit position [bit].
  /// Works for bits >= 32 in JavaScript by using arithmetic instead of shifts.
  static int unset(int n, int bit) {
    if (bit < 32) {
      n &= ~(1 << bit);
    } else {
      // For bits >= 32, check if bit is set then subtract
      if (isSet(n, bit)) {
        n -= _pow2(bit);
      }
    }
    return n;
  }

  /// Helper: returns 2^exp as int. Works for exp >= 32 in JavaScript.
  static int _pow2(int exp) {
    // Use multiplication to avoid << overflow in JavaScript
    if (exp < 32) {
      return 1 << exp;
    }
    int result = 1 << 30; // 2^30
    for (int i = 30; i < exp; i++) {
      result *= 2;
    }
    return result;
  }
}
