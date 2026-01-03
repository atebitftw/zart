/// T3 VM opcode constants.
///
/// Opcode values are taken directly from the reference VM implementation
/// in `packages/tads-runner/tads3/vmop.h`.
///
/// Each instruction consists of a one-byte opcode followed by operand data.
/// The size and interpretation of operands varies by instruction.
abstract class T3Opcodes {
  // ==================== Push Operations (0x01-0x10) ====================

  /// Push constant integer 0.
  static const int PUSH_0 = 0x01;

  /// Push constant integer 1.
  static const int PUSH_1 = 0x02;

  /// Push SBYTE operand as integer.
  static const int PUSHINT8 = 0x03;

  /// Push INT4 operand as integer.
  static const int PUSHINT = 0x04;

  /// Push UINT4 operand as string constant offset.
  static const int PUSHSTR = 0x05;

  /// Push UINT4 operand as list constant offset.
  static const int PUSHLST = 0x06;

  /// Push UINT4 operand as object ID.
  static const int PUSHOBJ = 0x07;

  /// Push nil.
  static const int PUSHNIL = 0x08;

  /// Push true.
  static const int PUSHTRUE = 0x09;

  /// Push UINT2 operand as property ID.
  static const int PUSHPROPID = 0x0A;

  /// Push UINT4 code offset as function pointer.
  static const int PUSHFNPTR = 0x0B;

  /// Push inline string constant (UINT2 len + bytes).
  static const int PUSHSTRI = 0x0C;

  /// Push varargs parameter list.
  static const int PUSHPARLST = 0x0D;

  /// Push varargs parameter from list.
  static const int MAKELSTPAR = 0x0E;

  /// Push an enum value (UINT4).
  static const int PUSHENUM = 0x0F;

  /// Push a pointer to a built-in function (UINT2 set, UINT2 idx).
  static const int PUSHBIFPTR = 0x10;

  // ==================== Arithmetic/Logic (0x20-0x30) ====================

  /// Negate (unary -).
  static const int NEG = 0x20;

  /// Bitwise NOT (~).
  static const int BNOT = 0x21;

  /// Add.
  static const int ADD = 0x22;

  /// Subtract.
  static const int SUB = 0x23;

  /// Multiply.
  static const int MUL = 0x24;

  /// Bitwise AND.
  static const int BAND = 0x25;

  /// Bitwise OR.
  static const int BOR = 0x26;

  /// Shift left.
  static const int SHL = 0x27;

  /// Arithmetic shift right.
  static const int ASHR = 0x28;

  /// Bitwise/logical XOR.
  static const int XOR = 0x29;

  /// Divide.
  static const int DIV = 0x2A;

  /// Modulo (remainder).
  static const int MOD = 0x2B;

  /// Logical NOT (!).
  static const int NOT = 0x2C;

  /// Boolize - convert top of stack to true/nil.
  static const int BOOLIZE = 0x2D;

  /// Increment value at top of stack.
  static const int INC = 0x2E;

  /// Decrement value at top of stack.
  static const int DEC = 0x2F;

  /// Logical shift right.
  static const int LSHR = 0x30;

  // ==================== Comparison (0x40-0x45) ====================

  /// Equals.
  static const int EQ = 0x40;

  /// Not equals.
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

  /// Return with value at top of stack.
  static const int RETVAL = 0x50;

  /// Return nil.
  static const int RETNIL = 0x51;

  /// Return true.
  static const int RETTRUE = 0x52;

  /// Return with no value (keeps R0).
  static const int RET = 0x54;

  // ==================== Named Arguments (0x56-0x57) ====================

  /// Pointer to named argument table.
  static const int NAMEDARGPTR = 0x56;

  /// Named argument table.
  static const int NAMEDARGTAB = 0x57;

  // ==================== Function Calls (0x58-0x59) ====================

  /// Call function (UBYTE argc, UINT4 offset).
  static const int CALL = 0x58;

  /// Call function through pointer (UBYTE argc).
  static const int PTRCALL = 0x59;

  // ==================== Property Access (0x60-0x6D) ====================

  /// Get property (UINT2 propId).
  static const int GETPROP = 0x60;

  /// Call property with arguments (UBYTE argc, UINT2 propId).
  static const int CALLPROP = 0x61;

  /// Call property through pointer with args (UBYTE argc).
  static const int PTRCALLPROP = 0x62;

  /// Get property of 'self' (UINT2 propId).
  static const int GETPROPSELF = 0x63;

  /// Call method of 'self' (UBYTE argc, UINT2 propId).
  static const int CALLPROPSELF = 0x64;

  /// Call method of 'self' through pointer (UBYTE argc).
  static const int PTRCALLPROPSELF = 0x65;

  /// Get property of specific object (UINT4 objId, UINT2 propId).
  static const int OBJGETPROP = 0x66;

  /// Call method of specific object (UBYTE argc, UINT4 objId, UINT2 propId).
  static const int OBJCALLPROP = 0x67;

  /// Get property, disallowing side effects (UINT2 propId).
  static const int GETPROPDATA = 0x68;

  /// Get property through pointer, data only.
  static const int PTRGETPROPDATA = 0x69;

  /// Get property of local variable (UBYTE localNum, UINT2 propId).
  static const int GETPROPLCL1 = 0x6A;

  /// Call property of local variable (UBYTE argc, UBYTE localNum, UINT2 propId).
  static const int CALLPROPLCL1 = 0x6B;

  /// Get property of R0 (UINT2 propId).
  static const int GETPROPR0 = 0x6C;

  /// Call property of R0 (UBYTE argc, UINT2 propId).
  static const int CALLPROPR0 = 0x6D;

  // ==================== Inheritance/Delegation (0x72-0x78) ====================

  /// Inherit from superclass (UBYTE argc, UINT2 propId).
  static const int INHERIT = 0x72;

  /// Inherit through property pointer (UBYTE argc).
  static const int PTRINHERIT = 0x73;

  /// Inherit from explicit superclass (UBYTE argc, UINT2 propId, UINT4 objId).
  static const int EXPINHERIT = 0x74;

  /// Inherit from explicit superclass through prop ptr (UBYTE argc, UINT4 objId).
  static const int PTREXPINHERIT = 0x75;

  /// Modifier: next call is var arg count.
  static const int VARARGC = 0x76;

  /// Delegate to object on stack (UBYTE argc, UINT2 propId).
  static const int DELEGATE = 0x77;

  /// Delegate through property pointer (UBYTE argc).
  static const int PTRDELEGATE = 0x78;

  // ==================== Stack/Swap (0x7A-0x7F) ====================

  /// Swap top two elements with next two.
  static const int SWAP2 = 0x7A;

  /// Swap elements at operand indices (UBYTE idx1, UBYTE idx2).
  static const int SWAPN = 0x7B;

  /// Get argument #0.
  static const int GETARGN0 = 0x7C;

  /// Get argument #1.
  static const int GETARGN1 = 0x7D;

  /// Get argument #2.
  static const int GETARGN2 = 0x7E;

  /// Get argument #3.
  static const int GETARGN3 = 0x7F;

  // ==================== Local/Arg Access (0x80-0x8F) ====================

  /// Push a local variable (UBYTE index).
  static const int GETLCL1 = 0x80;

  /// Push a local (UINT2 index).
  static const int GETLCL2 = 0x81;

  /// Push an argument (UBYTE index).
  static const int GETARG1 = 0x82;

  /// Push an argument (UINT2 index).
  static const int GETARG2 = 0x83;

  /// Push 'self'.
  static const int PUSHSELF = 0x84;

  /// Push debug frame local.
  static const int GETDBLCL = 0x85;

  /// Push debug frame argument.
  static const int GETDBARG = 0x86;

  /// Get current argument count.
  static const int GETARGC = 0x87;

  /// Duplicate top of stack.
  static const int DUP = 0x88;

  /// Discard top of stack.
  static const int DISC = 0x89;

  /// Discard n items from stack (UBYTE count).
  static const int DISC1 = 0x8A;

  /// Push the R0 register onto the stack.
  static const int GETR0 = 0x8B;

  /// Push debug frame argument count.
  static const int GETDBARGC = 0x8C;

  /// Swap top two stack elements.
  static const int SWAP = 0x8D;

  /// Push a method context value (UBYTE which).
  static const int PUSHCTXELE = 0x8E;

  /// Duplicate the top two stack elements.
  static const int DUP2 = 0x8F;

  // ==================== Jump/Control Flow (0x90-0xA6) ====================

  /// Jump through case table.
  static const int SWITCH = 0x90;

  /// Unconditional branch (INT2 offset).
  static const int JMP = 0x91;

  /// Jump if true (INT2 offset).
  static const int JT = 0x92;

  /// Jump if false (INT2 offset).
  static const int JF = 0x93;

  /// Jump if equal (INT2 offset).
  static const int JE = 0x94;

  /// Jump if not equal (INT2 offset).
  static const int JNE = 0x95;

  /// Jump if greater than (INT2 offset).
  static const int JGT = 0x96;

  /// Jump if greater or equal (INT2 offset).
  static const int JGE = 0x97;

  /// Jump if less than (INT2 offset).
  static const int JLT = 0x98;

  /// Jump if less than or equal (INT2 offset).
  static const int JLE = 0x99;

  /// Jump and save if true (INT2 offset).
  static const int JST = 0x9A;

  /// Jump and save if false (INT2 offset).
  static const int JSF = 0x9B;

  /// Local jump to subroutine (INT2 offset).
  static const int LJSR = 0x9C;

  /// Local return from subroutine.
  static const int LRET = 0x9D;

  /// Jump if nil (INT2 offset).
  static const int JNIL = 0x9E;

  /// Jump if not nil (INT2 offset).
  static const int JNOTNIL = 0x9F;

  /// Jump if R0 is true (INT2 offset).
  static const int JR0T = 0xA0;

  /// Jump if R0 is false (INT2 offset).
  static const int JR0F = 0xA1;

  /// Iterator next.
  static const int ITERNEXT = 0xA2;

  /// Set local from R0 and leave value on stack.
  static const int GETSETLCL1R0 = 0xA3;

  /// Set local and leave value on stack.
  static const int GETSETLCL1 = 0xA4;

  /// Push R0 twice.
  static const int DUPR0 = 0xA5;

  /// Get stack element at given index.
  static const int GETSPN = 0xA6;

  // ==================== Short Local Access (0xAA-0xAF) ====================

  /// Get local #0.
  static const int GETLCLN0 = 0xAA;

  /// Get local #1.
  static const int GETLCLN1 = 0xAB;

  /// Get local #2.
  static const int GETLCLN2 = 0xAC;

  /// Get local #3.
  static const int GETLCLN3 = 0xAD;

  /// Get local #4.
  static const int GETLCLN4 = 0xAE;

  /// Get local #5.
  static const int GETLCLN5 = 0xAF;

  // ==================== Say/Builtins (0xB0-0xB9) ====================

  /// Display a constant string (UINT4 offset).
  static const int SAY = 0xB0;

  /// Call built-in func from set 0 (UBYTE argc, UBYTE funcIdx).
  static const int BUILTIN_A = 0xB1;

  /// Call built-in from set 1 (UBYTE argc, UBYTE funcIdx).
  static const int BUILTIN_B = 0xB2;

  /// Call built-in from set 2 (UBYTE argc, UBYTE funcIdx).
  static const int BUILTIN_C = 0xB3;

  /// Call built-in from set 3 (UBYTE argc, UBYTE funcIdx).
  static const int BUILTIN_D = 0xB4;

  /// Call built-in from any set, 8-bit index (UBYTE argc, UBYTE funcIdx, UBYTE setIdx).
  static const int BUILTIN1 = 0xB5;

  /// Call built-in from any set, 16-bit index (UBYTE argc, UINT2 funcIdx, UBYTE setIdx).
  static const int BUILTIN2 = 0xB6;

  /// Call external function.
  static const int CALLEXT = 0xB7;

  /// Throw an exception.
  static const int THROW = 0xB8;

  /// Display the value at top of stack.
  static const int SAYVAL = 0xB9;

  // ==================== Index (0xBA-0xBC) ====================

  /// Index a list.
  static const int INDEX = 0xBA;

  /// Index a local variable by an int8 value (UBYTE localNum, SBYTE idx).
  static const int IDXLCL1INT8 = 0xBB;

  /// Index by an int8 value (SBYTE idx).
  static const int IDXINT8 = 0xBC;

  // ==================== New Object (0xC0-0xC3) ====================

  /// Create new object instance (UBYTE metaclassIdx, UBYTE argc).
  static const int NEW1 = 0xC0;

  /// Create new object (2-byte operands) (UINT2 metaclassIdx, UBYTE argc).
  static const int NEW2 = 0xC1;

  /// Create new transient instance (UBYTE metaclassIdx, UBYTE argc).
  static const int TRNEW1 = 0xC2;

  /// Create transient object (2-byte operands) (UINT2 metaclassIdx, UBYTE argc).
  static const int TRNEW2 = 0xC3;

  // ==================== Local Modification (0xD0-0xDB) ====================

  /// Increment local variable by 1 (UBYTE localNum).
  static const int INCLCL = 0xD0;

  /// Decrement local variable by 1 (UBYTE localNum).
  static const int DECLCL = 0xD1;

  /// Add immediate 1-byte int to local (UBYTE localNum, SBYTE val).
  static const int ADDILCL1 = 0xD2;

  /// Add immediate 4-byte int to local (UBYTE localNum, INT4 val).
  static const int ADDILCL4 = 0xD3;

  /// Add value to local variable (UBYTE localNum).
  static const int ADDTOLCL = 0xD4;

  /// Subtract value from local variable (UBYTE localNum).
  static const int SUBFROMLCL = 0xD5;

  /// Set local to zero (UBYTE localNum).
  static const int ZEROLCL1 = 0xD6;

  /// Set local to zero (UINT2 localNum).
  static const int ZEROLCL2 = 0xD7;

  /// Set local to nil (UBYTE localNum).
  static const int NILLCL1 = 0xD8;

  /// Set local to nil (UINT2 localNum).
  static const int NILLCL2 = 0xD9;

  /// Set local to numeric value 1 (UBYTE localNum).
  static const int ONELCL1 = 0xDA;

  /// Set local to numeric value 1 (UINT2 localNum).
  static const int ONELCL2 = 0xDB;

  // ==================== Set Operations (0xE0-0xEF) ====================

  /// Set local (1-byte local number).
  static const int SETLCL1 = 0xE0;

  /// Set local (2-byte local number).
  static const int SETLCL2 = 0xE1;

  /// Set parameter (1-byte param number).
  static const int SETARG1 = 0xE2;

  /// Set parameter (2-byte param number).
  static const int SETARG2 = 0xE3;

  /// Set value at index.
  static const int SETIND = 0xE4;

  /// Set property in object (UINT2 propId).
  static const int SETPROP = 0xE5;

  /// Set property through prop pointer.
  static const int PTRSETPROP = 0xE6;

  /// Set property in self (UINT2 propId).
  static const int SETPROPSELF = 0xE7;

  /// Set property in immediate object (UINT4 objId, UINT2 propId).
  static const int OBJSETPROP = 0xE8;

  /// Set debugger local variable.
  static const int SETDBLCL = 0xE9;

  /// Set debugger parameter variable.
  static const int SETDBARG = 0xEA;

  /// Set 'self'.
  static const int SETSELF = 0xEB;

  /// Load method context from stack.
  static const int LOADCTX = 0xEC;

  /// Store method context and push on stack.
  static const int STORECTX = 0xED;

  /// Set local (1-byte local number) from R0 (UBYTE localNum).
  static const int SETLCL1R0 = 0xEE;

  /// Set indexed local (UBYTE localNum, SBYTE idx).
  static const int SETINDLCL1I8 = 0xEF;

  // ==================== Debug (0xF1-0xF2) ====================

  /// Debugger breakpoint.
  static const int BP = 0xF1;

  /// No operation.
  static const int NOP = 0xF2;

  // ==================== Context element codes ====================

  /// PUSHCTXELE: push target property.
  static const int PUSHCTXELE_TARGPROP = 0x01;

  /// PUSHCTXELE: push target object.
  static const int PUSHCTXELE_TARGOBJ = 0x02;

  /// PUSHCTXELE: push defining object.
  static const int PUSHCTXELE_DEFOBJ = 0x03;

  /// PUSHCTXELE: push the invokee.
  static const int PUSHCTXELE_INVOKEE = 0x04;

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
    PUSHPARLST: 'PUSHPARLST',
    MAKELSTPAR: 'MAKELSTPAR',
    PUSHENUM: 'PUSHENUM',
    PUSHBIFPTR: 'PUSHBIFPTR',
    NEG: 'NEG',
    BNOT: 'BNOT',
    ADD: 'ADD',
    SUB: 'SUB',
    MUL: 'MUL',
    BAND: 'BAND',
    BOR: 'BOR',
    SHL: 'SHL',
    ASHR: 'ASHR',
    XOR: 'XOR',
    DIV: 'DIV',
    MOD: 'MOD',
    NOT: 'NOT',
    BOOLIZE: 'BOOLIZE',
    INC: 'INC',
    DEC: 'DEC',
    LSHR: 'LSHR',
    EQ: 'EQ',
    NE: 'NE',
    LT: 'LT',
    LE: 'LE',
    GT: 'GT',
    GE: 'GE',
    RETVAL: 'RETVAL',
    RETNIL: 'RETNIL',
    RETTRUE: 'RETTRUE',
    RET: 'RET',
    NAMEDARGPTR: 'NAMEDARGPTR',
    NAMEDARGTAB: 'NAMEDARGTAB',
    CALL: 'CALL',
    PTRCALL: 'PTRCALL',
    GETPROP: 'GETPROP',
    CALLPROP: 'CALLPROP',
    PTRCALLPROP: 'PTRCALLPROP',
    GETPROPSELF: 'GETPROPSELF',
    CALLPROPSELF: 'CALLPROPSELF',
    PTRCALLPROPSELF: 'PTRCALLPROPSELF',
    OBJGETPROP: 'OBJGETPROP',
    OBJCALLPROP: 'OBJCALLPROP',
    GETPROPDATA: 'GETPROPDATA',
    PTRGETPROPDATA: 'PTRGETPROPDATA',
    GETPROPLCL1: 'GETPROPLCL1',
    CALLPROPLCL1: 'CALLPROPLCL1',
    GETPROPR0: 'GETPROPR0',
    CALLPROPR0: 'CALLPROPR0',
    INHERIT: 'INHERIT',
    PTRINHERIT: 'PTRINHERIT',
    EXPINHERIT: 'EXPINHERIT',
    PTREXPINHERIT: 'PTREXPINHERIT',
    VARARGC: 'VARARGC',
    DELEGATE: 'DELEGATE',
    PTRDELEGATE: 'PTRDELEGATE',
    SWAP2: 'SWAP2',
    SWAPN: 'SWAPN',
    GETARGN0: 'GETARGN0',
    GETARGN1: 'GETARGN1',
    GETARGN2: 'GETARGN2',
    GETARGN3: 'GETARGN3',
    GETLCL1: 'GETLCL1',
    GETLCL2: 'GETLCL2',
    GETARG1: 'GETARG1',
    GETARG2: 'GETARG2',
    PUSHSELF: 'PUSHSELF',
    GETDBLCL: 'GETDBLCL',
    GETDBARG: 'GETDBARG',
    GETARGC: 'GETARGC',
    DUP: 'DUP',
    DISC: 'DISC',
    DISC1: 'DISC1',
    GETR0: 'GETR0',
    GETDBARGC: 'GETDBARGC',
    SWAP: 'SWAP',
    PUSHCTXELE: 'PUSHCTXELE',
    DUP2: 'DUP2',
    SWITCH: 'SWITCH',
    JMP: 'JMP',
    JT: 'JT',
    JF: 'JF',
    JE: 'JE',
    JNE: 'JNE',
    JGT: 'JGT',
    JGE: 'JGE',
    JLT: 'JLT',
    JLE: 'JLE',
    JST: 'JST',
    JSF: 'JSF',
    LJSR: 'LJSR',
    LRET: 'LRET',
    JNIL: 'JNIL',
    JNOTNIL: 'JNOTNIL',
    JR0T: 'JR0T',
    JR0F: 'JR0F',
    ITERNEXT: 'ITERNEXT',
    GETSETLCL1R0: 'GETSETLCL1R0',
    GETSETLCL1: 'GETSETLCL1',
    DUPR0: 'DUPR0',
    GETSPN: 'GETSPN',
    GETLCLN0: 'GETLCLN0',
    GETLCLN1: 'GETLCLN1',
    GETLCLN2: 'GETLCLN2',
    GETLCLN3: 'GETLCLN3',
    GETLCLN4: 'GETLCLN4',
    GETLCLN5: 'GETLCLN5',
    SAY: 'SAY',
    BUILTIN_A: 'BUILTIN_A',
    BUILTIN_B: 'BUILTIN_B',
    BUILTIN_C: 'BUILTIN_C',
    BUILTIN_D: 'BUILTIN_D',
    BUILTIN1: 'BUILTIN1',
    BUILTIN2: 'BUILTIN2',
    CALLEXT: 'CALLEXT',
    THROW: 'THROW',
    SAYVAL: 'SAYVAL',
    INDEX: 'INDEX',
    IDXLCL1INT8: 'IDXLCL1INT8',
    IDXINT8: 'IDXINT8',
    NEW1: 'NEW1',
    NEW2: 'NEW2',
    TRNEW1: 'TRNEW1',
    TRNEW2: 'TRNEW2',
    INCLCL: 'INCLCL',
    DECLCL: 'DECLCL',
    ADDILCL1: 'ADDILCL1',
    ADDILCL4: 'ADDILCL4',
    ADDTOLCL: 'ADDTOLCL',
    SUBFROMLCL: 'SUBFROMLCL',
    ZEROLCL1: 'ZEROLCL1',
    ZEROLCL2: 'ZEROLCL2',
    NILLCL1: 'NILLCL1',
    NILLCL2: 'NILLCL2',
    ONELCL1: 'ONELCL1',
    ONELCL2: 'ONELCL2',
    SETLCL1: 'SETLCL1',
    SETLCL2: 'SETLCL2',
    SETARG1: 'SETARG1',
    SETARG2: 'SETARG2',
    SETIND: 'SETIND',
    SETPROP: 'SETPROP',
    PTRSETPROP: 'PTRSETPROP',
    SETPROPSELF: 'SETPROPSELF',
    OBJSETPROP: 'OBJSETPROP',
    SETDBLCL: 'SETDBLCL',
    SETDBARG: 'SETDBARG',
    SETSELF: 'SETSELF',
    LOADCTX: 'LOADCTX',
    STORECTX: 'STORECTX',
    SETLCL1R0: 'SETLCL1R0',
    SETINDLCL1I8: 'SETINDLCL1I8',
    BP: 'BP',
    NOP: 'NOP',
  };

  /// Gets the name of an opcode for debugging.
  static String getName(int opcode) => names[opcode] ?? 'UNKNOWN(0x${opcode.toRadixString(16).padLeft(2, '0')})';
}
