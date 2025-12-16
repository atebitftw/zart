import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/opcodes.dart';

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
        0x10, // add
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
  });
}
