import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  group('Tailcall Regression Test', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;

    setUp(() async {
      interpreter = GlulxInterpreter(TestGlkIoProvider());
    });

    Uint8List createRecursiveTailcallGame() {
      final data = Uint8List(1024);
      // Header
      data.setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]); // Magic
      data.setRange(8, 12, [0x00, 0x00, 0x01, 0x00]); // RAMSTART 0x100
      data.setRange(12, 16, [0x00, 0x00, 0x04, 0x00]); // EXTSTART 0x400
      data.setRange(16, 20, [0x00, 0x00, 0x04, 0x00]); // ENDMEM 0x400
      data.setRange(20, 24, [0x00, 0x00, 0x04, 0x00]); // Stack 0x400

      // Function at 0x100: C1, 1 local (4-byte)
      // Header: C1 04 01 00 00
      data.setAll(0x100, [0xC1, 0x04, 0x01, 0x00, 0x00]);

      // 0x105: jnz local0, skip to 0x10E
      // opcode 0x23 (jnz), modes 0x19 (L1=9, L2=1), local 0, branch offset 7
      data.setAll(0x105, [
        0x23, // jnz
        0x19, // L1=9, L2=1
        0x00, // local 0
        0x07, // branch offset 7 (0x109 + 7 - 2 = 0x10E)
      ]);

      // 0x109: ret 1
      data.setAll(0x109, [
        0x31, // ret
        0x01, // 1-byte const
        0x01, // value 1
      ]);

      // 0x10E: sub local0 1 -(sp)
      // opcode 0x11, modes 0x19, 0x08 (L1=9, L2=1, S1=8), local 0, value 1
      data.setAll(0x10E, [0x11, 0x19, 0x08, 0x00, 0x01]);

      // 0x113: tailcall 0x100 1
      // opcode 0x34, modes 0x13 (L1=3, L2=1), 0x00000100, 1
      data.setAll(0x113, [0x34, 0x13, 0x00, 0x00, 0x01, 0x00, 0x01]);

      // 0x120: Bootstrapper: callfi 0x100 5
      data.setAll(0x120, [
        0x81, 0x61, // callfi (0x161)
        0x12, 0x00, // L1=2 (short), L2=1 (byte), S1=0
        0x01, 0x00, // address 0x100
        0x05, // arg: 5
        0x81, 0x20, // quit (0x120)
      ]);

      return data;
    }

    test('tailcall should not grow stack during recursion', () async {
      final gameData = createRecursiveTailcallGame();
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);

      harness.setProgramCounter(0x120);

      // Check stack pointer before any calls
      final initialSp = interpreter.stack.sp;

      // Execute 'callfi'
      await interpreter.executeInstruction();
      final spAfterCall = interpreter.stack.sp;
      expect(
        spAfterCall,
        greaterThan(initialSp),
        reason: 'Call should push a frame',
      );

      // Now run the recursion.
      // Each tailcall should be stack-neutral.
      int maxSp = 0;
      int steps = 0;
      while (interpreter.pc >= 0x100 && interpreter.pc < 0x127 && steps < 100) {
        // Capture SP at the start of each recursion loop (at entry point)
        if (interpreter.pc == 0x105) {
          expect(
            interpreter.stack.sp,
            equals(spAfterCall),
            reason: 'Stack should be neutral at function entry',
          );
        }

        await interpreter.executeInstruction();
        if (interpreter.stack.sp > maxSp) {
          maxSp = interpreter.stack.sp;
        }
        steps++;
      }

      // Final instruction (quit)
      if (interpreter.pc == 0x127) {
        await interpreter.executeInstruction();
      }

      expect(
        interpreter.pc,
        equals(0x129),
        reason: 'Should have finished recursion at PC 0x129 (after quit)',
      );
      expect(
        maxSp,
        equals(spAfterCall + 4),
        reason: 'Max stack depth should be initial + 1 pushed argument',
      );
    });
  });
}
