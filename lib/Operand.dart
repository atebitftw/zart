
class Operand
{
  final int type;
  int rawValue;

  Operand(this.type);

  int get value(){
    switch(type){
      case OperandType.LARGE:
      case OperandType.SMALL:
        return rawValue;
      case OperandType.VARIABLE:
        return Z.readVariable(rawValue);
      default:
        throw new Exception('Invalid Operand Type: $type');
    }
  }


  String toString() => '[${OperandType.asString(type)}, 0x${value.toRadixString(16)}]';
}

/// Declares the 4 different operand types
class OperandType {

  /** 2 byte large constant (0-65535) */
  static final int LARGE = 0x00;

  /** 1 byte small constant (0-255) */
  static final int SMALL = 0x01;

  /** Variable lookup */
  static final int VARIABLE = 0x02;

  /** Omitted Flag, terminates Operand Type list */
  static final int OMITTED = 0x03;

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
