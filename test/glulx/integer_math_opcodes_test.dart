import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  /// Glulx Spec Section 2.4.1: Integer Math Opcodes
  group('Integer Math Opcodes', () {
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
      interpreter = GlulxInterpreter(MockGlkProvider());
    });

    test('nop does nothing', () async {
      /// Spec Section 2.4: "nop: Do nothing."
      // Opcode: 0x00 (nop), no operands
      gameData = createGameData([GlulxOp.nop]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);

      await interpreter.executeInstruction();

      // PC should advance past the opcode
      expect(interpreter.pc, equals(0x101));
    });

    test('add computes L1 + L2', () async {
      /// Spec Section 2.4.1: "add L1 L2 S1: Add L1 and L2, using standard 32-bit addition.
      /// Truncate the result to 32 bits if necessary."
      // Opcode: 0x10 (add)
      // Modes byte 1: 0x11 -> L1=mode 1 (low nibble), L2=mode 1 (high nibble)
      // Modes byte 2: 0x08 -> S1=mode 8 (push to stack)
      // Operands: L1=5, L2=7 -> result 12 pushed to stack
      gameData = createGameData([GlulxOp.add, 0x11, 0x08, 0x05, 0x07]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);

      // Push a dummy call frame since stack operations need it
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(12));
    });

    test('add truncates to 32 bits', () async {
      /// Spec Section 2.4.1: "Truncate the result to 32 bits if necessary."
      // 0xFFFFFFFF + 1 = 0x100000000, truncated to 0x00000000
      gameData = createGameData([
        GlulxOp.add, // add
        0x33, // L1=mode 3 (4-byte const), L2=mode 3 (4-byte const)
        0x08, // S1=mode 8 (push to stack)
        0xFF, 0xFF, 0xFF, 0xFF, // L1 = 0xFFFFFFFF
        0x00, 0x00, 0x00, 0x01, // L2 = 1
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0));
    });

    test('sub computes L1 - L2', () async {
      /// Spec Section 2.4.1: "sub L1 L2 S1: Compute (L1 - L2), and store the result in S1."
      // 10 - 3 = 7
      gameData = createGameData([GlulxOp.sub, 0x11, 0x08, 0x0A, 0x03]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(7));
    });

    test('mul computes L1 * L2', () async {
      /// Spec Section 2.4.1: "mul L1 L2 S1: Compute (L1 * L2), and store the result in S1."
      // 6 * 7 = 42
      gameData = createGameData([GlulxOp.mul, 0x11, 0x08, 0x06, 0x07]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(42));
    });

    test('div computes signed L1 / L2', () async {
      /// Spec Section 2.4.1: "div L1 L2 S1: Compute (L1 / L2)... This is signed integer division."
      // 11 / 2 = 5
      gameData = createGameData([GlulxOp.div, 0x11, 0x08, 0x0B, 0x02]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(5));
    });

    test('div throws on division by zero', () async {
      /// Spec Section 2.4.1: "Division by zero is of course an error."
      // L1=10, L2=0 -> div by zero
      gameData = createGameData([GlulxOp.div, 0x01, 0x08, 0x0A, 0x00]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      expect(
        Future.sync(() => interpreter.executeInstruction()),
        throwsException,
      );
    });

    test('div throws on -0x80000000 / -1', () async {
      /// Spec Section 2.4.1: "So is dividing the value -0x80000000 by -1."
      gameData = createGameData([
        GlulxOp.div, // div
        0x33, // L1=mode 3 (4-byte const), L2=mode 3 (4-byte const)
        0x08, // S1=mode 8 (push)
        0x80, 0x00, 0x00, 0x00, // L1 = -0x80000000
        0xFF, 0xFF, 0xFF, 0xFF, // L2 = -1
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      expect(
        Future.sync(() => interpreter.executeInstruction()),
        throwsException,
      );
    });

    test('div handles negative numbers correctly', () async {
      /// Spec Section 2.4.1: "-11 / 2 = -5"
      gameData = createGameData([
        GlulxOp.div, // div
        0x11, 0x08, // L1=mode 1, L2=mode 1, S1=mode 8
        0xF5, // L1 = -11 (signed 1-byte)
        0x02, // L2 = 2
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // Result is -5 as unsigned 32-bit
      expect(interpreter.stack.pop32().toSigned(32), equals(-5));
    });

    test('mod computes signed L1 % L2', () async {
      /// Spec Section 2.4.1: "mod L1 L2 S1: Compute (L1 % L2)..."
      // 13 % 5 = 3
      gameData = createGameData([GlulxOp.mod, 0x11, 0x08, 0x0D, 0x05]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(3));
    });

    test('mod throws on modulo by zero', () async {
      /// Spec Section 2.4.1: "...taking the remainder modulo zero is an error..."
      // L1=10, L2=0 -> mod by zero
      gameData = createGameData([GlulxOp.mod, 0x01, 0x08, 0x0A, 0x00]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      expect(
        Future.sync(() => interpreter.executeInstruction()),
        throwsException,
      );
    });

    test('neg computes -L1', () async {
      /// Spec Section 2.4.1: "neg L1 S1: Compute the negative of L1."
      // neg 5 -> -5 (0xFFFFFFFB as unsigned)
      gameData = createGameData([GlulxOp.neg, 0x81, 0x05]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // -5 as unsigned 32-bit
      expect(interpreter.stack.pop32(), equals((-5) & 0xFFFFFFFF));
    });

    // Signed Division Edge Cases (per C reference exec.c behavior)
    // These test cases verify Dart's signed integer division matches the spec.

    test('div: -7 / 3 = -2 (truncates toward zero)', () async {
      /// Spec Section 2.4.1: Signed integer division truncates toward zero.
      /// C reference: -7 / 3 = -2 (not -3)
      gameData = createGameData([
        GlulxOp.div, // div
        0x11, 0x08, // L1=mode 1, L2=mode 1, S1=mode 8
        0xF9, // L1 = -7 (signed 1-byte)
        0x03, // L2 = 3
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(-2));
    });

    test('div: 7 / -3 = -2 (truncates toward zero)', () async {
      /// Spec Section 2.4.1: Signed integer division truncates toward zero.
      /// C reference: 7 / -3 = -2 (not -3)
      gameData = createGameData([
        GlulxOp.div, // div
        0x11, 0x08,
        0x07, // L1 = 7
        0xFD, // L2 = -3 (signed 1-byte)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(-2));
    });

    test('div: -7 / -3 = 2 (both negative)', () async {
      /// C reference: -7 / -3 = 2
      gameData = createGameData([
        GlulxOp.div, // div
        0x11, 0x08,
        0xF9, // L1 = -7
        0xFD, // L2 = -3
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(2));
    });

    test('mod: -7 % 3 = -1 (remainder has sign of dividend)', () async {
      /// Spec Section 2.4.1: Remainder from signed integer division.
      /// C reference: -7 % 3 = -1 (sign matches dividend)
      gameData = createGameData([
        GlulxOp.mod, // mod
        0x11, 0x08,
        0xF9, // L1 = -7
        0x03, // L2 = 3
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(-1));
    });

    test('mod: 7 % -3 = 1 (sign matches dividend, not divisor)', () async {
      /// C reference: 7 % -3 = 1 (sign matches dividend)
      gameData = createGameData([
        GlulxOp.mod, // mod
        0x11, 0x08,
        0x07, // L1 = 7
        0xFD, // L2 = -3
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(1));
    });

    test('mod: -7 % -3 = -1 (both negative)', () async {
      /// C reference: -7 % -3 = -1
      gameData = createGameData([
        GlulxOp.mod, // mod
        0x11, 0x08,
        0xF9, // L1 = -7
        0xFD, // L2 = -3
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32().toSigned(32), equals(-1));
    });
  });
}

// Local MockGlkIoProvider removed
