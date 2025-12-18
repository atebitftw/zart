import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

void main() {
  /// Glulx Spec Section 2.4.3: Branch Opcodes
  group('Branch Opcodes', () {
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
      interpreter = GlulxInterpreter(MockGlkIoProvider());
    });

    // ========== jump tests ==========

    test('jump branches unconditionally (forward)', () async {
      /// Spec Section 2.4.3: "jump L1: Branch unconditionally to offset L1."
      /// Spec: "destination = PC + Offset - 2"
      // jump 10 -> PC after instruction = 0x103, destination = 0x103 + 10 - 2 = 0x10B
      gameData = createGameData([
        GlulxOp.jump, // 0x100
        0x01, // mode 1 (1-byte signed constant)
        0x0A, // offset = 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // PC after opcode read: 0x103, then + 10 - 2 = 0x10B
      expect(interpreter.pc, equals(0x10B));
    });

    test('jump branches backward (negative offset)', () async {
      // jump -5 -> PC after instruction = 0x103, destination = 0x103 + (-5) - 2 = 0xFC
      gameData = createGameData([
        GlulxOp.jump,
        0x01,
        0xFB, // -5 as signed byte
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // PC after opcode read: 0x103, then + (-5) - 2 = 0xFC
      expect(interpreter.pc, equals(0xFC));
    });

    // ========== jz tests ==========

    test('jz branches if L1 == 0', () async {
      /// Spec Section 2.4.3: "jz L1 L2: If L1 is equal to zero, branch to L2."
      gameData = createGameData([
        GlulxOp.jz,
        0x10, // L1=mode 0 (zero), L2=mode 1 (1-byte const)
        0x0A, // L2 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1=0, so branch taken: PC = 0x103 + 10 - 2 = 0x10B
      expect(interpreter.pc, equals(0x10B));
    });

    test('jz does not branch if L1 != 0', () async {
      gameData = createGameData([
        GlulxOp.jz,
        0x11, // L1=mode 1 (1-byte const), L2=mode 1
        0x05, // L1 = 5 (non-zero)
        0x0A, // L2 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 != 0, so no branch: PC stays at end of instruction (0x104)
      expect(interpreter.pc, equals(0x104));
    });

    // ========== jnz tests ==========

    test('jnz branches if L1 != 0', () async {
      /// Spec Section 2.4.3: "jnz L1 L2: If L1 is not equal to zero, branch to L2."
      gameData = createGameData([
        GlulxOp.jnz,
        0x11, // L1=mode 1, L2=mode 1
        0x05, // L1 = 5
        0x0A, // L2 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 != 0, branch taken: PC = 0x104 + 10 - 2 = 0x10C
      expect(interpreter.pc, equals(0x10C));
    });

    test('jnz does not branch if L1 == 0', () async {
      gameData = createGameData([
        GlulxOp.jnz,
        0x10, // L1=mode 0 (zero), L2=mode 1
        0x0A, // L2 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 == 0, no branch
      expect(interpreter.pc, equals(0x103));
    });

    // ========== jeq tests ==========

    test('jeq branches if L1 == L2', () async {
      /// Spec Section 2.4.3: "jeq L1 L2 L3: If L1 is equal to L2, branch to L3."
      gameData = createGameData([
        GlulxOp.jeq,
        0x11, 0x01, // L1=mode 1, L2=mode 1, L3=mode 1
        0x05, // L1 = 5
        0x05, // L2 = 5
        0x0A, // L3 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 == L2, branch taken: PC = 0x106 + 10 - 2 = 0x10E
      expect(interpreter.pc, equals(0x10E));
    });

    test('jeq does not branch if L1 != L2', () async {
      gameData = createGameData([
        GlulxOp.jeq,
        0x11, 0x01,
        0x05, // L1 = 5
        0x07, // L2 = 7
        0x0A, // L3 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 != L2, no branch
      expect(interpreter.pc, equals(0x106));
    });

    // ========== jne tests ==========

    test('jne branches if L1 != L2', () async {
      /// Spec Section 2.4.3: "jne L1 L2 L3: If L1 is not equal to L2, branch to L3."
      gameData = createGameData([
        GlulxOp.jne,
        0x11, 0x01,
        0x05, // L1 = 5
        0x07, // L2 = 7
        0x0A, // L3 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // L1 != L2, branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jlt tests (signed) ==========

    test('jlt branches if L1 < L2 (signed)', () async {
      /// Spec Section 2.4.3: "jlt L1 L2 L3: Branch if L1 < L2 (signed)"
      gameData = createGameData([
        GlulxOp.jlt,
        0x11, 0x01,
        0xFB, // L1 = -5 (signed byte)
        0x05, // L2 = 5
        0x0A, // L3 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // -5 < 5, branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    test('jlt does not branch if L1 >= L2 (signed)', () async {
      gameData = createGameData([
        GlulxOp.jlt,
        0x11, 0x01,
        0x05, // L1 = 5
        0xFB, // L2 = -5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 5 >= -5, no branch
      expect(interpreter.pc, equals(0x106));
    });

    // ========== jltu tests (unsigned) ==========

    test('jltu branches if L1 < L2 (unsigned)', () async {
      /// Spec Section 2.4.3: "jltu L1 L2 L3: Branch if L1 < L2 (unsigned)"
      // 5 < 0xFFFFFFFF (interpreted as unsigned)
      gameData = createGameData([
        GlulxOp.jltu,
        0x11, 0x01,
        0x05, // L1 = 5
        0xFF, // L2 = 255 (or -1 signed, but we treat as unsigned)
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 5 < 255 (unsigned), branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    test('jltu treats 0x80000000 as greater than 0x7FFFFFFF', () async {
      /// Spec: unsigned comparison treats high bit as magnitude, not sign
      gameData = createGameData([
        GlulxOp.jltu,
        0x33, 0x01, // L1=mode 3, L2=mode 3, L3=mode 1
        0x7F, 0xFF, 0xFF, 0xFF, // L1 = 0x7FFFFFFF
        0x80, 0x00, 0x00, 0x00, // L2 = 0x80000000
        0x0A, // L3 = offset 10
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 0x7FFFFFFF < 0x80000000 (unsigned), branch taken
      // PC after instruction: 0x100 + 1(op) + 2(modes) + 4(L1) + 4(L2) + 1(L3) = 0x10C
      // Destination: 0x10C + 10 - 2 = 0x114
      expect(interpreter.pc, equals(0x114));
    });

    // ========== jge tests (signed) ==========

    test('jge branches if L1 >= L2 (signed)', () async {
      gameData = createGameData([
        GlulxOp.jge,
        0x11, 0x01,
        0x05, // L1 = 5
        0x05, // L2 = 5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 5 >= 5, branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jgt tests (signed) ==========

    test('jgt branches if L1 > L2 (signed)', () async {
      gameData = createGameData([
        GlulxOp.jgt,
        0x11, 0x01,
        0x0A, // L1 = 10
        0x05, // L2 = 5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 10 > 5, branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jle tests (signed) ==========

    test('jle branches if L1 <= L2 (signed)', () async {
      gameData = createGameData([
        GlulxOp.jle,
        0x11, 0x01,
        0x03, // L1 = 3
        0x05, // L2 = 5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 3 <= 5, branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jgeu tests (unsigned) ==========

    test('jgeu branches if L1 >= L2 (unsigned)', () async {
      gameData = createGameData([
        GlulxOp.jgeu,
        0x11, 0x01,
        0xFF, // L1 = 255
        0x05, // L2 = 5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 255 >= 5 (unsigned), branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jgtu tests (unsigned) ==========

    test('jgtu branches if L1 > L2 (unsigned)', () async {
      gameData = createGameData([
        GlulxOp.jgtu,
        0x11, 0x01,
        0xFF, // L1 = 255
        0x05, // L2 = 5
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 255 > 5 (unsigned), branch taken
      expect(interpreter.pc, equals(0x10E));
    });

    // ========== jleu tests (unsigned) ==========

    test('jleu branches if L1 <= L2 (unsigned)', () async {
      gameData = createGameData([
        GlulxOp.jleu,
        0x11, 0x01,
        0x05, // L1 = 5
        0xFF, // L2 = 255
        0x0A,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // 5 <= 255 (unsigned), branch taken
      expect(interpreter.pc, equals(0x10E));
    });
  });
}

/// Mock GlkIoProvider for testing
class MockGlkIoProvider implements GlkIoProvider {
  @override
  void setMemoryAccess({
    required void Function(int addr, int val, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
