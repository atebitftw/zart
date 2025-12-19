import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  group('Stack Opcodes', () {
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

    test('stkcount stores number of values on stack', () async {
      // stkcount stack
      // Modes: S1=8 -> 0x08
      gameData = createGameData([GlulxOp.stkcount, 0x08]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.stack.push32(42);
      interpreter.stack.push32(43);

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(2));
    });

    test('stkpeek peeks at values on stack', () async {
      // stkpeek 1, stack (peek at index 1)
      // Modes: L1=1 (1-byte const), S1=8 (push) -> 0x81 in the first modes byte
      gameData = createGameData([GlulxOp.stkpeek, 0x81, 0x01]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.stack.push32(100); // index 1
      interpreter.stack.push32(200); // index 0

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(100));
      expect(interpreter.stack.pop32(), equals(200));
      expect(interpreter.stack.pop32(), equals(100));
    });

    test('stkswap swaps top two values', () async {
      // stkswap (no operands)
      gameData = createGameData([GlulxOp.stkswap]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.stack.push32(10);
      interpreter.stack.push32(20);

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(10));
      expect(interpreter.stack.pop32(), equals(20));
    });

    test('stkroll rotates stack values', () async {
      // stkroll 3, 1 (rotate top 3 up by 1)
      // Modes: L1=1, L2=1 -> 0x11
      gameData = createGameData([GlulxOp.stkroll, 0x11, 0x03, 0x01]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.stack.push32(3);
      interpreter.stack.push32(2);
      interpreter.stack.push32(1);

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(2));
      expect(interpreter.stack.pop32(), equals(3));
      expect(interpreter.stack.pop32(), equals(1));
    });

    test('stkcopy duplicates stack values', () async {
      // stkcopy 2 (duplicate top 2)
      // Modes: L1=1 -> 0x01
      gameData = createGameData([GlulxOp.stkcopy, 0x01, 0x02]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.stack.push32(10);
      interpreter.stack.push32(20);

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(20));
      expect(interpreter.stack.pop32(), equals(10));
      expect(interpreter.stack.pop32(), equals(20));
      expect(interpreter.stack.pop32(), equals(10));
    });
  });
}

// Local MockGlkIoProvider removed
