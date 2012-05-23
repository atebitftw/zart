
/** Helper class for binary operations */
class BinaryHelper {

  /// Returns true if bit is set in [n] at [bitPosition].
  static bool isSet(num n, int bitPosition) => ((n >> bitPosition) & 1) == 1;

  /// Returns the bottom [bits] bits from [n].
  static int bottomBits(num n, int bits) => n & ((Math.pow(2, bits)) - 1);
  
  static num set(num n, int bit){
    n |= (1 << bit);
    return n;
  }
  
  static num unset(num n, int bit){
    n &= ~(1 << bit);
    return n;
  }
}
