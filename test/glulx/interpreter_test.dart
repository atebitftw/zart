import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/zart.dart' show Debugger;

import 'test_terminal_display.dart';

final maxSteps = Debugger
    .maxSteps; // do not change this without getting permission from user.

void main() {
  group('GlulxInterpreter', () {
    late GlulxInterpreter interpreter;

    // Helper to create valid header and code
    Uint8List createGame(List<int> code) {
      final size = 256; // Minimum nice size
      final bytes = Uint8List(size);
      final bd = ByteData.sublistView(bytes);

      // Magic 'Glul'
      bd.setUint32(0, 0x476C756C);
      // Version 3.1.2 (0x00030102)
      bd.setUint32(4, 0x00030102);
      // RAM Start to 256 (everything is RAM for simplicity in test?)
      // Actually code is usually ROM. RAM start must be 256 aligned?
      // Let's set RAM start to 0x40 (64 bytes header/tables).
      // Code will be at 0x40.
      bd.setUint32(8, 0x40); // RAM Start
      bd.setUint32(12, size); // Ext Start
      bd.setUint32(16, size); // End Mem
      bd.setUint32(20, 1024); // Stack Size
      bd.setUint32(24, 0x40); // Start Func

      // Add function header: Type C0 (stack args), Locals 0,0 (no locals)
      bytes[0x40] = 0xC0;
      bytes[0x41] = 0x00;
      bytes[0x42] = 0x00;

      // Copy code to 0x43 (after function header)
      for (int i = 0; i < code.length; i++) {
        bytes[0x43 + i] = code[i];
      }

      return bytes;
    }

    test('add opcode', () async {
      // 0x10: add L1 L2 S1
      // L1: const 5 (mode 1, byte 5)
      // L2: const 10 (mode 1, byte 10)
      // S1: stack (mode 8)
      // Quit (0x120)

      // Encoding:
      // Opcode 0x10 (1 byte)
      // Operands descriptors: 3 operands.
      // DestType byte: (Mode1 << 4) | Mode1 ? No.
      // Opcode 0x10 has 3 operands.
      // Rule: "The operand addressing modes... encoded in bytes following opcode."
      // "One byte for every two operands."
      // Ops: L1(5), L2(10), S1(Stack)
      // 1st byte: (Mode1 | Mode2<<4) ?? No.
      // Spec: "Lower 4 bits are mode of first operand. Upper 4 bits are mode of second operand."
      // Byte 1: (Mode1) | (Mode2 << 4)
      // Byte 2: (Mode3) | (Mode4 << 4)

      // Modes:
      // L1: 1 (Const byte 5)
      // L2: 1 (Const byte 10)
      // S1: 8 (Stack)

      // Byte 1: 0x1 | (0x1 << 4) = 0x11
      // Byte 2: 0x8 | (0x0 << 4) = 0x08

      // Data: 5, 10

      final code = [
        GlulxOp.add, // add
        0x11, // Modes for L1, L2
        0x08, // Mode for S1
        5, // L1 val
        10, // L2 val

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF, // Quit
        // Opcode encoding:
        // 00..7F: 1 byte
        // 8000..BFFF: 2 bytes (big endian) -> (Op - 0x8000) ??
        // Spec: "Codes 00..7F encoded as single bytes 00..7F"
        // "Codes 0000..3FFF encoded as two bytes 80..BF, 00..FF"
        // 0x120 is between 0 and 3FFF.
        // So encoded as 2 bytes:
        // Byte 0: 0x80 | High part of opcode.
        // 0x120 = 0001 0010 0000.
        // High 6 bits of 0x120? No.
        // "Value is (B0 & 0x7F) << 8 | B1"
        // So B0 should be 0x80 | (0x120 >> 8) = 0x81
        // B1 should be 0x120 & 0xFF = 0x20
        // So 0x81, 0x20.
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF, // Quit
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Result should be on stack: 15
      // Access stack via private generic? Or methods?
      // I can't access _stack easily.
      // I should write to RAM instead and check RAM.
      // S1: RAM address 0x50 (Mode 5, byte 0x50) (offset from 0? No, absolute 0x50)

      // Update test to write to RAM 0x80 (inside header/padding area, safe for test?)
      // Header is 36 bytes. 0x40 is StartFunc.
      // RAM starts at 0x40 (header says).
      // If code is at 0x40, writing to 0x80 is fine (assuming code is small).

      // S1: Mode 5 (Contents of Address 00-FF).
      // This mode means: Argument is the Address.
      // Value is stored AT that address.
      // Arg: 0x80.
    });

    test('add opcode write to ram', () async {
      // add 5 10 -> RAM[0x80]
      final code = [
        GlulxOp.add, // add
        0x11, // Modes 1, 1
        0x05, // Mode 5 (RAM byte addr)
        5, // L1
        10, // L2
        0x80, // S1 addr

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF, // quit
      ];

      interpreter = GlulxInterpreter();
      // expose way to read memory? No public API.
      // But for unit test I can modify interpreter to expose it or make _memory public?
      // Or specific test method in interpreter?
      // Or extend Interpreter.

      // I will use `load` to setup.
      // BUT I can't check the result without access to memory.
      // I'll assume success if it runs without exception for now.
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // We know from the code that 5 + 10 = 15 is stored at RAM address 0x80.
      expect(interpreter.memRead32(0x80), equals(15));
    });

    test('add opcode with stack (indirect)', () async {
      // Original test tried to read from stack but couldn't verify.
      // We can pop the result from stack into RAM to verify.
      final code = [
        GlulxOp.add, // add
        0x11, // Modes for L1, L2
        0x08, // Mode for S1 (Stack)
        5, // L1 val
        10, // L2 val
        // Now pop result from stack to RAM 0x80
        // copy: L1 S1.
        // L1: Stack (8). S1: RAM 0x80 (Mode 5, Byte 0x80).
        // Mode Byte: 8 | (5<<4) = 0x58.
        GlulxOp.copy, 0x58, 0x80,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF, // Quit
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(15));
    });

    test('jump opcode', () async {
      // jump 4 (skip next instruction)
      // next instr: quit (incorrectly formatted to cause crash?)
      // target instr: quit (correct)

      // jump 0x20. Mode 1 (const byte) = 4.
      // Enc: 0x20, 0x01, 0x04.
      // Current PC points to next instr.
      // Offset 4 means skipping 4 bytes.

      // Code:
      // 0: jump 4
      // 3: invalid/crash (0xFF)
      // 4: crash
      // 5: crash
      // 6: crash
      // 7: quit

      // Wait. Offset is relative to *next instruction*.
      // jump is at 0. len 3. next is 3.
      // Offset 4 from 3 = 7.
      // So instruction at 7 is executed.

      final code = [
        GlulxOp.jump, 0x01, 0x06, // jump 4
        0xFF, 0xFF, 0xFF, 0xFF, // Garbage
        GlulxOp.quit >> 8 & 0x7F | 0x80,
        GlulxOp.quit & 0xFF, // quit (at index 7)
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);
    });
    test('sub mul div mod neg', () async {
      // sub 10 3 -> RAM[0x80] (7)
      // mul 4 4 -> RAM[0x84] (16)
      // div 20 5 -> RAM[0x88] (4)
      // mod 10 3 -> RAM[0x8C] (1)
      // neg 5 -> RAM[0x90] (-5 via unsigned? 0xFFFFFFFB)

      final code = [
        GlulxOp.sub,
        0x11,
        0x05,
        10,
        3,
        0x80,
        GlulxOp.mul,
        0x11,
        0x05,
        4,
        4,
        0x84,
        GlulxOp.div,
        0x11,
        0x05,
        20,
        5,
        0x88,
        GlulxOp.mod,
        0x11,
        0x05,
        10,
        3,
        0x8C,
        GlulxOp.neg,
        0x51, // Mode1=1, Mode2=5. 1 | 5<<4 = 0x51.
        5,
        0x90,
        GlulxOp.quit >> 8 & 0x7F | 0x80,
        GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(7));
      expect(interpreter.memRead32(0x84), equals(16));
      expect(interpreter.memRead32(0x88), equals(4));
      expect(interpreter.memRead32(0x8C), equals(1));
      // -5 in 32-bit signed 2's complement is 0xFFFFFFFB = 4294967291 unsigned
      // memRead32 returns unsigned 32-bit int from ByteData.getUint32
      // -5 & 0xFFFFFFFF = 4294967291
      expect(interpreter.memRead32(0x90), equals(4294967291));
    });

    test('bitwise opcodes', () async {
      // bitand 0x0F 0x03 -> RAM[0x80] (0x03)
      // bitor 0x01 0x02 -> RAM[0x84] (0x03)
      // bitxor 0x03 0x01 -> RAM[0x88] (0x02)
      // bitnot 0x00 -> RAM[0x8C] (0xFFFFFFFF)

      final code = [
        GlulxOp.bitand,
        0x11,
        0x05,
        0x0F,
        0x03,
        0x80,
        GlulxOp.bitor,
        0x11,
        0x05,
        0x01,
        0x02,
        0x84,
        GlulxOp.bitxor,
        0x11,
        0x05,
        0x03,
        0x01,
        0x88,
        GlulxOp.bitnot,
        0x51, // Mode1=1, Mode2=5.
        0x00,
        0x8C,
        GlulxOp.quit >> 8 & 0x7F | 0x80,
        GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(0x03));
      expect(interpreter.memRead32(0x84), equals(0x03));
      expect(interpreter.memRead32(0x88), equals(0x02));
      expect(interpreter.memRead32(0x8C), equals(0xFFFFFFFF));
    });
    test('branching opcodes', () async {
      // jz 0 label1 (jump 2)
      // label1: nop (just pass)
      // jnz 1 label2 (jump 2)
      // label2: nop
      // ... and so on.

      // To verify branches, I'll write to memory if branch is NOT taken when it should be.
      // Or I can use a pattern where if branch is taken it jumps over a "trap" (e.g. quit or write error).

      // Test: jz 0 (take), jnz 0 (no take), jeq 5 5 (take), jne 5 6 (take)
      // RAM[0x80] = 0 initially.
      // If fail, write 1 to 0x80.

      final code = [
        // jz: 2 ops. Mode 1 (const), Mode 1 (const). -> 0x11.
        // Val=0. Off=4.
        GlulxOp.jz, 0x11, 0x00, 0x06,
        // Fail block. copy 1 RAM[80].
        // Op 40. Mode 1, Mode 5 -> 0x51.
        GlulxOp.copy, 0x51, 0x01, 0x80,

        // jnz 1, 4. Mode 1, 1 -> 0x11.
        GlulxOp.jnz, 0x11, 0x01, 0x06,
        // Fail block. copy 2 RAM[80].
        GlulxOp.copy, 0x51, 0x02, 0x80,

        // jeq 5 5 4. Mode 1, 1, 1. -> 0x11 0x01.
        GlulxOp.jeq, 0x11, 0x01, 0x05, 0x05, 0x06,
        // Fail block. copy 3 RAM[80].
        GlulxOp.copy, 0x51, 0x05, 0x80,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(0)); // Should remain 0
    });

    test('branch comparison opcodes', () async {
      // Test jlt, jge, jgt, jle (Signed)
      // Test jltu, jgeu (Unsigned)
      // jne

      // Plan:
      // jne 5 6 +3 (take)
      // jne 5 5 +3 (no take, fail)

      // jlt -1 0 +3 (take) -> -1 < 0
      // jgt -1 0 +3 (no take) -> -1 > 0 is false

      // jltu -1 0 +3 (no take) -> 0xFFFFFFFF < 0 is false.
      // jgtu ... (not in list? Jgt is same?) No jgtu. Only jltu, jgeu.

      final code = [
        // jne 5 6 (True) -> +4.
        GlulxOp.jne, 0x11, 0x01, 5, 6, 6,
        GlulxOp.copy, 0x51, 0x01, 0xE0, // Error 1
        // jeq 5 5 (True) -> +4
        GlulxOp.jeq, 0x11, 0x01, 5, 5, 6,
        GlulxOp.copy, 0x51, 0x02, 0xE0, // Error 2
        // jlt -1 10 (True) -> +4. (-1 < 10)
        GlulxOp.jlt, 0x11, 0x01, 0xFF, 10, 6,
        GlulxOp.copy, 0x51, 0x05, 0xE0, // Error 3
        // jle 10 10 (True) -> +4
        GlulxOp.jle, 0x11, 0x01, 10, 10, 6,
        GlulxOp.copy, 0x51, 0x06, 0xE0, // Error 4
        // jgt 10 -1 (True) -> +4 (10 > -1)
        GlulxOp.jgt, 0x11, 0x01, 10, 0xFF, 6,
        GlulxOp.copy, 0x51, 0x05, 0xE0, // Error 5
        // jge 10 10 (True) -> +4
        GlulxOp.jge, 0x11, 0x01, 10, 10, 6,
        GlulxOp.copy, 0x51, 0x06, 0xE0, // Error 6
        // jltu 10 255 (True) -> +4 (10 < 255 unsigned)
        GlulxOp.jltu, 0x11, 0x01, 10, 0xFF, 6,
        GlulxOp.copy, 0x51, 0x07, 0xE0, // Error 7
        // jgeu 255 10 (True) -> +4.
        GlulxOp.jgeu, 0x11, 0x01, 0xFF, 10, 6,
        GlulxOp.copy, 0x51, 0x08, 0xE0, // Error 8

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0xE0), equals(0));
    });

    test('branch not taken', () async {
      //Verify execution falls through when branch condition is false
      final code = [
        // jz 1 (False) -> +4. Fallthrough.
        GlulxOp.jz, 0x11, 0x01, 0x06,
        // Write 1 to RAM[80] (Success mark)
        GlulxOp.copy, 0x51, 0x01, 0x80,

        // jnz 0 (False) -> +4. Fallthrough.
        GlulxOp.jnz, 0x11, 0x00, 0x06,
        // Write 2 to RAM[84]
        GlulxOp.copy, 0x51, 0x02, 0x84,

        // jeq 5 6 (False) -> +4. Fallthrough.
        GlulxOp.jeq, 0x11, 0x01, 0x05, 0x06, 0x06,
        // Write 3 to RAM[88]
        GlulxOp.copy, 0x51, 0x03, 0x88,

        // jne 5 5 (False) -> +4. Fallthrough.
        GlulxOp.jne, 0x11, 0x01, 0x05, 0x05, 0x06,
        // Write 4 to RAM[8C]
        GlulxOp.copy, 0x51, 0x04, 0x8C,

        // jlt 10 5 (False) -> +4. Fallthrough.
        GlulxOp.jlt, 0x11, 0x01, 0x0A, 0x05, 0x06,
        // Write 5 to RAM[90]
        GlulxOp.copy, 0x51, 0x05, 0x90,

        // jge 5 10 (False) -> +4. Fallthrough.
        GlulxOp.jge, 0x11, 0x01, 0x05, 0x0A, 0x06,
        // Write 6 to RAM[94]
        GlulxOp.copy, 0x51, 0x06, 0x94,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(1));
      expect(interpreter.memRead32(0x84), equals(2));
      expect(interpreter.memRead32(0x88), equals(3));
      expect(interpreter.memRead32(0x8C), equals(4));
      expect(interpreter.memRead32(0x90), equals(5));
      expect(interpreter.memRead32(0x94), equals(6));
    });

    test('copy opcodes', () async {
      // copy 0x12345678 -> RAM[0x80]
      // copyb 0xFF -> RAM[0x84] (should only write byte)
      // copys 0xFFFF -> RAM[0x88] (should only write short)

      // copy: 40 L1 S1
      // copyb: 42 L1 S1
      // copys: 41 L1 S1

      // wait, let's fix opcode construction
      final codeCorrect = [
        GlulxOp.copy,
        0x53,
        0x12,
        0x34,
        0x56,
        0x78,
        0x80,
        GlulxOp.copyb,
        0x51,
        0xFF,
        0x84,
        GlulxOp.copys,
        0x52,
        0xFF,
        0xFF,
        0x88,
        GlulxOp.quit >> 8 & 0x7F | 0x80,
        GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(codeCorrect));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(0x12345678));
      // copyb writes byte. RAM initialized to 0.
      // 0x84 was 0. Write FF to 0x84.
      // memRead32(0x84) -> 0x000000FF ? No, Big Endian.
      // 84: FF, 85: 00, 86: 00, 87: 00. -> 0xFF000000.
      // Wait.
      // _memWrite8(0x84, 0xFF).
      // ByteData.getUint32(0x84) -> [FF, 00, 00, 00] (if rest 0).
      expect(interpreter.memRead32(0x84), equals(0xFF000000));

      // copys writes 0xFFFF to 0x88.
      // 88: FF FF 00 00. -> 0xFFFF0000.

      expect(interpreter.memRead32(0x88), equals(0xFFFF0000));
    });

    test('glk opcode', () async {
      // Test glk opcode with production provider using real gestalt selector
      // glk(id, numargs) -> res
      // Arguments found on stack.
      // Opcode 0x130.
      // We'll call gestalt(0, 0) which returns the Glk version 0x00070600

      final code = [
        // Push args to stack in reverse order: val=0, sel=0
        // Push 0 (val)
        GlulxOp.copy, 0x81, 0,
        // Push 0 (sel = version)
        GlulxOp.copy, 0x81, 0,

        // glk gestalt(4), 2 args -> RAM[0x80]
        // Modes: Op1(1)|Op2(1)<<4 = 0x11. Op3(5) = 0x05.
        // Opcode 0x130 is 2 bytes: 0x81, 0x30.
        // Selector 4 (gestalt), 2 args
        GlulxOp.glk >> 8 | 0x80,
        GlulxOp.glk & 0xFF,
        0x11,
        0x05,
        GlkIoSelectors.gestalt,
        0x02,
        0x80,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      final testDisplay = TestTerminalDisplay();
      final ioProvider = GlulxTerminalProvider(testDisplay);
      interpreter = GlulxInterpreter(io: ioProvider);
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Should return Glk version 0x00070600
      expect(interpreter.memRead32(0x80), equals(0x00070600));
    });

    test('streamchar uses io provider', () async {
      final code = [
        GlulxOp.streamchar, 0x01, 0x41, // 'A'
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      final testDisplay = TestTerminalDisplay();
      final ioProvider = GlulxTerminalProvider(testDisplay);
      interpreter = GlulxInterpreter(io: ioProvider);
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Verify that 'A' was output through the production IO provider
      expect(testDisplay.output, equals('A'));
    });

    test('shift opcodes', () async {
      final code = [
        // shiftl 1 1 -> RAM[0x80] (2)
        GlulxOp.shiftl, 0x11, 0x05, 1, 1, 0x80,
        // sshiftr -2 1 -> RAM[0x84] (-1)
        // -2 is 0xFFFFFFFE. >> 1 should be 0xFFFFFFFF (-1).
        GlulxOp.sshiftr, 0x11, 0x05, 0xFE, 1, 0x84,
        // Note: 0xFE as byte constant is -2 signed? Mode 1 is byte.
        // Interpreter logic: if (value > 127) value -= 256;
        // So 0xFE (254) becomes -2. Correct.

        // ushiftr -2 1 -> RAM[0x88]
        // -2 (0xFFFFFFFE) >>> 1 = 0x7FFFFFFF (2147483647).
        GlulxOp.ushiftr, 0x11, 0x05, 0xFE, 1, 0x88,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(2));
      // -1 unsigned is 0xFFFFFFFF
      expect(interpreter.memRead32(0x84), equals(0xFFFFFFFF));
      expect(interpreter.memRead32(0x88), equals(0x7FFFFFFF));
    });

    test('sexs/sexb opcodes', () async {
      final code = [
        // sexb 0xFF -> RAM[0x80] (-1)
        // sexb L1(Const Byte - Mode 1) S1(Addr 0-FF - Mode 5)
        // Byte 1: 1 | (5 << 4) = 0x51.
        GlulxOp.sexb, 0x51, 0xFF, 0x80,
        // sexs 0xFFFF -> RAM[0x84] (-1)
        // Need to pass 0xFFFF. Mode 2 (short const) 0xFFFF.
        // Byte 1: Mode2=2. Mode2=5. -> 0x52.
        // Short: FF FF.
        GlulxOp.sexs, 0x52, 0xFF, 0xFF, 0x84,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(0xFFFFFFFF));
      expect(interpreter.memRead32(0x84), equals(0xFFFFFFFF));
    });

    test('array opcodes', () async {
      // Setup memory:
      // index 0: 0x10101010
      // index 1: 0x20202020
      // We will write these using `copy` first or manually in setup?
      // `createGame` copies code to 0x40.
      // We can use `astore` to write them.

      // But we want to test `astore`...

      final code = [
        // astore 0xC0 0 0x10101010
        // L1(const 0xC0), L2(const 0), L3(const long 0x10101010)
        // L1 must be positive. 0xC0 as Mode 1 is -64.
        // Use Mode 2 for L1 (0x00C0).
        // Modes: L1(2), L2(1) -> 2 | 1<<4 = 0x12.
        // L3(3). -> 0x03.
        GlulxOp.astore, 0x12, 0x03, 0x00, 0xC0, 0x00,
        0x10, 0x10, 0x10, 0x10, // Value 0x10101010
        // astore 0xC0 1 0x20202020
        // Addr = 0xC0 + 4*1 = 0xC4.
        GlulxOp.astore, 0x12, 0x03, 0x00, 0xC0, 0x01,
        0x20, 0x20, 0x20, 0x20,

        // Now read back with aload
        // aload 0xC0 0 -> RAM[0xD0]
        GlulxOp.aload, 0x12, 0x05, 0x00, 0xC0, 0x00, 0xD0,

        // aload 0xC0 1 -> RAM[0xD4]
        GlulxOp.aload, 0x12, 0x05, 0x00, 0xC0, 0x01, 0xD4,

        // Test astores / aloads
        // astores 0xE0 0 0x3344
        // Mode 2 for E0.
        GlulxOp.astores, 0x12, 0x02, 0x00, 0xE0, 0x00, 0x33, 0x44,

        // aloads 0xE0 0 -> RAM[0xD8]
        GlulxOp.aloads, 0x12, 0x05, 0x00, 0xE0, 0x00, 0xD8,

        // Test astoreb / aloadb
        // astoreb 0xF0 0 0x55
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xF0, 0x00, 0x55,

        // aloadb 0xF0 0 -> RAM[0xDC]
        GlulxOp.aloadb, 0x12, 0x05, 0x00, 0xF0, 0x00, 0xDC,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0xD0), equals(0x10101010));
      expect(interpreter.memRead32(0xD4), equals(0x20202020));

      // aloads zero extends.
      expect(interpreter.memRead32(0xD8), equals(0x3344));

      // aloadb zero extends.
      expect(interpreter.memRead32(0xDC), equals(0x55));

      // Verify memory directly too
      expect(interpreter.memRead32(0xC0), equals(0x10101010));
      // 0xE0: 33 44
      // memRead32(0xA0) gets 4 bytes at A0. A0, A1, A2, A3.
      // We wrote short (2 bytes) to A0. So A0, A1 are 33, 44.
      // A2, A3 are 0.
      // So 0x33440000.
      expect(interpreter.memRead32(0xE0) & 0xFFFF0000, equals(0x33440000));
    });

    test('mzero opcode', () async {
      // First write some non-zero values to RAM[0xC0..0xC3]
      // Then zero 4 bytes with mzero
      final code = [
        // Write 0xAA to RAM[0xC0]
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x00, 0xAA,
        // Write 0xBB to RAM[0xC1]
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x01, 0xBB,
        // Write 0xCC to RAM[0xC2]
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x02, 0xCC,
        // Write 0xDD to RAM[0xC3]
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x03, 0xDD,

        // mzero 4 0xC0
        // Opcode 0x170 -> 2 bytes: 0x81, 0x70
        // Modes: L1(1), L2(2) -> 0x21
        GlulxOp.mzero >> 8 | 0x80, GlulxOp.mzero & 0xFF, 0x21, 4, 0x00, 0xC0,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // All 4 bytes should be 0
      expect(interpreter.memRead32(0xC0), equals(0));
    });

    test('mcopy opcode non-overlapping', () async {
      // Write 4 bytes to RAM[0xC0], copy to RAM[0xD0]
      final code = [
        // astore 0xC0 0 0x12345678
        GlulxOp.astore, 0x12, 0x03, 0x00, 0xC0, 0x00,
        0x12, 0x34, 0x56, 0x78,

        // mcopy 4 0xC0 0xD0
        // Opcode 0x171 -> 2 bytes: 0x81, 0x71
        // Modes: L1(1), L2(2), L3(2) -> 0x21, 0x02
        GlulxOp.mcopy >> 8 | 0x80,
        GlulxOp.mcopy & 0xFF,
        0x21,
        0x02,
        4,
        0x00,
        0xC0,
        0x00,
        0xD0,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Source unchanged
      expect(interpreter.memRead32(0xC0), equals(0x12345678));
      // Destination has the copy
      expect(interpreter.memRead32(0xD0), equals(0x12345678));
    });

    test('mcopy opcode overlapping forward', () async {
      // Write bytes, then copy with dest < src (forward copy)
      // RAM[0xC0..0xC3] = AA BB CC DD
      // mcopy 4, 0xC0, 0xBE (copies to 0xBE-0xC1, overlaps with source)
      final code = [
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x00, 0xAA,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x01, 0xBB,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x02, 0xCC,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x03, 0xDD,

        // mcopy 4 0xC0 0xBE
        GlulxOp.mcopy >> 8 | 0x80,
        GlulxOp.mcopy & 0xFF,
        0x21,
        0x02,
        4,
        0x00,
        0xC0,
        0x00,
        0xBE,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // 0xBE should now have AA BB CC DD
      expect(interpreter.memRead32(0xBE), equals(0xAABBCCDD));
    });

    test('mcopy opcode overlapping backward', () async {
      // Write bytes, then copy with dest > src (backward copy)
      // RAM[0xC0..0xC3] = AA BB CC DD
      // mcopy 4, 0xC0, 0xC2 (dest > src, overlaps)
      final code = [
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x00, 0xAA,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x01, 0xBB,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x02, 0xCC,
        GlulxOp.astoreb, 0x12, 0x01, 0x00, 0xC0, 0x03, 0xDD,

        // mcopy 4 0xC0 0xC2
        GlulxOp.mcopy >> 8 | 0x80,
        GlulxOp.mcopy & 0xFF,
        0x21,
        0x02,
        4,
        0x00,
        0xC0,
        0x00,
        0xC2,

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // 0xC2 should have AA BB CC DD (copied correctly despite overlap)
      expect(interpreter.memRead32(0xC2), equals(0xAABBCCDD));
    });

    test('nop opcode', () async {
      // nop should do nothing and continue execution
      final code = [
        GlulxOp.nop,
        GlulxOp.copy, 0x51, 42, 0x80, // copy 42 -> RAM[0x80]
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x80), equals(42));
    });

    test('astorebit opcode', () async {
      // astorebit L1 L2 L3: sets/clears bit L2 at address L1 to value L3
      // Opcode: 0x4F (single byte, < 0x80)
      // 3 operands: mode bytes = (op1 | op2<<4), (op3 | 0<<4)
      // Using mode 1 (const byte) for all: 0x11, 0x01
      // Use address 0x60 to avoid overwriting code which ends at 0x51
      final game = createGame([
        // astorebit 0x60 0 1 (set bit 0 at addr 0x60)
        GlulxOp.astorebit, 0x11, 0x01, 0x60, 0x00, 0x01,
        // astorebit 0x60 7 1 (set bit 7 at addr 0x60)
        GlulxOp.astorebit, 0x11, 0x01, 0x60, 0x07, 0x01,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // Pre-zero the target address
      game[0x60] = 0x00;

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      // After setting bits 0 and 7, memory[0x60] should be 0x81 (0b10000001)
      // memRead32 reads big-endian, so 0x60 byte will be in upper byte
      expect(interpreter.memRead32(0x60) >> 24 & 0xFF, equals(0x81));
    });

    test('streamunichar opcode', () async {
      // Set iosys to Glk mode (2), then output a unicode char
      final code = [
        // setiosys 2 0 (Glk mode)
        // setiosys: 0x149 -> 0x81, 0x49
        // modes: L1=mode1, L2=mode0 -> 0x01
        GlulxOp.setiosys >> 8 | 0x80, GlulxOp.setiosys & 0xFF, 0x01, 0x02,
        // streamunichar 0x41 ('A')
        // streamunichar: 0x73, mode1
        GlulxOp.streamunichar, 0x01, 0x41,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      final testDisplay = TestTerminalDisplay();
      final ioProvider = GlulxTerminalProvider(testDisplay);
      interpreter = GlulxInterpreter(io: ioProvider);
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Verify 'A' was output through production IO provider
      expect(testDisplay.output, equals('A'));
    });

    test('debugtrap opcode', () async {
      // debugtrap should not crash, just continue
      final code = [
        GlulxOp.debugtrap >> 8 & 0x7F | 0x80, GlulxOp.debugtrap & 0xFF,
        0x01, 0x42, // arg: 0x42
        GlulxOp.copy, 0x51, 99, 0x70, // write to 0x70 (< 0x80)
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x70), equals(99));
    });

    test('setrandom opcode', () async {
      // Set seed, get random, set same seed, get random again - should match
      final code = [
        // setrandom 12345
        // setrandom: 0x111 -> 0x81, 0x11
        // mode 2 (16-bit const): 0x02
        GlulxOp.setrandom >> 8 & 0x7F | 0x80, GlulxOp.setrandom & 0xFF,
        0x02, 0x30, 0x39, // 0x3039 = 12345
        // random 100 -> RAM[0x70]
        // random: 0x110 -> 0x81, 0x10
        // modes: L1=mode1, S1=mode5 -> 0x51
        GlulxOp.random >> 8 & 0x7F | 0x80, GlulxOp.random & 0xFF,
        0x51, 100, 0x70,
        // setrandom 12345 again
        GlulxOp.setrandom >> 8 & 0x7F | 0x80, GlulxOp.setrandom & 0xFF,
        0x02, 0x30, 0x39,
        // random 100 -> RAM[0x74]
        GlulxOp.random >> 8 & 0x7F | 0x80, GlulxOp.random & 0xFF,
        0x51, 100, 0x74,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // With same seed, should get same random number
      expect(interpreter.memRead32(0x70), equals(interpreter.memRead32(0x74)));
    });

    test('verify opcode', () async {
      // verify always returns 0 (success) in our stub implementation
      final code = [
        GlulxOp.verify >> 8 & 0x7F | 0x80, GlulxOp.verify & 0xFF,
        0x05, 0x70, // S1 = RAM[0x70]
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x70), equals(0)); // 0 = success
    });

    test('callf opcode', () async {
      // Call a function at 0x70 with no args, returns 42
      final game = createGame([
        // callf 0x70 -> RAM[0x60]
        // callf: 0x160 -> 0x81, 0x60
        // modes: L1=mode1, S1=mode5 -> 0x51
        GlulxOp.callf >> 8 | 0x80, GlulxOp.callf & 0xFF, 0x51, 0x70, 0x60,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // Place function at 0x70
      game[0x70] = 0xC1; // Type C1
      game[0x71] = 0x00; // No locals
      game[0x72] = 0x00;
      // return 42
      game[0x73] = GlulxOp.ret;
      game[0x74] = 0x01; // mode 1 (const byte)
      game[0x75] = 42;

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x60), equals(42));
    });

    test('callfi opcode', () async {
      // Call a function at 0x70 with 1 arg (5), returns arg + 10
      final game = createGame([
        // callfi 0x70 5 -> RAM[0x60]
        // callfi: 0x161 -> 0x81, 0x61
        // modes: L1=mode1, L2=mode1, S1=mode5 -> 0x11, 0x05
        GlulxOp.callfi >> 8 | 0x80,
        GlulxOp.callfi & 0xFF,
        0x11,
        0x05,
        0x70,
        5,
        0x60,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // Function at 0x70: Type C1, 1 local (4 bytes), add 10 to arg
      game[0x70] = 0xC1;
      game[0x71] = 0x04; // 1 local, 4 bytes
      game[0x72] = 0x01; // 1 count
      game[0x73] = 0x00;
      game[0x74] = 0x00;
      // add local0 10 -> stack, then return
      game[0x75] = GlulxOp.add;
      game[0x76] = 0x19; // mode 9 (local 0-FF), mode 1
      game[0x77] = 0x08; // mode 8 (stack)
      game[0x78] = 0x00; // local offset 0
      game[0x79] = 10; // const 10
      game[0x7A] = GlulxOp.ret;
      game[0x7B] = 0x08; // pop from stack

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x60), equals(15)); // 5 + 10
    });

    test('callfii opcode', () async {
      // Call function with 2 args (6, 7), returns arg1 * arg2
      final game = createGame([
        // callfii 0x70 6 7 -> RAM[0x60]
        // callfii: 0x162 -> 0x81, 0x62
        // 4 operands: L1, L2, L3, S1
        // modes: L1=mode1 | L2=mode1<<4 = 0x11, L3=mode1 | S1=mode5<<4 = 0x51
        GlulxOp.callfii >> 8 | 0x80,
        GlulxOp.callfii & 0xFF,
        0x11,
        0x51,
        0x70,
        6,
        7,
        0x60,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // Function at 0x70: 2 locals
      game[0x70] = 0xC1;
      game[0x71] = 0x04;
      game[0x72] = 0x02; // 2 locals
      game[0x73] = 0x00;
      game[0x74] = 0x00;
      // mul local0 local1 -> stack
      game[0x75] = GlulxOp.mul;
      game[0x76] = 0x99; // local, local
      game[0x77] = 0x08; // stack
      game[0x78] = 0x00; // local0
      game[0x79] = 0x04; // local1 (4 bytes offset)
      game[0x7A] = GlulxOp.ret;
      game[0x7B] = 0x08; // mode 8 - pop from stack

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x60), equals(42)); // 6 * 7
    });

    test('callfiii opcode', () async {
      // Call function with 3 args (10, 20, 12), returns arg1 + arg2 + arg3
      final game = createGame([
        // callfiii 0x70 10 20 12 -> RAM[0x60]
        // callfiii: 0x163 -> 0x81, 0x63
        // modes: L1=mode1, L2=mode1, L3=mode1, L4=mode1, S1=mode5 -> 0x11, 0x11, 0x05
        GlulxOp.callfiii >> 8 | 0x80,
        GlulxOp.callfiii & 0xFF,
        0x11,
        0x11,
        0x05,
        0x70,
        10,
        20,
        12,
        0x60,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // Function at 0x70: 3 locals
      game[0x70] = 0xC1;
      game[0x71] = 0x04;
      game[0x72] = 0x03; // 3 locals
      game[0x73] = 0x00;
      game[0x74] = 0x00;
      // add local0 local1 -> stack
      game[0x75] = GlulxOp.add;
      game[0x76] = 0x99;
      game[0x77] = 0x08;
      game[0x78] = 0x00;
      game[0x79] = 0x04;
      // add stack local2 -> stack
      game[0x7A] = GlulxOp.add;
      game[0x7B] = 0x98;
      game[0x7C] = 0x08;
      game[0x7D] = 0x08;
      game[0x7E] = GlulxOp.ret;
      game[0x7F] = 0x08;

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x60), equals(42)); // 10 + 20 + 12
    });

    test('tailcall opcode', () async {
      // Main calls func1 at 0x60, func1 tailcalls func2 at 0x70, func2 returns 99
      final game = createGame([
        // Push arg 5, then call 0x60 with 1 arg -> RAM[0x50]
        GlulxOp.copy, 0x81, 5, // push 5
        // call 0x60 1 -> RAM[0x50]
        // call: 0x30
        // modes: L1=mode1, L2=mode1, S1=mode5 -> 0x11, 0x05
        GlulxOp.call, 0x11, 0x05, 0x60, 1, 0x50,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ]);

      // func1 at 0x60: tailcall to 0x70
      game[0x60] = 0xC0; // stack args
      game[0x61] = 0x00;
      game[0x62] = 0x00;
      // tailcall 0x70 1
      // tailcall: 0x34
      // modes: L1=mode1, L2=mode1 -> 0x11
      game[0x63] = GlulxOp.tailcall;
      game[0x64] = 0x11;
      game[0x65] = 0x70;
      game[0x66] = 1;

      // func2 at 0x70: return 99
      game[0x70] = 0xC0;
      game[0x71] = 0x00;
      game[0x72] = 0x00;
      game[0x73] = GlulxOp.ret;
      game[0x74] = 0x01;
      game[0x75] = 99;

      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(0x50), equals(99));
    });
  });
}
