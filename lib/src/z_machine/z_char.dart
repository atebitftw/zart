import 'package:zart/src/z_machine/binary_helper.dart';

/// Represents a Z-Character.
class ZChar {
  /// The raw word.
  final int _word;

  /// The first Z-Character.
  final int z1;

  /// The second Z-Character.
  final int z2;

  /// The third Z-Character.
  final int z3;

  /// Instantiates a [ZChar].
  ZChar(this._word)
    : // ((word >> 15) & 1) == 1,
      z3 = BinaryHelper.bottomBits(_word, 5),
      z2 = BinaryHelper.bottomBits(_word >> 5, 5),
      z1 = BinaryHelper.bottomBits(_word >> 10, 5) {
    // print('${word.toRadixString(2)}');
  }

  /// Gets the terminator set flag.
  bool get terminatorSet => BinaryHelper.isSet(_word, 15);

  /// Converts the [ZChar] to a list of integers.
  List<int> toCollection() => [z1, z2, z3];
}
