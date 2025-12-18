import 'package:zart/src/glulx/glulx_op.dart';

class OpcodeInfo {
  final int operandCount;
  // Bitmask or list indicating which operands are stores?
  // Usually only the last one is a store in Glulx, but not always.
  // Spec: "L1 L2 S1".
  final List<bool> _stores;

  OpcodeInfo(this.operandCount, this._stores);

  bool isStore(int index) {
    if (index >= _stores.length) return false;
    return _stores[index];
  }

  static final Map<int, OpcodeInfo> _opcodes = {
    GlulxOp.nop: OpcodeInfo(0, []),
    GlulxOp.add: OpcodeInfo(3, [false, false, true]),
    GlulxOp.sub: OpcodeInfo(3, [false, false, true]),
    GlulxOp.mul: OpcodeInfo(3, [false, false, true]),
    GlulxOp.copy: OpcodeInfo(2, [false, true]),
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
    // Default 0 operands to avoid crash, will likely fail execution if it was supposed to have operands.
  }
}
