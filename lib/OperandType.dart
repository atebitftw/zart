
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
}
