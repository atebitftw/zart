part of zart_prujohn;

/** Helper class for binary operations */
class BinaryHelper {

  /// Returns true if bit is set in [n] at [bitPosition].
  static bool isSet(num n, int bitPosition) => ((n >> bitPosition) & 1) == 1;

  /// Returns the bottom [bits] bits from [n].
  static int bottomBits(num n, int bits) => n & ((pow(2, bits)) - 1);

  /// Returns an int with the given [numBits] set at the bottom.
  static int setBottomBits(int numBits){
    if (numBits == 0) return 0;

    var i = 1;

    for(int x = 1; x < numBits; x++){
      i = (i << 1) | 1;
    }

    return i;
  }

  static num set(num n, int bit){
    n |= (1 << bit);
    return n;
  }

  static num unset(num n, int bit){
    n &= ~(1 << bit);
    return n;
  }
}
