/// Static helper functions for common number/math needs.
class MathHelper {
  /// Takes any Dart [val] and converts it to a Z-Machine-readable
  /// 16-bit unsigned representation of a signed value.
  ///
  /// Values outside the -32768 to 32767 range are wrapped using modular
  /// arithmetic, as per Z-Machine specification behavior.
  ///
  /// ### Z-Machine Spec Reference
  /// 2.2
  static int dartSignedIntTo16BitSigned(int val) {
    // Wrap to 16-bit range using modular arithmetic
    // This handles overflow/underflow correctly per Z-Machine spec
    val = val & 0xFFFF;

    // If the value was negative (or wrapped to appear negative in 16-bit),
    // it's already in the correct unsigned representation.
    // Otherwise, positive values are already correct.
    return val;
  }

  /// Converts a game 16-bit 'word' [val] into a signed Dart int.
  ///
  /// ### Z-Machine Spec Reference
  /// ref(2.2)
  static int toSigned(int val) {
    //if (val == 0) return val;

    // game 16-bit word is always positive number to Dart
    assert(val >= 0);

    // convert to signed if 16-bit MSB is set
    return (val & 0x8000) == 0x8000 ? -(65536 - val) : val;
  }
}
