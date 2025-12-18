import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/op_code_info.dart';

void main() {
  group('Acceleration Integration', () {
    late GlulxInterpreter interpreter;

    setUp(() {
      interpreter = GlulxInterpreter();
    });

    test('accelparam opcode sets accelerator params', () async {
      final mem = Uint8List(0x20000);
      final bd = ByteData.sublistView(mem);
      bd.setUint32(GlulxHeader.magicNumber, 0x476C756C);
      bd.setUint32(GlulxHeader.version, 0x00030103);
      bd.setUint32(GlulxHeader.ramStart, 0x1000);
      bd.setUint32(GlulxHeader.extStart, 0x20000);
      bd.setUint32(GlulxHeader.endMem, 0x20000);
      bd.setUint32(GlulxHeader.stackSize, 0x1000);
      bd.setUint32(GlulxHeader.startFunc, 0x1000);

      int pc = 0x1000;
      // Function Header
      mem[pc++] = 0xC0; // Type: Stack Arg
      mem[pc++] = 0x00; // LocalType 0
      mem[pc++] = 0x00; // Count 0 (Terminator)

      // Alignment logic in _enterFunction:
      // localsPos = 1001. formatPtr = 1003.
      // (1003 - 1001) % 4 = 2 != 0.
      // formatPtr += 2. -> 1005.
      // (1005 - 1001) % 4 = 0.
      pc = 0x1005;

      // accelparam 7 42
      mem[pc++] = 0x81;
      mem[pc++] = 0x81; // 0x181 accelparam
      mem[pc++] = 0x11; // Mode: ConstByte(1), ConstByte(1) -> 0x11
      mem[pc++] = 0x07; // Param 7
      mem[pc++] = 0x2A; // Value 42

      // quit
      mem[pc++] = 0x81;
      mem[pc++] = 0x20;

      interpreter.load(mem);
      await interpreter.run(maxSteps: 300);

      expect(interpreter.accelerator.params[7], 42);
    });

    test('accelfunc routes call to accelerator', () async {
      final mem = Uint8List(0x20000);
      final bd = ByteData.sublistView(mem);
      bd.setUint32(GlulxHeader.magicNumber, 0x476C756C);
      bd.setUint32(GlulxHeader.version, 0x00030103);
      bd.setUint32(GlulxHeader.ramStart, 0x1000);
      bd.setUint32(GlulxHeader.extStart, 0x20000);
      bd.setUint32(GlulxHeader.endMem, 0x20000);
      bd.setUint32(GlulxHeader.stackSize, 0x1000);
      bd.setUint32(GlulxHeader.startFunc, 0x1000);

      int pc = 0x1000;
      // Function Header
      mem[pc++] = 0xC0; // Type: Stack Arg
      mem[pc++] = 0x00;
      mem[pc++] = 0x00;

      // Alignment
      pc = 0x1005;

      // accelfunc 1, 0x2000
      mem[pc++] = 0x81;
      mem[pc++] = 0x80; // accelfunc 0x180
      mem[pc++] = 0x21; // Mode: Op0=Byte(1), Op1=Short(2) -> 0x21
      mem[pc++] = 0x01; // ID 1
      mem[pc++] = 0x20;
      mem[pc++] = 0x00; // 0x2000 (Big Endian)

      // callfi 0x2000 0x3000 -> Mem[0x5000]
      // callfi: 0x161
      mem[pc++] = 0x81;
      mem[pc++] = 0x61; // callfi
      // Operands: FuncAddr(2000), Arg1(3000), Dest(5000)
      // Modes: Byte 1 (Op0, Op1): Short(2), Short(2) -> 0x22
      // Modes: Byte 2 (Op2): AddrAny(7) (Store) -> 0x07
      mem[pc++] = 0x22;
      mem[pc++] = 0x07;

      // Op0 (FuncAddr)
      mem[pc++] = 0x20;
      mem[pc++] = 0x00; // 0x2000

      // Op1 (Arg1)
      mem[pc++] = 0x30;
      mem[pc++] = 0x00; // 0x3000

      // Op2 (Dest)
      mem[pc++] = 0x00;
      mem[pc++] = 0x00;
      mem[pc++] = 0x50;
      mem[pc++] = 0x00; // 0x5000

      // quit
      mem[pc++] = 0x81;
      mem[pc++] = 0x20;

      // Setup Object at 0x3000 for Z__Region(0x3000) -> 1
      mem[0x3000] = 0x70;

      interpreter.load(mem);
      await interpreter.run(maxSteps: 300);

      expect(interpreter.memRead32(0x5000), 1);
    });
  });
}
