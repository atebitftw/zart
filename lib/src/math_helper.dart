import 'package:zart/src/game_exception.dart';

/// Static helper functions for common number/math needs.
class MathHelper {
  /// Takes any Dart [val] between -32768 & 32767 and makes a zmachine-readable
  /// 16-bit signed 'word' from it.
  ///
  /// ### Z-Machine Spec Reference
  /// 2.2
  static int dartSignedIntTo16BitSigned(int val) {
    if (val < -32768 || val > 32767) {
      throw GameException("Signed 16-bit int is out of range: $val");
    }

    if (val > -1) return val;

    return 65536 - val.abs();
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
