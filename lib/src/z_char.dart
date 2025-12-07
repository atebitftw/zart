import 'package:zart/src/binary_helper.dart';

class ZChar {
  final int _word;
  final int z1;
  final int z2;
  final int z3;

  ZChar(this._word)
      : // ((word >> 15) & 1) == 1,
        z3 = BinaryHelper.bottomBits(_word, 5),
        z2 = BinaryHelper.bottomBits(_word >> 5, 5),
        z1 = BinaryHelper.bottomBits(_word >> 10, 5) {
    // print('${word.toRadixString(2)}');
  }

  bool get terminatorSet => BinaryHelper.isSet(_word, 15);

  List<int> toCollection() => [z1, z2, z3];
}
