import 'package:zart/src/glulx/glulx_opcodes.dart';

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
    GlulxOpcodes.nop: OpcodeInfo(0, []), // nop
    GlulxOpcodes.add: OpcodeInfo(3, [false, false, true]), // add
    GlulxOpcodes.sub: OpcodeInfo(3, [false, false, true]), // sub
    GlulxOpcodes.mul: OpcodeInfo(3, [false, false, true]), // mul
    GlulxOpcodes.div: OpcodeInfo(3, [false, false, true]), // div
    GlulxOpcodes.mod: OpcodeInfo(3, [false, false, true]), // mod
    GlulxOpcodes.neg: OpcodeInfo(2, [false, true]), // neg
    GlulxOpcodes.bitand: OpcodeInfo(3, [false, false, true]), // bitand
    GlulxOpcodes.bitor: OpcodeInfo(3, [false, false, true]), // bitor
    GlulxOpcodes.bitxor: OpcodeInfo(3, [false, false, true]), // bitxor
    GlulxOpcodes.bitnot: OpcodeInfo(2, [false, true]), // bitnot
    GlulxOpcodes.jump: OpcodeInfo(1, [false]), // jump
    GlulxOpcodes.jz: OpcodeInfo(2, [false, false]), // jz
    GlulxOpcodes.jnz: OpcodeInfo(2, [false, false]), // jnz
    GlulxOpcodes.jeq: OpcodeInfo(3, [false, false, false]), // jeq
    GlulxOpcodes.jne: OpcodeInfo(3, [false, false, false]), // jne
    GlulxOpcodes.jlt: OpcodeInfo(3, [false, false, false]), // jlt
    GlulxOpcodes.jge: OpcodeInfo(3, [false, false, false]), // jge
    GlulxOpcodes.jgt: OpcodeInfo(3, [false, false, false]), // jgt
    GlulxOpcodes.jle: OpcodeInfo(3, [false, false, false]), // jle
    GlulxOpcodes.jltu: OpcodeInfo(3, [false, false, false]), // jltu
    GlulxOpcodes.jgeu: OpcodeInfo(3, [false, false, false]), // jgeu
    GlulxOpcodes.call: OpcodeInfo(3, [false, false, true]), // call
    GlulxOpcodes.ret: OpcodeInfo(1, [false]), // return
    GlulxOpcodes.copy: OpcodeInfo(2, [false, true]), // copy
    GlulxOpcodes.copys: OpcodeInfo(2, [false, true]), // copys
    GlulxOpcodes.copyb: OpcodeInfo(2, [false, true]), // copyb
    GlulxOpcodes.streamchar: OpcodeInfo(1, [false]), // streamchar
    GlulxOpcodes.quit: OpcodeInfo(0, []), // quit
    GlulxOpcodes.glk: OpcodeInfo(3, [false, false, true]), // glk
    GlulxOpcodes.shiftl: OpcodeInfo(3, [false, false, true]), // shiftl
    GlulxOpcodes.sshiftr: OpcodeInfo(3, [false, false, true]), // sshiftr
    GlulxOpcodes.ushiftr: OpcodeInfo(3, [false, false, true]), // ushiftr
    GlulxOpcodes.sexs: OpcodeInfo(2, [false, true]), // sexs
    GlulxOpcodes.sexb: OpcodeInfo(2, [false, true]), // sexb
    GlulxOpcodes.aload: OpcodeInfo(3, [false, false, true]), // aload
    GlulxOpcodes.aloads: OpcodeInfo(3, [false, false, true]), // aloads
    GlulxOpcodes.aloadb: OpcodeInfo(3, [false, false, true]), // aloadb
    GlulxOpcodes.astore: OpcodeInfo(3, [false, false, false]), // astore
    GlulxOpcodes.astores: OpcodeInfo(3, [false, false, false]), // astores
    GlulxOpcodes.astoreb: OpcodeInfo(3, [false, false, false]), // astoreb
    GlulxOpcodes.stkcount: OpcodeInfo(1, [true]), // stkcount (Store)
    GlulxOpcodes.stkpeek: OpcodeInfo(2, [false, true]), // stkpeek L1 S2
    GlulxOpcodes.stkswap: OpcodeInfo(0, []), // stkswap
    GlulxOpcodes.stkroll: OpcodeInfo(2, [false, false]), // stkroll L1 L2
    GlulxOpcodes.stkcopy: OpcodeInfo(1, [false]), // stkcopy L1
    GlulxOpcodes.tailcall: OpcodeInfo(2, [false, false]), // tailcall L1 L2
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
    // Default 0 operands to avoid crash, will likely fail execution if it was supposed to have operands.
  }
}
