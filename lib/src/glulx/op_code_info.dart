import 'package:zart/src/glulx/glulx_op.dart';

/// Describes an opcode's operand structure.
class OpcodeInfo {
  final int operandCount;
  final List<bool> _stores;

  OpcodeInfo(this.operandCount, this._stores);

  /// Returns true if the operand at [index] is a store operand.
  bool isStore(int index) {
    if (index >= _stores.length) return false;
    return _stores[index];
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
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
  }
}
