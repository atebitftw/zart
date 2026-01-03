/// T3 VM opcode constants.
///
/// Each instruction consists of a one-byte opcode followed by operand data.
/// The size and interpretation of operands varies by instruction.
///
/// See spec section "Byte-Code Instruction Set".
abstract class T3Opcodes {
  // ==================== Push Operations (0x01-0x0F) ====================

  /// Push integer 0.
  static const int PUSH_0 = 0x01;

  /// Push integer 1.
  static const int PUSH_1 = 0x02;

  /// Push 8-bit signed integer (SBYTE val).
  static const int PUSHINT8 = 0x03;

  /// Push 32-bit integer (INT4 val).
  static const int PUSHINT = 0x04;

  /// Push constant string (UINT4 offset).
  static const int PUSHSTR = 0x05;

  /// Push constant list (UINT4 offset).
  static const int PUSHLST = 0x06;

  /// Push object reference (UINT4 objId).
  static const int PUSHOBJ = 0x07;

  /// Push nil.
  static const int PUSHNIL = 0x08;

  /// Push true.
  static const int PUSHTRUE = 0x09;

  /// Push property ID (UINT2 propId).
  static const int PUSHPROPID = 0x0A;

  /// Push function pointer (UINT4 codeOffset).
  static const int PUSHFNPTR = 0x0B;

  /// Push inline string (UINT2 len + bytes) - creates String object.
  static const int PUSHSTRI = 0x0C;

  /// Push self-printing string (UINT4 offset).
  static const int PUSHDSTR = 0x0D; // Note: Displays and pushes nil

  /// Push enum value (UINT4 enumVal).
  static const int PUSHENUM = 0x0E;

  /// Push built-in function pointer (UINT2 setIdx, UINT2 funcIdx).
  static const int PUSHBIFPTR = 0x0F;

  // ==================== Negation/Not/Complement (0x10-0x1F) ====================

  /// Boolean negation (! operator).
  static const int NOT = 0x10;

  /// Boolean NOT nil (converts to true/nil).
  static const int BOOLIZE = 0x11;

  /// Increment top of stack.
  static const int INC = 0x12;

  /// Decrement top of stack.
  static const int DEC = 0x13;

  /// Arithmetic negation (unary -).
  static const int NEG = 0x18;

  /// Bitwise NOT (~).
  static const int BNOT = 0x19;

  // ==================== Arithmetic (0x20-0x2F) ====================

  /// Addition.
  static const int ADD = 0x22;

  /// Subtraction.
  static const int SUB = 0x23;

  /// Multiplication.
  static const int MUL = 0x24;

  /// Bitwise AND.
  static const int BAND = 0x25;

  /// Division.
  static const int DIV = 0x26;

  /// Modulo.
  static const int MOD = 0x27;

  /// Bitwise OR.
  static const int BOR = 0x28;

  /// Left shift.
  static const int SHL = 0x29;

  /// Arithmetic right shift.
  static const int ASHR = 0x2A;

  /// Bitwise XOR.
  static const int XOR = 0x2B;

  /// Logical right shift.
  static const int LSHR = 0x2C;

  // ==================== Comparison (0x40-0x4F) ====================

  /// Equality.
  static const int EQ = 0x40;

  /// Inequality.
  static const int NE = 0x41;

  /// Less than.
  static const int LT = 0x42;

  /// Less than or equal.
  static const int LE = 0x43;

  /// Greater than.
  static const int GT = 0x44;

  /// Greater than or equal.
  static const int GE = 0x45;

  // ==================== Return (0x50-0x54) ====================

  /// Return nil.
  static const int RETNIL = 0x50;

  /// Return value in R0.
  static const int RETVAL = 0x51;

  /// Return true.
  static const int RETTRUE = 0x52;

  /// Return (UINT2 - number of args to remove).
  static const int RET = 0x54;

  // ==================== Branching (0x55-0x5F) ====================

  /// Unconditional jump (INT2 offset).
  static const int JMP = 0x55;

  /// Jump if true (INT2 offset).
  static const int JT = 0x56;

  /// Jump if false (INT2 offset).
  static const int JF = 0x57;

  /// Jump if nil (INT2 offset).
  static const int JNil = 0x58;

  /// Jump if not nil (INT2 offset).
  static const int JNotNil = 0x59;

  /// Jump if R0 is true (INT2 offset).
  static const int JR0T = 0x5A;

  /// Jump if R0 is false (INT2 offset).
  static const int JR0F = 0x5B;

  // ==================== Function Calls (0x58-0x6F) ====================

  /// Call function (UINT4 offset, UBYTE argc).
  static const int CALL = 0x58;

  /// Call function using TOS (UBYTE argc).
  static const int PTRCALL = 0x59;

  // ==================== Local Variable Access (0x80-0x8F) ====================

  /// Get local 0-3 (no operand, encoded in opcode).
  static const int GETLCL1 = 0x80;

  /// Get local (UINT2 index).
  static const int GETLCL2 = 0x81;

  /// Get argument 0-3 (no operand, encoded in opcode).
  static const int GETARG1 = 0x82;

  /// Get argument (UINT2 index).
  static const int GETARG2 = 0x83;

  /// Push self.
  static const int PUSHSELF = 0x84;

  /// Get R0.
  static const int GETR0 = 0x85;

  // ==================== Store to Locals (0xB0-0xBF) ====================

  /// Set local (UBYTE index).
  static const int SETLCL1 = 0xB0;

  /// Set local (UINT2 index).
  static const int SETLCL2 = 0xB1;

  /// Set argument (UINT2 index).
  static const int SETARG1 = 0xB2;

  /// Set argument (UINT2 index).
  static const int SETARG2 = 0xB3;

  /// Set self.
  static const int SETSELF = 0xB4;

  /// Set R0 to TOS and pop.
  static const int SETR0 = 0xB5;

  // ==================== Object Property Access (0xC0-0xCF) ====================

  /// Get property (UINT2 propId, UBYTE argc).
  static const int GETPROP = 0xC0;

  /// Call property (UINT2 propId, UBYTE argc).
  static const int CALLPROP = 0xC1;

  /// Get property with pointer (UBYTE argc).
  static const int PTRCALLPROP = 0xC2;

  /// Get property self (UINT2 propId, UBYTE argc).
  static const int GETPROPSELF = 0xC3;

  /// Call property self (UINT2 propId, UBYTE argc).
  static const int CALLPROPSELF = 0xC4;

  /// Get property using local (UBYTE localIdx, UINT2 propId, UBYTE argc).
  static const int GETPROPLCL1 = 0xC5;

  /// Call property using local (UBYTE localIdx, UINT2 propId, UBYTE argc).
  static const int CALLPROPLCL1 = 0xC6;

  /// Get property R0 (UINT2 propId, UBYTE argc).
  static const int GETPROPR0 = 0xC7;

  /// Call property R0 (UINT2 propId, UBYTE argc).
  static const int CALLPROPR0 = 0xC8;

  // ==================== Stack Manipulation (0x07-0x0F extra) ====================

  /// Discard TOS.
  static const int DISC = 0x16;

  /// Discard N elements (UBYTE count).
  static const int DISC1 = 0x17;

  /// Duplicate TOS.
  static const int DUP = 0x1A;

  /// Swap top two elements.
  static const int SWAP = 0x1B;

  // ==================== Switch (0xE0) ====================

  /// Switch statement.
  static const int SWITCH = 0xE0;

  // ==================== New Object (0xF0-0xFF) ====================

  /// Create new object (UBYTE metaclassIdx, UBYTE argc).
  static const int NEW1 = 0xC0;

  /// Create new object (UINT2 metaclassIdx, UBYTE argc).
  static const int NEW2 = 0xC1;

  // ==================== Index Operations ====================

  /// Index into value.
  static const int INDEX = 0x30;

  /// Set indexed value.
  static const int SETIND = 0x31;

  /// Index with 8-bit immediate (SBYTE index).
  static const int IDXINT8 = 0x32;

  // ==================== Special Operations ====================

  /// No operation.
  static const int NOP = 0x00;

  /// Say (display string TOS).
  static const int SAY = 0x14;

  /// Enter/leave frame debug.
  static const int BP = 0xF1;

  /// Names for debugging.
  static const Map<int, String> names = {
    PUSH_0: 'PUSH_0',
    PUSH_1: 'PUSH_1',
    PUSHINT8: 'PUSHINT8',
    PUSHINT: 'PUSHINT',
    PUSHSTR: 'PUSHSTR',
    PUSHLST: 'PUSHLST',
    PUSHOBJ: 'PUSHOBJ',
    PUSHNIL: 'PUSHNIL',
    PUSHTRUE: 'PUSHTRUE',
    PUSHPROPID: 'PUSHPROPID',
    PUSHFNPTR: 'PUSHFNPTR',
    PUSHSTRI: 'PUSHSTRI',
    PUSHDSTR: 'PUSHDSTR',
    PUSHENUM: 'PUSHENUM',
    PUSHBIFPTR: 'PUSHBIFPTR',
    NOT: 'NOT',
    BOOLIZE: 'BOOLIZE',
    INC: 'INC',
    DEC: 'DEC',
    SAY: 'SAY',
    DISC: 'DISC',
    DISC1: 'DISC1',
    NEG: 'NEG',
    BNOT: 'BNOT',
    DUP: 'DUP',
    SWAP: 'SWAP',
    ADD: 'ADD',
    SUB: 'SUB',
    MUL: 'MUL',
    BAND: 'BAND',
    DIV: 'DIV',
    MOD: 'MOD',
    BOR: 'BOR',
    SHL: 'SHL',
    ASHR: 'ASHR',
    XOR: 'XOR',
    LSHR: 'LSHR',
    INDEX: 'INDEX',
    SETIND: 'SETIND',
    IDXINT8: 'IDXINT8',
    EQ: 'EQ',
    NE: 'NE',
    LT: 'LT',
    LE: 'LE',
    GT: 'GT',
    GE: 'GE',
    RETNIL: 'RETNIL',
    RETVAL: 'RETVAL',
    RETTRUE: 'RETTRUE',
    RET: 'RET',
    JMP: 'JMP',
    JT: 'JT',
    JF: 'JF',
    GETLCL1: 'GETLCL1',
    GETLCL2: 'GETLCL2',
    GETARG1: 'GETARG1',
    GETARG2: 'GETARG2',
    PUSHSELF: 'PUSHSELF',
    GETR0: 'GETR0',
    SETLCL1: 'SETLCL1',
    SETLCL2: 'SETLCL2',
    SETARG1: 'SETARG1',
    SETARG2: 'SETARG2',
    SETSELF: 'SETSELF',
    SETR0: 'SETR0',
    GETPROP: 'GETPROP',
    CALLPROP: 'CALLPROP',
    GETPROPSELF: 'GETPROPSELF',
    CALLPROPSELF: 'CALLPROPSELF',
    SWITCH: 'SWITCH',
    NOP: 'NOP',
    BP: 'BP',
  };

  /// Gets the name of an opcode for debugging.
  static String getName(int opcode) => names[opcode] ?? 'UNKNOWN(0x${opcode.toRadixString(16)})';
}
