import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  group('Array Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    Uint8List createGameData(List<int> opcodeBytes) {
      final data = Uint8List(1024);
      // Magic Number: 47 6C 75 6C
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;

      // RAMSTART at 0x100
      data[8] = 0x00;
      data[9] = 0x00;
      data[10] = 0x01;
      data[11] = 0x00;

      // EXTSTART and ENDMEM at 0x400
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x04;
      data[15] = 0x00;

      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x04;
      data[19] = 0x00;

      // Stack size: 0x400
      data[20] = 0x00;
      data[21] = 0x00;
      data[22] = 0x04;
      data[23] = 0x00;

      // Place opcode bytes at RAMSTART (0x100)
      for (var i = 0; i < opcodeBytes.length; i++) {
        data[0x100 + i] = opcodeBytes[i];
      }

      return data;
    }

    setUp(() async {
      interpreter = GlulxInterpreter(MockGlkProvider());
    });

    test('aload reads a 32-bit word from an array', () async {
      // Data at 0x200: [0x11223344]
      // Opcode: aload 0x200, 0, stack
      // Modes: L1=3 (4-byte), L2=1 (1-byte), S1=8 (push) -> 0x13, 0x08
      gameData = createGameData([
        GlulxOp.aload,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x00,
      ]);
      gameData[0x200] = 0x11;
      gameData[0x201] = 0x22;
      gameData[0x202] = 0x33;
      gameData[0x203] = 0x44;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x11223344));
    });

    test('aload reads with non-zero index', () async {
      // Data at 0x204: [0x55667788]
      // Opcode: aload 0x200, 1, stack (index 1 = offset 4)
      // Modes: L1=3, L2=1, S1=8 -> 0x13, 0x08
      gameData = createGameData([
        GlulxOp.aload,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x01,
      ]);
      gameData[0x204] = 0x55;
      gameData[0x205] = 0x66;
      gameData[0x206] = 0x77;
      gameData[0x207] = 0x88;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x55667788));
    });

    test('astore writes a 32-bit word to an array', () async {
      // Opcode: astore 0x200, 1, 0xAABBCCDD (index 1 = offset 4)
      // Modes: L1=3, L2=1, L3=3 -> 0x13, 0x03
      gameData = createGameData([
        GlulxOp.astore,
        0x13,
        0x03,
        0x00,
        0x00,
        0x02,
        0x00,
        0x01,
        0xAA,
        0xBB,
        0xCC,
        0xDD,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readWord(0x204), equals(0xAABBCCDD));
    });

    test('aloads reads a 16-bit short from an array', () async {
      // Data at 0x202: [0x1122]
      // Opcode: aloads 0x200, 1, stack (index 1 = offset 2)
      // Modes: L1=3, L2=1, S1=8 -> 0x13, 0x08
      gameData = createGameData([
        GlulxOp.aloads,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x01,
      ]);
      gameData[0x202] = 0x11;
      gameData[0x203] = 0x22;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      // Result is sign-extended to 32-bit
      expect(interpreter.stack.pop32(), equals(0x00001122));
    });

    test('aloads does not sign-extend negative short', () async {
      // Data at 0x202: [0x8899]
      gameData = createGameData([
        GlulxOp.aloads,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x01,
      ]);
      gameData[0x202] = 0x88;
      gameData[0x203] = 0x99;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      // Spec Section 2.4.6: "The 'load' opcodes expand 8-bit or 16-bit values *without* sign extension."
      expect(interpreter.stack.pop32(), equals(0x8899));
    });

    test('astores writes a 16-bit short to an array', () async {
      // Opcode: astores 0x200, 2, 0x1234 (index 2 = offset 4)
      // Modes: L1=3, L2=1, L3=2 (2-byte const) -> 0x13, 0x02
      gameData = createGameData([
        GlulxOp.astores,
        0x13,
        0x02,
        0x00,
        0x00,
        0x02,
        0x00,
        0x02,
        0x12,
        0x34,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readShort(0x204), equals(0x1234));
    });

    test('aloadb reads a byte from an array', () async {
      // Data at 0x203: [0x44]
      // Opcode: aloadb 0x200, 3, stack
      // Modes: L1=3, L2=1, S1=8 -> 0x13, 0x08
      gameData = createGameData([
        GlulxOp.aloadb,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x03,
      ]);
      gameData[0x203] = 0x44;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x44));
    });

    test('aloadb does not sign-extend negative byte', () async {
      // Data at 0x203: [0x88]
      gameData = createGameData([
        GlulxOp.aloadb,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x03,
      ]);
      gameData[0x203] = 0x88;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x88));
    });

    test('astoreb writes a byte to an array', () async {
      // Opcode: astoreb 0x200, 5, 0x55
      // Modes: L1=3, L2=1, L3=1 -> 0x13, 0x01
      gameData = createGameData([
        GlulxOp.astoreb,
        0x13,
        0x01,
        0x00,
        0x00,
        0x02,
        0x00,
        0x05,
        0x55,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readByte(0x205), equals(0x55));
    });

    test('aloadbit reads a bit from memory', () async {
      // Data at 0x200: 0x80 (1000 0000)
      // Bit 7 is 1
      // Modes: L1=3, L2=1, S1=8 -> 0x13, 0x08
      gameData = createGameData([
        GlulxOp.aloadbit,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x07, // Bit 7 of 0x200
        GlulxOp.aloadbit,
        0x13,
        0x08,
        0x00,
        0x00,
        0x02,
        0x00,
        0x06, // Bit 6 of 0x200
      ]);
      gameData[0x200] = 0x80;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(1));

      // Bit 6 should be 0
      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0));
    });

    test('astorebit writes a bit to memory', () async {
      // Set bit 9 of 0x200 (byte 0x201, bit 1)
      // Modes: L1=3, L2=1, L3=1 -> 0x13, 0x01
      gameData = createGameData([
        GlulxOp.astorebit,
        0x13,
        0x01,
        0x00,
        0x00,
        0x02,
        0x00,
        0x09,
        0x01,
        GlulxOp.astorebit,
        0x13,
        0x01,
        0x00,
        0x00,
        0x02,
        0x00,
        0x09,
        0x00,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readByte(0x201), equals(0x02));

      // Clear it
      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readByte(0x201), equals(0x00));
    });
  });
}

// Local MockGlkIoProvider removed
