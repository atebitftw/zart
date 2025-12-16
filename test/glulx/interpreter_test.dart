import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_opcodes.dart';
import 'package:zart/src/io/io_provider.dart';

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

      // Copy code to 0x40
      for (int i = 0; i < code.length; i++) {
        bytes[0x40 + i] = code[i];
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
        GlulxOpcodes.add, // add
        0x11, // Modes for L1, L2
        0x08, // Mode for S1
        5, // L1 val
        10, // L2 val

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF, // Quit
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
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF, // Quit
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
        GlulxOpcodes.add, // add
        0x11, // Modes 1, 1
        0x05, // Mode 5 (RAM byte addr)
        5, // L1
        10, // L2
        0x80, // S1 addr

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF, // quit
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
      await interpreter.run();
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
        GlulxOpcodes.jump, 0x01, 0x04, // jump 4
        0xFF, 0xFF, 0xFF, 0xFF, // Garbage
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF, // quit (at index 7)
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();
    });
    test('sub mul div mod neg', () async {
      // sub 10 3 -> RAM[0x80] (7)
      // mul 4 4 -> RAM[0x84] (16)
      // div 20 5 -> RAM[0x88] (4)
      // mod 10 3 -> RAM[0x8C] (1)
      // neg 5 -> RAM[0x90] (-5 via unsigned? 0xFFFFFFFB)

      final code = [
        GlulxOpcodes.sub,
        0x11,
        0x05,
        10,
        3,
        0x80,
        GlulxOpcodes.mul,
        0x11,
        0x05,
        4,
        4,
        0x84,
        GlulxOpcodes.div,
        0x11,
        0x05,
        20,
        5,
        0x88,
        GlulxOpcodes.mod,
        0x11,
        0x05,
        10,
        3,
        0x8C,
        GlulxOpcodes.neg,
        0x51, // Mode1=1, Mode2=5. 1 | 5<<4 = 0x51.
        5,
        0x90,
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80,
        GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
        GlulxOpcodes.bitand,
        0x11,
        0x05,
        0x0F,
        0x03,
        0x80,
        GlulxOpcodes.bitor,
        0x11,
        0x05,
        0x01,
        0x02,
        0x84,
        GlulxOpcodes.bitxor,
        0x11,
        0x05,
        0x03,
        0x01,
        0x88,
        GlulxOpcodes.bitnot,
        0x51, // Mode1=1, Mode2=5.
        0x00,
        0x8C,
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80,
        GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
        GlulxOpcodes.jz, 0x11, 0x00, 0x04,
        // Fail block. copy 1 RAM[80].
        // Op 40. Mode 1, Mode 5 -> 0x51.
        GlulxOpcodes.copy, 0x51, 0x01, 0x80,

        // jnz 1, 4. Mode 1, 1 -> 0x11.
        GlulxOpcodes.jnz, 0x11, 0x01, 0x04,
        // Fail block. copy 2 RAM[80].
        GlulxOpcodes.copy, 0x51, 0x02, 0x80,

        // jeq 5 5 4. Mode 1, 1, 1. -> 0x11 0x01.
        GlulxOpcodes.jeq, 0x11, 0x01, 0x05, 0x05, 0x04,
        // Fail block. copy 3 RAM[80].
        GlulxOpcodes.copy, 0x51, 0x03, 0x80,

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
        GlulxOpcodes.jne, 0x11, 0x01, 5, 6, 4,
        GlulxOpcodes.copy, 0x51, 0x01, 0xE0, // Error 1
        // jeq 5 5 (True) -> +4
        GlulxOpcodes.jeq, 0x11, 0x01, 5, 5, 4,
        GlulxOpcodes.copy, 0x51, 0x02, 0xE0, // Error 2
        // jlt -1 10 (True) -> +4. (-1 < 10)
        GlulxOpcodes.jlt, 0x11, 0x01, 0xFF, 10, 4,
        GlulxOpcodes.copy, 0x51, 0x03, 0xE0, // Error 3
        // jle 10 10 (True) -> +4
        GlulxOpcodes.jle, 0x11, 0x01, 10, 10, 4,
        GlulxOpcodes.copy, 0x51, 0x04, 0xE0, // Error 4
        // jgt 10 -1 (True) -> +4 (10 > -1)
        GlulxOpcodes.jgt, 0x11, 0x01, 10, 0xFF, 4,
        GlulxOpcodes.copy, 0x51, 0x05, 0xE0, // Error 5
        // jge 10 10 (True) -> +4
        GlulxOpcodes.jge, 0x11, 0x01, 10, 10, 4,
        GlulxOpcodes.copy, 0x51, 0x06, 0xE0, // Error 6
        // jltu 10 255 (True) -> +4 (10 < 255 unsigned)
        GlulxOpcodes.jltu, 0x11, 0x01, 10, 0xFF, 4,
        GlulxOpcodes.copy, 0x51, 0x07, 0xE0, // Error 7
        // jgeu 255 10 (True) -> +4.
        GlulxOpcodes.jgeu, 0x11, 0x01, 0xFF, 10, 4,
        GlulxOpcodes.copy, 0x51, 0x08, 0xE0, // Error 8

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

      expect(interpreter.memRead32(0xE0), equals(0));
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
        GlulxOpcodes.copy,
        0x53,
        0x12,
        0x34,
        0x56,
        0x78,
        0x80,
        GlulxOpcodes.copyb,
        0x51,
        0xFF,
        0x84,
        GlulxOpcodes.copys,
        0x52,
        0xFF,
        0xFF,
        0x88,
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80,
        GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(codeCorrect));
      await interpreter.run();

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
      // glk(id, numargs) -> res
      // Arguments found on stack.
      // Opcode 0x130.
      // Example: glk(0x123, 2). Stack: [Arg2, Arg1].

      final code = [
        // Push args to stack: Arg 1 (10), Arg 2 (20).
        // Spec: "First argument pushed last." -> So Arg 1 is top of stack?
        // Wait. "Arguments are pushed in standard function-call order (first argument pushed last)."
        // If func(a, b), we push b, then push a. Stack Top = a.
        // So _pop() gets a (Arg 1). _pop() gets b (Arg 2).

        // Push 20 (Arg 2).
        // Mode 8 (Stack) is Destination. Mode 1 (Const) is Source.
        // Byte: Src(1) | Dest(8)<<4 = 0x81.
        GlulxOpcodes.copy, 0x81, 20,
        // Push 10 (Arg 1).
        GlulxOpcodes.copy, 0x81, 10,

        // glk 0x123, 2 -> 0x80
        // Modes: Op1(3)|Op2(1)<<4 = 0x13. Op3(5) = 0x05.
        // Mode byte 2 (for op3): Mode 5 (RAM byte? No, RAM 00-FF is D). Mode 5 is Address 00-FF.
        // Wait. 0x80 is RAM address or just address?
        // Mode 5 (Address 00-FF). Since isStore=true, it stores to RAM if it's RAM mode or...
        // Wait. Mode 5 is "Address 00-FF". It reads from PC, gets byte. The value is the address.
        // If destination, it writes to that address in memory.
        // RAM starts at 0?
        // _storeResult writes to _memWrite32(address).
        // RAM usually mapped at start?
        // Our test createGame makes RAM.
        // So address 0x80 is valid.
        // So Mode 5 (0x80) is "Address 0x80".
        // Byte 2: Mode 5.

        // 0x13, 0x05.
        // Op1 (Const 4): 00 00 01 23.
        // Op2 (Const 1): 02.
        // Op3 (Addr 1): 80.

        // Let's re-verify modes.
        // L1 (op1) = 3 (const 4).
        // S1 (op2) = 1 (const 1).
        // Byte 1: 3 | (1 << 4) = 0x13.
        // L2 (op3) = 5 (addr 1).
        // S3 (op4) = 0.
        // Byte 2: 5 | 0 = 0x05.
        // glk 0x123, 2 -> 0x80
        // Modes: Op1(3)|Op2(1)<<4 = 0x13. Op3(5) = 0x05.
        // Opcode 0x130 is 2 bytes: 0x81, 0x30.
        0x81, 0x30, 0x13, 0x05, 0x00, 0x00, 0x01, 0x23, 0x02, 0x80,

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      final mockIo = MockIoProvider();
      interpreter = GlulxInterpreter(io: mockIo);
      interpreter.load(createGame(code));
      await interpreter.run();

      expect(mockIo.glkCalls.containsKey(0x123), isTrue);
      expect(mockIo.glkCalls[0x123], equals([10, 20]));
      expect(interpreter.memRead32(0x80), equals(42));
    });

    test('streamchar uses io provider', () async {
      final code = [
        GlulxOpcodes.streamchar, 0x01, 0x41, // 'A'
        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      final mockIo = MockIoProvider();
      interpreter = GlulxInterpreter(io: mockIo);
      interpreter.load(createGame(code));
      await interpreter.run();

      expect(mockIo.glkCalls.containsKey(0x81), isTrue); // glk_put_char_stream
      expect(mockIo.glkCalls[0x81], equals([0, 0x41]));
    });

    test('shift opcodes', () async {
      final code = [
        // shiftl 1 1 -> RAM[0x80] (2)
        GlulxOpcodes.shiftl, 0x11, 0x05, 1, 1, 0x80,
        // sshiftr -2 1 -> RAM[0x84] (-1)
        // -2 is 0xFFFFFFFE. >> 1 should be 0xFFFFFFFF (-1).
        GlulxOpcodes.sshiftr, 0x11, 0x05, 0xFE, 1, 0x84,
        // Note: 0xFE as byte constant is -2 signed? Mode 1 is byte.
        // Interpreter logic: if (value > 127) value -= 256;
        // So 0xFE (254) becomes -2. Correct.

        // ushiftr -2 1 -> RAM[0x88]
        // -2 (0xFFFFFFFE) >>> 1 = 0x7FFFFFFF (2147483647).
        GlulxOpcodes.ushiftr, 0x11, 0x05, 0xFE, 1, 0x88,

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

      expect(interpreter.memRead32(0x80), equals(2));
      // -1 unsigned is 0xFFFFFFFF
      expect(interpreter.memRead32(0x84), equals(0xFFFFFFFF));
      expect(interpreter.memRead32(0x88), equals(0x7FFFFFFF));
    });

    test('sex opcodes', () async {
      final code = [
        // sexb 0xFF -> RAM[0x80] (-1)
        // sexb L1(Const Byte - Mode 1) S1(Addr 0-FF - Mode 5)
        // Byte 1: 1 | (5 << 4) = 0x51.
        GlulxOpcodes.sexb, 0x51, 0xFF, 0x80,
        // sexs 0xFFFF -> RAM[0x84] (-1)
        // Need to pass 0xFFFF. Mode 2 (short const) 0xFFFF.
        // Byte 1: Mode2=2. Mode2=5. -> 0x52.
        // Short: FF FF.
        GlulxOpcodes.sexs, 0x52, 0xFF, 0xFF, 0x84,

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
        GlulxOpcodes.astore, 0x12, 0x03, 0x00, 0xC0, 0x00,
        0x10, 0x10, 0x10, 0x10, // Value 0x10101010
        // astore 0xC0 1 0x20202020
        // Addr = 0xC0 + 4*1 = 0xC4.
        GlulxOpcodes.astore, 0x12, 0x03, 0x00, 0xC0, 0x01,
        0x20, 0x20, 0x20, 0x20,

        // Now read back with aload
        // aload 0xC0 0 -> RAM[0xD0]
        GlulxOpcodes.aload, 0x12, 0x05, 0x00, 0xC0, 0x00, 0xD0,

        // aload 0xC0 1 -> RAM[0xD4]
        GlulxOpcodes.aload, 0x12, 0x05, 0x00, 0xC0, 0x01, 0xD4,

        // Test astores / aloads
        // astores 0xE0 0 0x3344
        // Mode 2 for E0.
        GlulxOpcodes.astores, 0x12, 0x02, 0x00, 0xE0, 0x00, 0x33, 0x44,

        // aloads 0xE0 0 -> RAM[0xD8]
        GlulxOpcodes.aloads, 0x12, 0x05, 0x00, 0xE0, 0x00, 0xD8,

        // Test astoreb / aloadb
        // astoreb 0xF0 0 0x55
        GlulxOpcodes.astoreb, 0x12, 0x01, 0x00, 0xF0, 0x00, 0x55,

        // aloadb 0xF0 0 -> RAM[0xDC]
        GlulxOpcodes.aloadb, 0x12, 0x05, 0x00, 0xF0, 0x00, 0xDC,

        GlulxOpcodes.quit >> 8 & 0x7F | 0x80, GlulxOpcodes.quit & 0xFF,
      ];

      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run();

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
  });
}

class MockIoProvider extends IoProvider {
  final List<String> log = [];
  final Map<int, List<int>> glkCalls = {};

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    return null;
  }

  @override
  int getFlags1() => 0;

  @override
  Future<int> glulxGlk(int selector, List<int> args) {
    log.add('glk: $selector, args: $args');
    glkCalls[selector] = args;
    if (selector == 0x123) {
      // Mock function 0x123
      return Future.value(42); // Return 42
    }
    return Future.value(0);
  }
}
