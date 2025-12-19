import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

void main() {
  group('Move Opcodes', () {
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
      interpreter = GlulxInterpreter(MockGlkIoProvider());
    });

    test('copy copies 32-bit values', () async {
      // Opcode: copy 0x12345678, stack
      // Mode: L1=3 (4-byte), S1=8 -> (8 << 4) | 3 = 0x83
      gameData = createGameData([GlulxOp.copy, 0x83, 0x12, 0x34, 0x56, 0x78]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x12345678));
    });

    test('copys copies 16-bit values', () async {
      // Opcode: copys 0x1234, stack
      // Mode: L1=2 (2-byte), S1=8 -> (8 << 4) | 2 = 0x82
      gameData = createGameData([GlulxOp.copys, 0x82, 0x12, 0x34]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      // Spec Section 2.4.5: "the destination is always 32 bits, the source is 16 bits. Sign-extension is NOT performed."
      expect(interpreter.stack.pop32(), equals(0x1234));
    });

    test('copys does not sign-extend', () async {
      // Opcode: copys 0x8899, stack
      // Mode: 0x82
      gameData = createGameData([GlulxOp.copys, 0x82, 0x88, 0x99]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x8899));
    });

    test('copyb copies 8-bit values', () async {
      // Opcode: copyb 0x44, stack
      // Mode: L1=1 (1-byte), S1=8 -> (8 << 4) | 1 = 0x81
      gameData = createGameData([GlulxOp.copyb, 0x81, 0x44]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x44));
    });

    test('copyb does not sign-extend', () async {
      // Opcode: copyb 0x88, stack
      // Mode: 0x81
      gameData = createGameData([GlulxOp.copyb, 0x81, 0x88]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0x88));
    });

    test('sexs sign-extends 16-bit to 32-bit', () async {
      // Opcode: sexs 0x8899, stack
      // Mode: L1=2 (2-byte), S1=8 -> 0x82
      gameData = createGameData([GlulxOp.sexs, 0x82, 0x88, 0x99]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32().toSigned(32), equals(0xFFFF8899.toSigned(32)));
    });

    test('sexb sign-extends 8-bit to 32-bit', () async {
      // Opcode: sexb 0x88, stack
      // Mode: L1=1 (1-byte), S1=8 -> 0x81
      gameData = createGameData([GlulxOp.sexb, 0x81, 0x88]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32().toSigned(32), equals(0xFFFFFF88.toSigned(32)));
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
