import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import '../../bin/cli/cli_platform_provider.dart';

void main() {
  /// Glulx Spec Section 2.4.2: Bitwise Opcodes
  group('Bitwise Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    /// Creates a minimal Glulx game data with the given opcode bytes at RAMSTART.
    Uint8List createGameData(List<int> opcodeBytes) {
      final data = Uint8List(512);
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

      // EXTSTART and ENDMEM
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x02;
      data[15] = 0x00;

      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x02;
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
      interpreter = GlulxInterpreter(CliPlatformProvider(gameName: 'test'));
    });

    // ========== bitand tests ==========

    test('bitand computes L1 & L2', () async {
      /// Spec Section 2.4.2: "bitand L1 L2 S1: Compute the bitwise AND of L1 and L2."
      // 0xFF00 & 0x0FF0 = 0x0F00
      gameData = createGameData([
        GlulxOp.bitand,
        0x33, 0x08, // L1=mode 3, L2=mode 3, S1=mode 8
        0x00, 0x00, 0xFF, 0x00, // L1 = 0xFF00
        0x00, 0x00, 0x0F, 0xF0, // L2 = 0x0FF0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0x0F00));
    });

    // ========== bitor tests ==========

    test('bitor computes L1 | L2', () async {
      /// Spec Section 2.4.2: "bitor L1 L2 S1: Compute the bitwise OR of L1 and L2."
      // 0xFF00 | 0x00FF = 0xFFFF
      gameData = createGameData([
        GlulxOp.bitor,
        0x33, 0x08,
        0x00, 0x00, 0xFF, 0x00, // L1 = 0xFF00
        0x00, 0x00, 0x00, 0xFF, // L2 = 0x00FF
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0xFFFF));
    });

    // ========== bitxor tests ==========

    test('bitxor computes L1 ^ L2', () async {
      /// Spec Section 2.4.2: "bitxor L1 L2 S1: Compute the bitwise XOR of L1 and L2."
      // 0xFF00 ^ 0xFFFF = 0x00FF
      gameData = createGameData([
        GlulxOp.bitxor,
        0x33, 0x08,
        0x00, 0x00, 0xFF, 0x00, // L1 = 0xFF00
        0x00, 0x00, 0xFF, 0xFF, // L2 = 0xFFFF
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0x00FF));
    });

    // ========== bitnot tests ==========

    test('bitnot computes ~L1', () async {
      /// Spec Section 2.4.2: "bitnot L1 S1: Compute the bitwise negation of L1."
      // ~0x00000000 = 0xFFFFFFFF
      gameData = createGameData([
        GlulxOp.bitnot,
        0x83, // S1=mode 8 (high nibble), L1=mode 3 (low nibble)
        0x00, 0x00, 0x00, 0x00, // L1 = 0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0xFFFFFFFF));
    });

    test('bitnot inverts all bits', () async {
      // ~0xAAAAAAAA = 0x55555555
      gameData = createGameData([
        GlulxOp.bitnot,
        0x83, // S1=mode 8 (high nibble), L1=mode 3 (low nibble)
        0xAA, 0xAA, 0xAA, 0xAA, // L1 = 0xAAAAAAAA
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0x55555555));
    });

    // ========== shiftl tests ==========

    test('shiftl shifts L1 left by L2 places', () async {
      /// Spec Section 2.4.2: "shiftl L1 L2 S1: Shift the bits of L1 to the left by L2 places."
      // 1 << 4 = 16
      gameData = createGameData([
        GlulxOp.shiftl,
        0x11, 0x08, // L1=mode 1, L2=mode 1, S1=mode 8
        0x01, // L1 = 1
        0x04, // L2 = 4
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(16));
    });

    test('shiftl returns 0 if L2 >= 32', () async {
      /// Spec Section 2.4.2: "If L2 is 32 or more, the result is always zero."
      gameData = createGameData([
        GlulxOp.shiftl,
        0x11, 0x08,
        0xFF, // L1 = -1 (0xFF as signed byte, but we use any value)
        0x20, // L2 = 32
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0));
    });

    // ========== ushiftr tests ==========

    test('ushiftr shifts L1 right by L2 places (unsigned)', () async {
      /// Spec Section 2.4.2: "ushiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
      /// The top L2 bits are filled in with zeroes."
      // 0x80000000 >> 4 = 0x08000000 (unsigned)
      gameData = createGameData([
        GlulxOp.ushiftr,
        0x13, 0x08, // L1=mode 3, L2=mode 1, S1=mode 8
        0x80, 0x00, 0x00, 0x00, // L1 = 0x80000000
        0x04, // L2 = 4
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0x08000000));
    });

    test('ushiftr returns 0 if L2 >= 32', () async {
      /// Spec Section 2.4.2: "If L2 is 32 or more, the result is always zero."
      gameData = createGameData([
        GlulxOp.ushiftr,
        0x13, 0x08,
        0xFF, 0xFF, 0xFF, 0xFF, // L1 = 0xFFFFFFFF
        0x20, // L2 = 32
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0));
    });

    // ========== sshiftr tests ==========

    test('sshiftr shifts L1 right with sign extension (positive)', () async {
      /// Spec Section 2.4.2: "sshiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
      /// The top L2 bits are filled with copies of the top bit of L1."
      // 0x7FFFFFFF >> 4 = 0x07FFFFFF (positive, top bit 0 -> fill with 0)
      gameData = createGameData([
        GlulxOp.sshiftr,
        0x13, 0x08, // L1=mode 3, L2=mode 1, S1=mode 8
        0x7F, 0xFF, 0xFF, 0xFF, // L1 = 0x7FFFFFFF (positive)
        0x04, // L2 = 4
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0x07FFFFFF));
    });

    test('sshiftr shifts L1 right with sign extension (negative)', () async {
      /// 0x80000000 >> 4 = 0xF8000000 (negative, top bit 1 -> fill with 1)
      gameData = createGameData([
        GlulxOp.sshiftr,
        0x13, 0x08,
        0x80, 0x00, 0x00, 0x00, // L1 = 0x80000000 (negative)
        0x04, // L2 = 4
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0xF8000000));
    });

    test('sshiftr returns 0 if L2 >= 32 and L1 positive', () async {
      /// Spec Section 2.4.2: "If L2 is 32 or more, the result is always zero or FFFFFFFF,
      /// depending on the top bit of L1."
      gameData = createGameData([
        GlulxOp.sshiftr,
        0x13, 0x08,
        0x7F, 0xFF, 0xFF, 0xFF, // L1 = 0x7FFFFFFF (positive)
        0x20, // L2 = 32
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0));
    });

    test('sshiftr returns 0xFFFFFFFF if L2 >= 32 and L1 negative', () async {
      /// Spec Section 2.4.2: result is FFFFFFFF when top bit is 1
      gameData = createGameData([
        GlulxOp.sshiftr,
        0x13, 0x08,
        0x80, 0x00, 0x00, 0x00, // L1 = 0x80000000 (negative)
        0x20, // L2 = 32
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0xFFFFFFFF));
    });

    test('shift with L2 = 0 returns L1 unchanged', () async {
      /// Spec Note: "If L2 is zero, the result is always equal to L1."
      gameData = createGameData([
        GlulxOp.shiftl,
        0x13, 0x08, // L1=mode 3, L2=mode 1, S1=mode 8
        0xDE, 0xAD, 0xBE, 0xEF, // L1 = 0xDEADBEEF
        0x00, // L2 = 0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0xDEADBEEF));
    });
  });
}

// Local MockGlkIoProvider removed
