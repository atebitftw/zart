import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

void main() {
  group('Search Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    Uint8List createGameData(List<int> opcodeBytes) {
      final data = Uint8List(2048);
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C; // magic
      data[10] = 0x01; // RAMSTART 0x100
      data[14] = 0x08; // EXTSTART 0x800
      data[18] = 0x08; // ENDMEM 0x800
      data[22] = 0x04; // Stack size 0x400
      for (var i = 0; i < opcodeBytes.length; i++) {
        data[0x100 + i] = opcodeBytes[i];
      }
      return data;
    }

    setUp(() async {
      interpreter = GlulxInterpreter(MockGlkIoProvider());
    });

    test('linearsearch finds a 4-byte key', () async {
      // linearsearch key=42, keySize=4, start=0x400, structSize=8, numStructs=4, keyOffset=0, options=0, dest=stack
      // Opcode: 0x81, 0x50.
      // Modes: L1=1, L2=1, L3=2, L4=1, L5=1, L6=1, L7=1, S1=8
      // Byte 1: 0x11 (L1, L2)
      // Byte 2: 0x12 (L3:2-byte constant, L4)
      // Byte 3: 0x11 (L5, L6)
      // Byte 4: 0x81 (L7, S1)
      gameData = createGameData([
        0x81, 0x50, // Opcode
        0x11, 0x12, 0x11, 0x81, // Modes
        0x2A, // key=42
        0x04, // keySize=4
        0x04, 0x00, // start=0x400
        0x08, // structSize=8
        0x04, // numStructs=4
        0x00, // keyOffset=0
        0x00, // options=0
      ]);

      // Set up memory at 0x400
      // 4 structs of 8 bytes. Key is at offset 0.
      // Struct 0: [10, 0, 0, 0, ...]
      // Struct 1: [20, 0, 0, 0, ...]
      // Struct 2: [42, 0, 0, 0, ...]
      // Struct 3: [50, 0, 0, 0, ...]
      gameData[0x403] = 10;
      gameData[0x40B] = 20;
      gameData[0x413] = 42;
      gameData[0x41B] = 50;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x410));
    });

    test('linearsearch fails to find key', () async {
      // same as above, but key=99
      gameData = createGameData([
        0x81, 0x50, // Opcode
        0x11, 0x12, 0x11, 0x81, // Modes
        0x63, // key=99
        0x04, // keySize=4
        0x04, 0x00, // start=0x400
        0x08, // structSize=8
        0x04, // numStructs=4
        0x00, // keyOffset=0
        0x00, // options=0
      ]);

      gameData[0x403] = 10;
      gameData[0x413] = 42;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0));
    });

    test('binarysearch finds a 2-byte key', () async {
      // binarysearch key=30, keySize=2, start=0x400, structSize=4, numStructs=4, keyOffset=0, options=0, dest=stack
      // Opcode: 0x81, 0x51.
      gameData = createGameData([
        0x81, 0x51, // Opcode
        0x11, 0x12, 0x11, 0x81, // Modes
        0x1E, // key=30
        0x02, // keySize=2
        0x04, 0x00, // start=0x400
        0x04, // structSize=4
        0x04, // numStructs=4
        0x00, // keyOffset=0
        0x00, // options=0
      ]);

      // Sorted structs: 10, 20, 30, 40
      gameData[0x400] = 0;
      gameData[0x401] = 10;
      gameData[0x404] = 0;
      gameData[0x405] = 20;
      gameData[0x408] = 0;
      gameData[0x409] = 30;
      gameData[0x40C] = 0;
      gameData[0x40D] = 40;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x408));
    });

    test('linkedsearch finds a 4-byte key', () async {
      // linkedsearch key=100, keySize=4, start=0x400, keyOffset=4, nextOffset=0, options=0, dest=stack
      // Opcode: 0x81, 0x52. 7 operands.
      // Modes: L1=1, L2=1, L3=2, L4=1, L5=1, L6=1, S1=8
      // Byte 1: 0x11
      // Byte 2: 0x12
      // Byte 3: 0x11
      // Byte 4: 0x08 (Op 7=8? No, Op 7 is 1, so 0x?8. Wait, 7 operands, so 0x81)
      // Actually 7 operands means Op 7 is the last one. 0x81 (L7=1, S1=8) is for 8 operands.
      // For 7 operands:
      // Byte 1: Op 1, Op 2 (0x11)
      // Byte 2: Op 3, Op 4 (0x12 for 2-byte addr)
      // Byte 3: Op 5, Op 6 (0x11)
      // Byte 4: Op 7 (0x08)
      gameData = createGameData([
        0x81, 0x52, // Opcode
        0x11, 0x12, 0x11, 0x08, // Modes
        0x64, // key=100
        0x04, // keySize=4
        0x04, 0x00, // start=0x400
        0x04, // keyOffset=4
        0x00, // nextOffset=0
        0x00, // options=0
      ]);

      // Linked list at 0x400
      // Node 1 at 0x400: next=0x410, key=50
      // Node 2 at 0x410: next=0x420, key=100
      // Node 3 at 0x420: next=0, key=150
      gameData[0x400] = 0;
      gameData[0x401] = 0;
      gameData[0x402] = 0x04;
      gameData[0x403] = 0x10;
      gameData[0x404] = 0;
      gameData[0x405] = 0;
      gameData[0x406] = 0;
      gameData[0x407] = 50;

      gameData[0x410] = 0;
      gameData[0x411] = 0;
      gameData[0x412] = 0x04;
      gameData[0x413] = 0x20;
      gameData[0x414] = 0;
      gameData[0x415] = 0;
      gameData[0x416] = 0;
      gameData[0x417] = 100;

      gameData[0x420] = 0;
      gameData[0x421] = 0;
      gameData[0x422] = 0;
      gameData[0x423] = 0;
      gameData[0x424] = 0;
      gameData[0x425] = 0;
      gameData[0x426] = 0;
      gameData[0x427] = 150;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x410));
    });
    group('Search Options', () {
      test('linearsearch with ReturnIndex', () async {
        // options=4 (ReturnIndex)
        gameData = createGameData([
          0x81, 0x50, // Opcode
          0x11, 0x12, 0x11, 0x81, // Modes
          0x2A, // key=42
          0x04, // keySize=4
          0x04, 0x00, // start=0x400
          0x08, // structSize=8
          0x04, // numStructs=4
          0x00, // keyOffset=0
          0x04, // options=4
        ]);

        gameData[0x403] = 10;
        gameData[0x40B] = 20;
        gameData[0x413] = 42; // Index 2

        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        expect(interpreter.stack.pop32(), equals(2));
      });
    });
  });
}

class MockGlkIoProvider implements GlkIoProvider {
  @override
  void setMemoryAccess({
    required void Function(int addr, int val, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
