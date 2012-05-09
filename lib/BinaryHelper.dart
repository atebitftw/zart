
/** Helper class for binary operations */
class BinaryHelper {

  /// Returns true if bit is set in [n] at [bitPosition].
  static bool isSet(num n, int bitPosition){
    return ((n >> bitPosition) & 1) == 1;
  }

  /// Returns the bottom [bits] bits from [n].
  static int bottomBits(num n, int bits){
    return n & ((Math.pow(2, bits)) - 1);
  }
}
