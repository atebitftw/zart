import 'package:zart/src/glulx/glulx_op.dart';

/// Describes an opcode's operand structure.
/// Reference: operand.c operandlist_t in the C implementation
class OpcodeInfo {
  final int operandCount;
  final List<bool> _stores;

  /// The byte width for memory/local operand access (1, 2, or 4).
  /// Reference: arg_size field in operandlist_t (operand.c line 22)
  final int argSize;

  /// Creates an [OpcodeInfo] with the given [operandCount] and [stores].
  /// [argSize] controls byte width for memory reads (default 4, use 1 for copyb, 2 for copys).
  const OpcodeInfo(this.operandCount, this._stores, {this.argSize = 4});

  /// Returns true if the operand at [index] is a store operand.
  bool isStore(int index) {
    if (index >= _stores.length) return false;
    return _stores[index];
  }

  @override
  String toString() {
    return 'OpInfo(operandCount: $operandCount, stores: $_stores)';
  }

  static final Map<int, OpcodeInfo> _opcodes = {
    // nop: 0 operands
    GlulxOp.nop: OpcodeInfo(0, []),

    // Integer Math: L1 L2 S1
    GlulxOp.add: OpcodeInfo(3, [false, false, true]),
    GlulxOp.sub: OpcodeInfo(3, [false, false, true]),
    GlulxOp.mul: OpcodeInfo(3, [false, false, true]),
    GlulxOp.div: OpcodeInfo(3, [false, false, true]),
    GlulxOp.mod: OpcodeInfo(3, [false, false, true]),
    GlulxOp.neg: OpcodeInfo(2, [false, true]),

    // Bitwise Operations: L1 L2 S1 (except bitnot which is L1 S1)
    GlulxOp.bitand: OpcodeInfo(3, [false, false, true]),
    GlulxOp.bitor: OpcodeInfo(3, [false, false, true]),
    GlulxOp.bitxor: OpcodeInfo(3, [false, false, true]),
    GlulxOp.bitnot: OpcodeInfo(2, [false, true]),
    GlulxOp.shiftl: OpcodeInfo(3, [false, false, true]),
    GlulxOp.sshiftr: OpcodeInfo(3, [false, false, true]),
    GlulxOp.ushiftr: OpcodeInfo(3, [false, false, true]),

    // Branch Opcodes
    GlulxOp.jump: OpcodeInfo(1, [false]),
    GlulxOp.jz: OpcodeInfo(2, [false, false]),
    GlulxOp.jnz: OpcodeInfo(2, [false, false]),
    GlulxOp.jeq: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jne: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jlt: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jge: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jgt: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jle: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jltu: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jgeu: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jgtu: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jleu: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jumpabs: OpcodeInfo(1, [false]),

    // Function Call Opcodes
    GlulxOp.call: OpcodeInfo(3, [false, false, true]),
    GlulxOp.callf: OpcodeInfo(2, [false, true]),
    GlulxOp.callfi: OpcodeInfo(3, [false, false, true]),
    GlulxOp.callfii: OpcodeInfo(4, [false, false, false, true]),
    GlulxOp.callfiii: OpcodeInfo(5, [false, false, false, false, true]),
    GlulxOp.ret: OpcodeInfo(1, [false]),
    GlulxOp.tailcall: OpcodeInfo(2, [false, false]),
    GlulxOp.catchEx: OpcodeInfo(2, [true, false]),
    GlulxOp.throwEx: OpcodeInfo(2, [false, false]),

    // Miscellaneous Opcodes
    GlulxOp.quit: OpcodeInfo(0, []),
    GlulxOp.gestalt: OpcodeInfo(3, [false, false, true]),

    // I/O System Opcodes
    GlulxOp.setiosys: OpcodeInfo(2, [false, false]),
    GlulxOp.getiosys: OpcodeInfo(2, [true, true]),

    // Copy Opcodes
    // Reference: operand.c lines 139-144 (list_LS, list_2LS, list_1LS)
    GlulxOp.copy: OpcodeInfo(2, [false, true]),
    GlulxOp.copys: OpcodeInfo(2, [false, true], argSize: 2),
    GlulxOp.copyb: OpcodeInfo(2, [false, true], argSize: 1),
    GlulxOp.sexs: OpcodeInfo(2, [false, true]),
    GlulxOp.sexb: OpcodeInfo(2, [false, true]),

    // Array: L1 L2 S1
    GlulxOp.aload: OpcodeInfo(3, [false, false, true]),
    GlulxOp.aloads: OpcodeInfo(3, [false, false, true]),
    GlulxOp.aloadb: OpcodeInfo(3, [false, false, true]),
    GlulxOp.aloadbit: OpcodeInfo(3, [false, false, true]),
    GlulxOp.astore: OpcodeInfo(3, [false, false, false]),
    GlulxOp.astores: OpcodeInfo(3, [false, false, false]),
    GlulxOp.astoreb: OpcodeInfo(3, [false, false, false]),
    GlulxOp.astorebit: OpcodeInfo(3, [false, false, false]),

    // Stack: L1 S1 (except stkswap which is 0, stkcopy/stkroll which are L1/L1 L2)
    GlulxOp.stkcount: OpcodeInfo(1, [true]),
    GlulxOp.stkpeek: OpcodeInfo(2, [false, true]),
    GlulxOp.stkswap: OpcodeInfo(0, []),
    GlulxOp.stkroll: OpcodeInfo(2, [false, false]),
    GlulxOp.stkcopy: OpcodeInfo(1, [false]),

    // Memory: S1/L1 S1
    GlulxOp.getmemsize: OpcodeInfo(1, [true]),
    GlulxOp.setmemsize: OpcodeInfo(2, [false, true]),
    GlulxOp.mzero: OpcodeInfo(2, [false, false]),
    GlulxOp.mcopy: OpcodeInfo(3, [false, false, false]),
    GlulxOp.malloc: OpcodeInfo(2, [false, true]),
    GlulxOp.mfree: OpcodeInfo(1, [false]),

    // System / Random
    GlulxOp.random: OpcodeInfo(2, [false, true]),
    GlulxOp.setrandom: OpcodeInfo(1, [false]),
    GlulxOp.verify: OpcodeInfo(1, [true]),
    GlulxOp.restart: OpcodeInfo(0, []),
    GlulxOp.save: OpcodeInfo(2, [false, true]),
    GlulxOp.restore: OpcodeInfo(2, [false, true]),
    GlulxOp.saveundo: OpcodeInfo(1, [true]),
    GlulxOp.restoreundo: OpcodeInfo(1, [true]),
    GlulxOp.hasundo: OpcodeInfo(1, [true]),
    GlulxOp.discardundo: OpcodeInfo(0, []),
    GlulxOp.protect: OpcodeInfo(2, [false, false]),
    GlulxOp.getstringtbl: OpcodeInfo(1, [true]),
    GlulxOp.setstringtbl: OpcodeInfo(1, [false]),

    // Stream: L1
    GlulxOp.streamchar: OpcodeInfo(1, [false]),
    GlulxOp.streamnum: OpcodeInfo(1, [false]),
    GlulxOp.streamstr: OpcodeInfo(1, [false]),
    GlulxOp.streamunichar: OpcodeInfo(1, [false]),

    // Search: (many operands)
    GlulxOp.linearsearch: OpcodeInfo(8, [false, false, false, false, false, false, false, true]),
    GlulxOp.binarysearch: OpcodeInfo(8, [false, false, false, false, false, false, false, true]),
    GlulxOp.linkedsearch: OpcodeInfo(7, [false, false, false, false, false, false, true]),

    // Floating Point: L1 L2 S1 / L1 S1
    GlulxOp.fadd: OpcodeInfo(3, [false, false, true]),
    GlulxOp.fsub: OpcodeInfo(3, [false, false, true]),
    GlulxOp.fmul: OpcodeInfo(3, [false, false, true]),
    GlulxOp.fdiv: OpcodeInfo(3, [false, false, true]),
    GlulxOp.fmod: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.frem: OpcodeInfo(3, [false, false, true]),
    GlulxOp.sqrt: OpcodeInfo(2, [false, true]),
    GlulxOp.exp: OpcodeInfo(2, [false, true]),
    GlulxOp.log: OpcodeInfo(2, [false, true]),
    GlulxOp.pow: OpcodeInfo(3, [false, false, true]),
    GlulxOp.sin: OpcodeInfo(2, [false, true]),
    GlulxOp.cos: OpcodeInfo(2, [false, true]),
    GlulxOp.tan: OpcodeInfo(2, [false, true]),
    GlulxOp.asin: OpcodeInfo(2, [false, true]),
    GlulxOp.acos: OpcodeInfo(2, [false, true]),
    GlulxOp.atan: OpcodeInfo(2, [false, true]),
    GlulxOp.atan2: OpcodeInfo(3, [false, false, true]),
    GlulxOp.ceil: OpcodeInfo(2, [false, true]),
    GlulxOp.floor: OpcodeInfo(2, [false, true]),
    GlulxOp.numtof: OpcodeInfo(2, [false, true]),
    GlulxOp.ftonumz: OpcodeInfo(2, [false, true]),
    GlulxOp.ftonumn: OpcodeInfo(2, [false, true]),
    GlulxOp.jfeq: OpcodeInfo(4, [false, false, false, false]),
    GlulxOp.jfne: OpcodeInfo(4, [false, false, false, false]),
    GlulxOp.jflt: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jfge: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jfgt: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jfle: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jisnan: OpcodeInfo(2, [false, false]),
    GlulxOp.jisinf: OpcodeInfo(2, [false, false]),
    GlulxOp.fgetround: OpcodeInfo(1, [true]),
    GlulxOp.fsetround: OpcodeInfo(1, [false]),

    // Double Precision: (same as float but mostly 64-bit operands)
    GlulxOp.dadd: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dsub: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dmul: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.ddiv: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dmodr: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dmodq: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dsqrt: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dexp: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dlog: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dpow: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dsin: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dcos: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dtan: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dasin: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dacos: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.datan: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.datan2: OpcodeInfo(6, [false, false, false, false, true, true]),
    GlulxOp.dceil: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.dfloor: OpcodeInfo(4, [false, false, true, true]),
    GlulxOp.numtod: OpcodeInfo(3, [false, true, true]),
    GlulxOp.dtonumz: OpcodeInfo(3, [false, false, true]),
    GlulxOp.ftod: OpcodeInfo(2, [false, true, true]),
    GlulxOp.dtof: OpcodeInfo(3, [false, false, true]),
    GlulxOp.jdeq: OpcodeInfo(7, [false, false, false, false, false, false, false]),
    GlulxOp.jdne: OpcodeInfo(7, [false, false, false, false, false, false, false]),
    GlulxOp.jdlt: OpcodeInfo(5, [false, false, false, false, false]),
    GlulxOp.jdge: OpcodeInfo(5, [false, false, false, false, false]),
    GlulxOp.jdgt: OpcodeInfo(5, [false, false, false, false, false]),
    GlulxOp.jdle: OpcodeInfo(5, [false, false, false, false, false]),
    GlulxOp.jdisnan: OpcodeInfo(3, [false, false, false]),
    GlulxOp.jdisinf: OpcodeInfo(3, [false, false, false]),

    // Glk Opcode
    GlulxOp.glk: OpcodeInfo(3, [false, false, true]),
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
  }
}
