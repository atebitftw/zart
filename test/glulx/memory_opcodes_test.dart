import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  group('Memory Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    Uint8List createGameData(List<int> opcodeBytes) {
      final data = Uint8List(1024);
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C; // magic
      data[10] = 0x01; // RAMSTART 0x100
      data[14] = 0x04; // EXTSTART 0x400
      data[18] = 0x04; // ENDMEM 0x400
      data[22] = 0x04; // Stack size 0x400
      for (var i = 0; i < opcodeBytes.length; i++) {
        data[0x100 + i] = opcodeBytes[i];
      }
      return data;
    }

    setUp(() async {
      interpreter = GlulxInterpreter(TestGlkIoProvider());
    });

    test('getmemsize returns current memory size', () async {
      // getmemsize (0x102) stack
      // Opcode: 0x81, 0x02. Modes: S1=8 -> 0x08
      gameData = createGameData([0x81, 0x02, 0x08]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x400));
    });

    test('setmemsize resizes memory', () async {
      // setmemsize (0x103) 0x600, stack
      // Opcode: 0x81, 0x03. Modes: L1=3 (4-byte), S1=8 -> 0x83
      gameData = createGameData([0x81, 0x03, 0x83, 0x00, 0x00, 0x06, 0x00]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0)); // 0 means success
      expect(interpreter.memoryMap.endMem, equals(0x600));
    });

    test('mzero zeroes out memory range', () async {
      // mzero (0x170) 5, 0x300
      // Opcode: 0x81, 0x70. Modes: L1=1, L2=3 (4-byte addr) -> 0x31
      gameData = createGameData([
        0x81,
        0x70,
        0x31,
        0x05,
        0x00,
        0x00,
        0x03,
        0x00,
      ]);
      // Fill some garbage at 0x300
      for (var i = 0x300; i < 0x310; i++) {
        gameData[i] = 0xFF;
      }

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);

      await interpreter.executeInstruction();
      for (var i = 0x300; i < 0x305; i++) {
        expect(interpreter.memoryMap.readByte(i), equals(0));
      }
      expect(interpreter.memoryMap.readByte(0x305), equals(0xFF));
    });

    test('mcopy copies memory range', () async {
      // mcopy (0x171) 4, 0x300, 0x310
      // Opcode: 0x81, 0x71. Modes byte 1: L1=1, L2=3 -> 0x31. Modes byte 2: L3=3 -> 0x03
      gameData = createGameData([
        0x81,
        0x71,
        0x31,
        0x03,
        0x04,
        0x00,
        0x00,
        0x03,
        0x00,
        0x00,
        0x00,
        0x03,
        0x10,
      ]);
      gameData[0x300] = 0xAA;
      gameData[0x301] = 0xBB;
      gameData[0x302] = 0xCC;
      gameData[0x303] = 0xDD;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);

      await interpreter.executeInstruction();
      expect(interpreter.memoryMap.readByte(0x310), equals(0xAA));
      expect(interpreter.memoryMap.readByte(0x311), equals(0xBB));
      expect(interpreter.memoryMap.readByte(0x312), equals(0xCC));
      expect(interpreter.memoryMap.readByte(0x313), equals(0xDD));
    });
  });
}

// Local MockGlkIoProvider removed
