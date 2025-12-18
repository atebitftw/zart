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
    GlulxOp.nop: OpcodeInfo(0, []), // nop
    GlulxOp.add: OpcodeInfo(3, [false, false, true]), // add
    GlulxOp.sub: OpcodeInfo(3, [false, false, true]), // sub
    GlulxOp.mul: OpcodeInfo(3, [false, false, true]), // mul
    GlulxOp.div: OpcodeInfo(3, [false, false, true]), // div
    GlulxOp.mod: OpcodeInfo(3, [false, false, true]), // mod
    GlulxOp.neg: OpcodeInfo(2, [false, true]), // neg
    GlulxOp.bitand: OpcodeInfo(3, [false, false, true]), // bitand
    GlulxOp.bitor: OpcodeInfo(3, [false, false, true]), // bitor
    GlulxOp.bitxor: OpcodeInfo(3, [false, false, true]), // bitxor
    GlulxOp.bitnot: OpcodeInfo(2, [false, true]), // bitnot
    GlulxOp.jump: OpcodeInfo(1, [false]), // jump
    GlulxOp.jz: OpcodeInfo(2, [false, false]), // jz
    GlulxOp.jnz: OpcodeInfo(2, [false, false]), // jnz
    GlulxOp.jeq: OpcodeInfo(3, [false, false, false]), // jeq
    GlulxOp.jne: OpcodeInfo(3, [false, false, false]), // jne
    GlulxOp.jlt: OpcodeInfo(3, [false, false, false]), // jlt
    GlulxOp.jge: OpcodeInfo(3, [false, false, false]), // jge
    GlulxOp.jgt: OpcodeInfo(3, [false, false, false]), // jgt
    GlulxOp.jle: OpcodeInfo(3, [false, false, false]), // jle
    GlulxOp.jltu: OpcodeInfo(3, [false, false, false]), // jltu
    GlulxOp.jgeu: OpcodeInfo(3, [false, false, false]), // jgeu
    GlulxOp.call: OpcodeInfo(3, [false, false, true]), // call
    GlulxOp.accelfunc: OpcodeInfo(2, [false, false]), // accelfunc L1 L2
    GlulxOp.accelparam: OpcodeInfo(2, [false, false]), // accelparam L1 L2
    GlulxOp.mfree: OpcodeInfo(1, [false]), // mfree L1
    GlulxOp.ret: OpcodeInfo(1, [false]), // return
    GlulxOp.copy: OpcodeInfo(2, [false, true]), // copy
    GlulxOp.copys: OpcodeInfo(2, [false, true]), // copys
    GlulxOp.copyb: OpcodeInfo(2, [false, true]), // copyb
    GlulxOp.streamchar: OpcodeInfo(1, [false]), // streamchar
    GlulxOp.quit: OpcodeInfo(0, []), // quit
    GlulxOp.glk: OpcodeInfo(3, [false, false, true]), // glk
    GlulxOp.shiftl: OpcodeInfo(3, [false, false, true]), // shiftl
    GlulxOp.sshiftr: OpcodeInfo(3, [false, false, true]), // sshiftr
    GlulxOp.ushiftr: OpcodeInfo(3, [false, false, true]), // ushiftr
    GlulxOp.sexs: OpcodeInfo(2, [false, true]), // sexs
    GlulxOp.sexb: OpcodeInfo(2, [false, true]), // sexb
    GlulxOp.aload: OpcodeInfo(3, [false, false, true]), // aload
    GlulxOp.aloads: OpcodeInfo(3, [false, false, true]), // aloads
    GlulxOp.aloadb: OpcodeInfo(3, [false, false, true]), // aloadb
    GlulxOp.astore: OpcodeInfo(3, [false, false, false]), // astore
    GlulxOp.astores: OpcodeInfo(3, [false, false, false]), // astores
    GlulxOp.astoreb: OpcodeInfo(3, [false, false, false]), // astoreb
    GlulxOp.stkcount: OpcodeInfo(1, [true]), // stkcount (Store)
    GlulxOp.stkpeek: OpcodeInfo(2, [false, true]), // stkpeek L1 S2
    GlulxOp.stkswap: OpcodeInfo(0, []), // stkswap
    GlulxOp.stkroll: OpcodeInfo(2, [false, false]), // stkroll L1 L2
    GlulxOp.stkcopy: OpcodeInfo(1, [false]), // stkcopy L1
    GlulxOp.tailcall: OpcodeInfo(2, [false, false]), // tailcall L1 L2
    GlulxOp.gestalt: OpcodeInfo(3, [false, false, true]), // gestalt L1 L2 S1
    GlulxOp.debugtrap: OpcodeInfo(1, [false]), // debugtrap L1
    GlulxOp.getmemsize: OpcodeInfo(1, [true]), // getmemsize S1
    GlulxOp.setmemsize: OpcodeInfo(2, [false, true]), // setmemsize L1 S1
    GlulxOp.jumpabs: OpcodeInfo(1, [false]), // jumpabs L1
    GlulxOp.streamnum: OpcodeInfo(1, [false]), // streamnum L1
    GlulxOp.streamstr: OpcodeInfo(1, [false]), // streamstr L1
    GlulxOp.random: OpcodeInfo(2, [false, true]), // random L1 S1
    GlulxOp.setrandom: OpcodeInfo(1, [false]), // setrandom L1
    GlulxOp.verify: OpcodeInfo(1, [true]), // verify S1
    GlulxOp.catchEx: OpcodeInfo(2, [true, false]), // catch S1 L1
    GlulxOp.throwEx: OpcodeInfo(2, [false, false]), // throw L1 L2
    // New opcodes
    GlulxOp.jgtu: OpcodeInfo(3, [false, false, false]), // jgtu L1 L2 L3
    GlulxOp.jleu: OpcodeInfo(3, [false, false, false]), // jleu L1 L2 L3
    GlulxOp.aloadbit: OpcodeInfo(3, [false, false, true]), // aloadbit L1 L2 S1
    GlulxOp.astorebit: OpcodeInfo(3, [
      false,
      false,
      false,
    ]), // astorebit L1 L2 L3
    GlulxOp.streamunichar: OpcodeInfo(1, [false]), // streamunichar L1
    GlulxOp.callf: OpcodeInfo(2, [false, true]), // callf L1 S1
    GlulxOp.callfi: OpcodeInfo(3, [false, false, true]), // callfi L1 L2 S1
    GlulxOp.callfii: OpcodeInfo(4, [
      false,
      false,
      false,
      true,
    ]), // callfii L1 L2 L3 S1
    GlulxOp.callfiii: OpcodeInfo(5, [
      false,
      false,
      false,
      false,
      true,
    ]), // callfiii L1 L2 L3 L4 S1
    GlulxOp.setiosys: OpcodeInfo(2, [false, false]), // setiosys L1 L2
    GlulxOp.getiosys: OpcodeInfo(2, [true, true]), // getiosys S1 S2
    GlulxOp.mzero: OpcodeInfo(2, [false, false]), // mzero L1 L2
    GlulxOp.mcopy: OpcodeInfo(3, [false, false, false]), // mcopy L1 L2 L3
    // Search opcodes
    GlulxOp.linearsearch: OpcodeInfo(8, [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ]), // linearsearch L1 L2 L3 L4 L5 L6 L7 S1
    GlulxOp.binarysearch: OpcodeInfo(8, [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ]), // binarysearch L1 L2 L3 L4 L5 L6 L7 S1
    GlulxOp.linkedsearch: OpcodeInfo(7, [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ]), // linkedsearch L1 L2 L3 L4 L5 L6 S1
    // Floating point math
    GlulxOp.numtof: OpcodeInfo(2, [false, true]), // numtof L1 S1
    GlulxOp.ftonumz: OpcodeInfo(2, [false, true]), // ftonumz L1 S1
    GlulxOp.ftonumn: OpcodeInfo(2, [false, true]), // ftonumn L1 S1
    GlulxOp.ceil: OpcodeInfo(2, [false, true]), // ceil L1 S1
    GlulxOp.floor: OpcodeInfo(2, [false, true]), // floor L1 S1
    GlulxOp.fadd: OpcodeInfo(3, [false, false, true]), // fadd L1 L2 S1
    GlulxOp.fsub: OpcodeInfo(3, [false, false, true]), // fsub L1 L2 S1
    GlulxOp.fmul: OpcodeInfo(3, [false, false, true]), // fmul L1 L2 S1
    GlulxOp.fdiv: OpcodeInfo(3, [false, false, true]), // fdiv L1 L2 S1
    GlulxOp.fmod: OpcodeInfo(3, [false, false, true]), // fmod L1 L2 S1
    GlulxOp.sqrt: OpcodeInfo(2, [false, true]), // sqrt L1 S1
    GlulxOp.exp: OpcodeInfo(2, [false, true]), // exp L1 S1
    GlulxOp.log: OpcodeInfo(2, [false, true]), // log L1 S1
    GlulxOp.pow: OpcodeInfo(3, [false, false, true]), // pow L1 L2 S1
    GlulxOp.sin: OpcodeInfo(2, [false, true]), // sin L1 S1
    GlulxOp.cos: OpcodeInfo(2, [false, true]), // cos L1 S1
    GlulxOp.tan: OpcodeInfo(2, [false, true]), // tan L1 S1
    GlulxOp.asin: OpcodeInfo(2, [false, true]), // asin L1 S1
    GlulxOp.acos: OpcodeInfo(2, [false, true]), // acos L1 S1
    GlulxOp.atan: OpcodeInfo(2, [false, true]), // atan L1 S1
    GlulxOp.atan2: OpcodeInfo(3, [false, false, true]), // atan2 L1 L2 S1
    GlulxOp.jfeq: OpcodeInfo(3, [false, false, false]), // jfeq L1 L2 L3
    GlulxOp.jfne: OpcodeInfo(3, [false, false, false]), // jfne L1 L2 L3
    GlulxOp.jflt: OpcodeInfo(3, [false, false, false]), // jflt L1 L2 L3
    GlulxOp.jfle: OpcodeInfo(3, [false, false, false]), // jfle L1 L2 L3
    GlulxOp.jfgt: OpcodeInfo(3, [false, false, false]), // jfgt L1 L2 L3
    GlulxOp.jfge: OpcodeInfo(3, [false, false, false]), // jfge L1 L2 L3
    GlulxOp.jisnan: OpcodeInfo(2, [false, false]), // jisnan L1 L2
    GlulxOp.jisinf: OpcodeInfo(2, [false, false]), // jisinf L1 L2
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
    // Default 0 operands to avoid crash, will likely fail execution if it was supposed to have operands.
  }
}
