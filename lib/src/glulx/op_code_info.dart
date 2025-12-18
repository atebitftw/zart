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

    // Integer Math: L1 S1
    GlulxOp.neg: OpcodeInfo(2, [false, true]),

    // Data Movement: L1 S1
    GlulxOp.copy: OpcodeInfo(2, [false, true]),
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
  }
}
