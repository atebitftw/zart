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
    GlulxOpcodes.gestalt: OpcodeInfo(3, [false, false, true]), // gestalt L1 L2 S1
    GlulxOpcodes.debugtrap: OpcodeInfo(1, [false]), // debugtrap L1
    GlulxOpcodes.getmemsize: OpcodeInfo(1, [true]), // getmemsize S1
    GlulxOpcodes.setmemsize: OpcodeInfo(2, [false, true]), // setmemsize L1 S1
    GlulxOpcodes.jumpabs: OpcodeInfo(1, [false]), // jumpabs L1
    GlulxOpcodes.streamnum: OpcodeInfo(1, [false]), // streamnum L1
    GlulxOpcodes.streamstr: OpcodeInfo(1, [false]), // streamstr L1
    GlulxOpcodes.random: OpcodeInfo(2, [false, true]), // random L1 S1
    GlulxOpcodes.setrandom: OpcodeInfo(1, [false]), // setrandom L1
    GlulxOpcodes.verify: OpcodeInfo(1, [true]), // verify S1
    GlulxOpcodes.catchEx: OpcodeInfo(2, [true, false]), // catch S1 L1
    GlulxOpcodes.throwEx: OpcodeInfo(2, [false, false]), // throw L1 L2
    // New opcodes
    GlulxOpcodes.jgtu: OpcodeInfo(3, [false, false, false]), // jgtu L1 L2 L3
    GlulxOpcodes.jleu: OpcodeInfo(3, [false, false, false]), // jleu L1 L2 L3
    GlulxOpcodes.aloadbit: OpcodeInfo(3, [false, false, true]), // aloadbit L1 L2 S1
    GlulxOpcodes.astorebit: OpcodeInfo(3, [false, false, false]), // astorebit L1 L2 L3
    GlulxOpcodes.streamunichar: OpcodeInfo(1, [false]), // streamunichar L1
    GlulxOpcodes.callf: OpcodeInfo(2, [false, true]), // callf L1 S1
    GlulxOpcodes.callfi: OpcodeInfo(3, [false, false, true]), // callfi L1 L2 S1
    GlulxOpcodes.callfii: OpcodeInfo(4, [false, false, false, true]), // callfii L1 L2 L3 S1
    GlulxOpcodes.callfiii: OpcodeInfo(5, [false, false, false, false, true]), // callfiii L1 L2 L3 L4 S1
    GlulxOpcodes.setiosys: OpcodeInfo(2, [false, false]), // setiosys L1 L2
    GlulxOpcodes.getiosys: OpcodeInfo(2, [true, true]), // getiosys S1 S2
    GlulxOpcodes.mzero: OpcodeInfo(2, [false, false]), // mzero L1 L2
    GlulxOpcodes.mcopy: OpcodeInfo(3, [false, false, false]), // mcopy L1 L2 L3
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
    // Default 0 operands to avoid crash, will likely fail execution if it was supposed to have operands.
  }
}
