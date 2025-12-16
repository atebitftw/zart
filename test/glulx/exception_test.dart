import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_opcodes.dart';

// Helper to create a minimal Glulx game file
ByteData createGame(List<int> code, {int ramStart = 0x1000}) {
  final fileSize = 256 + code.length + 0x1000; // Header + Code + Extra
  final buffer = ByteData(fileSize);

  // Magic 47 6c 75 6c
  buffer.setUint32(0, 0x476C756C);
  // RAM Start
  buffer.setUint32(8, ramStart);
  // Extent (File Size)
  buffer.setUint32(12, fileSize);
  // End Mem
  buffer.setUint32(16, fileSize * 2);
  // Stack Size
  buffer.setUint32(20, 4096);
  // Start Func
  buffer.setUint32(24, 0x100); // Code starts at 0x100
  // Decoding Table
  buffer.setUint32(28, 0);
  // Checksum
  buffer.setUint32(32, 0);

  // Write Code at 0x100
  for (int i = 0; i < code.length; i++) {
    buffer.setUint8(0x100 + i, code[i]);
  }

  return buffer;
}

void main() {
  group('Glulx Exception Handling Tests', () {
    late GlulxInterpreter interpreter;

    setUp(() {
      interpreter = GlulxInterpreter();
    });

    test('catch and throw flow', () async {
      // Logic:
      // 0x100: catch Ram[0x1200] (+9) -> Jump to 0x10F
      // 0x108: copy 99 Ram[0x1204] (Executed AFTER throw)
      // 0x10D: return 0
      //
      // 0x10F (Jump Target):
      //        throw 1234 Ram[0x1200]
      //        return 88 (Should not reach)

      final code = [
        // Function Header C0 (Start at 0x100)
        0xC0, 0x00, 0x00, // 0x100, 101, 102
        // 0x103: catch Ram[0x1200], Offset(9)
        // S1=RamOffset(Mode C), L1=Byte(Mode 1). 1C.
        // Length: 1+1+2+1 = 5 bytes. Ends 0x107.
        GlulxOpcodes.catchEx, 0x1C,
        0x02, 0x00, // Dest Offset: 0x200 (RamStart 0x1000 + 0x200 = 0x1200)
        0x09, // Offset 9 (Target 0x10F: 108 + 9 - 2)
        // 0x108 (Next Inst): copy 99 Ram[0x1204]
        // copy (0x40). Modes: S1(C), L1(1). C1.
        // Op0=L1 (Src)=Mode 1. Op1=S1 (Dest)=Mode C.
        // Byte = (C << 4) | 1 = C1.
        // Length: 1+1+1+2 = 5 bytes. Ends 0x10C.
        GlulxOpcodes.copy, 0xC1,
        99, // Source (Mode 1)
        0x02, 0x04, // Dest (Mode C Offset: 0x204)
        // 0x10D: return 0. Mode 00 (Zero).
        // Length: 1+1 = 2 bytes. Ends 0x10E.
        GlulxOpcodes.ret, 0x00,

        // 0x10F (Jump Target): throw 1234 Ram[0x1200]
        // throw (0x33). Modes: L1(2-Short), L2(C-RamOffset). C2.
        // Length: 1+1+2+2 = 6 bytes. Ends 0x114.
        GlulxOpcodes.throwEx, 0xC2,
        0x04, 0xD2, // 1234 (Mode 2)
        0x02, 0x00, // Token Addr Offset (Mode C reads from 0x1200)
        // 0x115: return 88
        GlulxOpcodes.ret, 0x03, 88,
      ];

      interpreter.load(createGame(code, ramStart: 0x1000).buffer.asUint8List());
      await interpreter.run(maxSteps: 1000);

      // 1. Check thrown value (stored in Catch dest 0x1200)
      // Expect 1234.
      expect(interpreter.memRead32(0x1200), equals(1234));

      // 2. Check 0x1204 (Proof that code after catch executed)
      // Expect 99.
      expect(interpreter.memRead32(0x1204), equals(99));
    });
  });
}
