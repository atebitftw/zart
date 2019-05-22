import 'package:zart/game_exception.dart';
import 'package:zart/z_machine.dart';

class Operand
{
  final int oType;
  int rawValue;

  int _cachedValue;

  Operand(this.oType);

  /// Gets a read of the [rawValue].
  /// If the type is VARIABLE, then performns an implicit
  /// read of the variable's address, otherwise just
  /// returns the rawValue (SMALL or LARGE);
  int get value{
    switch(oType){
      case OperandType.LARGE:
      case OperandType.SMALL:
        return rawValue;
      case OperandType.VARIABLE:
        //prevents popping the stack more than once for
        //value inspection.
        if (_cachedValue == null){
          _cachedValue = Z.machine.readVariable(rawValue);
        }
        return _cachedValue;
      default:
        throw GameException('Invalid Operand Type: $oType');
    }
  }

  int get peekValue{
    switch(oType){
      case OperandType.LARGE:
      case OperandType.SMALL:
        return rawValue;
      case OperandType.VARIABLE:
        return Z.machine.peekVariable(rawValue);
      default:
        return 0;
    }
  }

  String toString() => '[${OperandType.asString(oType)}, 0x${peekValue.toRadixString(16)}]';

  /// Used primarily for unit testing
  static int createVarOperandByte(List<int> types){
    if (types.length != 4) return null;

    return (types[0] << 6) | (types[1] << 4) | (types[2] << 2) | types[3];
  }
}

/// Declares the 4 different operand types
class OperandType {

  /** 2 byte large constant (0-65535) */
  static const int LARGE = 0x00;

  /** 1 byte small constant (0-255) */
  static const int SMALL = 0x01;

  /** Variable lookup */
  static const int VARIABLE = 0x02;

  /** Omitted Flag, terminates Operand Type list */
  static const int OMITTED = 0x03;

  static int intToOperandType(int value){
    switch(value){
      case 0x00: return OperandType.LARGE;
      case 0x01: return OperandType.SMALL;
      case 0x02: return OperandType.VARIABLE;
      case 0x03: return OperandType.OMITTED;
      default:
        throw Exception("Unrecognized int when attempting to convert to OperandType");
    }
  }

  static String asString(int type){
    switch(type){
      case LARGE:
        return 'Large';
      case SMALL:
        return 'Small';
      case VARIABLE:
        return 'Var';
      case OMITTED:
        return 'Omitted';
      default:
        return '*INVALID* $type';
    }
  }
}
