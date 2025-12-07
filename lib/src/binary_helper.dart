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
  static bool isSet(int n, int bitPosition) => (n >> bitPosition) & 1 == 1;

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
  static int set(int n, int bit) {
    n |= (1 << bit);
    return n;
  }

  /// Unsets a bit in [n] at bit position [bit].
  static int unset(int n, int bit) {
    n &= ~(1 << bit);
    return n;
  }
}
