import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import '../../bin/cli/cli_platform_provider.dart';
import 'mock_glk_io_provider.dart';

void main() {
  /// Glulx Spec Section 2.4.4: Function Call Opcodes
  group('Function Call Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    /// Helper to encode a 2-byte opcode (0x80-0x3FFF range)
    /// Spec: "Two bytes, OP+8000"
    List<int> op2(int op) => [(op + 0x8000) >> 8, (op + 0x8000) & 0xFF];

    /// Creates minimal Glulx game data with functions at known addresses
    Uint8List createGameData(List<int> mainOpcodes) {
      final data = Uint8List(1024);
      // Header
      data.setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]); // Magic
      data.setRange(8, 12, [0x00, 0x00, 0x01, 0x00]); // RAMSTART 0x100
      data.setRange(12, 16, [0x00, 0x00, 0x04, 0x00]); // EXTSTART 0x400
      data.setRange(16, 20, [0x00, 0x00, 0x04, 0x00]); // ENDMEM 0x400
      data.setRange(20, 24, [0x00, 0x00, 0x04, 0x00]); // Stack 0x400

      // Main opcodes at 0x100
      for (var i = 0; i < mainOpcodes.length; i++) {
        data[0x100 + i] = mainOpcodes[i];
      }

      // ===== Function at 0x200: C1, 1 local (4-byte), returns local[0] =====
      // Type C1, format: 04 01 00 00, entry at 0x205
      // 8 elements total
      data[0x200] = 0xC1; // type C1
      data[0x201] = 0x04;
      data[0x202] = 0x01; // 1 local of 4 bytes
      data[0x203] = 0x00;
      data[0x204] = 0x00; // terminator
      // Entry at 0x205:
      data[0x205] = GlulxOp.ret;
      data[0x206] = 0x09; // mode 9 (local 1-byte offset)
      data[0x207] = 0x00; // offset 0

      // ===== Function at 0x210: C1, returns constant 99 =====
      data[0x210] = 0xC1;
      data[0x211] = 0x00;
      data[0x212] = 0x00; // no locals
      // Entry at 0x213:
      data[0x213] = GlulxOp.ret;
      data[0x214] = 0x01; // mode 1 (1-byte const)
      data[0x215] = 0x63; // value 99

      // ===== Function at 0x220: C1, 2 locals, returns sum =====
      data[0x220] = 0xC1;
      data[0x221] = 0x04;
      data[0x222] = 0x02; // 2 locals of 4 bytes
      data[0x223] = 0x00;
      data[0x224] = 0x00; // terminator
      // Entry at 0x225: add local[0] + local[4] -> stack
      data[0x225] = GlulxOp.add;
      data[0x226] = 0x99; // L1=mode 9, L2=mode 9
      data[0x227] = 0x08; // S1=mode 8 (push)
      data[0x228] = 0x00; // L1 = offset 0
      data[0x229] = 0x04; // L2 = offset 4
      // ret stack
      data[0x22A] = GlulxOp.ret;
      data[0x22B] = 0x08; // mode 8 (pop)

      // ===== Function at 0x230: C0, adds count+firstArg to verify order =====
      // C0 means args are on stack: [lastArg, firstArg, count] bottom->top
      // add(pop, pop) will add count and firstArg
      // For args [10, 99]: correct stack is [99, 10, 2]
      //   add pops 2 and 10, pushes 12, ret returns 12
      // If wrong order [10, 99, 2]: add pops 2 and 99, pushes 101, ret returns 101
      data[0x230] = 0xC0; // type C0
      data[0x231] = 0x00;
      data[0x232] = 0x00; // no locals
      // Entry at 0x233: add pop pop -> push
      data[0x233] = GlulxOp.add;
      data[0x234] = 0x88; // L1=mode 8 (pop), L2=mode 8 (pop)
      data[0x235] = 0x08; // S1=mode 8 (push)
      // ret pop (return the sum)
      data[0x236] = GlulxOp.ret;
      data[0x237] = 0x08; // mode 8 (pop)

      return data;
    }

    setUp(() async {
      interpreter = GlulxInterpreter(CliPlatformProvider(gameName: 'test'));
    });

    // ========== callf tests ==========

    test('callf calls function with 0 args', () async {
      /// Spec: "callf L1 S1: Call function with 0 arguments."
      // callf 0x210, -> stack (returns 99)
      // Mode byte: L1=mode 2 (low), S1=mode 8 (high) = 0x82
      final opcodes = [
        ...op2(GlulxOp.callf), // 0x81, 0x60
        0x82, // L1=2 (2-byte const), S1=8 (push)
        0x02, 0x10, // L1 = 0x210
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      // Execute callf
      await interpreter.executeInstruction();
      // Execute ret
      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(99));
    });

    test('callfi calls function with 1 arg', () async {
      /// Spec: "callfi L1 L2 S1: Call function with 1 argument."
      // callfi 0x200, 42, -> stack
      // Modes: L1=2, L2=1, S1=8
      // Byte 0: L1(2) in low, L2(1) in high = 0x12
      // Byte 1: S1(8) in low = 0x08
      final opcodes = [
        ...op2(GlulxOp.callfi), // 0x81, 0x61
        0x12, 0x08, // modes
        0x02, 0x00, // L1 = 0x200
        0x2A, // L2 = 42
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      // Execute callfi
      await interpreter.executeInstruction();
      expect(interpreter.pc, equals(0x205)); // entry point

      // Execute ret in function
      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(42));
    });

    test('callfii calls function with 2 args', () async {
      /// Spec: "callfii L1 L2 L3 S1: Call function with 2 arguments."
      // callfii 0x220, 10, 32, -> stack (returns 42)
      // Modes: L1=2, L2=1, L3=1, S1=8
      // Byte 0: L1(2) low, L2(1) high = 0x12
      // Byte 1: L3(1) low, S1(8) high = 0x81
      final opcodes = [
        ...op2(GlulxOp.callfii), // 0x81, 0x62
        0x12, 0x81, // modes
        0x02, 0x20, // L1 = 0x220
        0x0A, // L2 = 10
        0x20, // L3 = 32
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction(); // callfii
      await interpreter.executeInstruction(); // add
      await interpreter.executeInstruction(); // ret

      expect(interpreter.stack.pop32(), equals(42));
    });

    test('call pops args from stack', () async {
      /// Spec: "call L1 L2 S1: Call function, L2 args from stack."
      // call 0x200, 1, -> stack
      // Modes: L1=2, L2=1, S1=8
      final opcodes = [
        GlulxOp.call, // 0x30 (1-byte)
        0x12, 0x08, // modes
        0x02, 0x00, // L1 = 0x200
        0x01, // L2 = 1 arg
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      // Push argument
      interpreter.stack.push32(77);

      await interpreter.executeInstruction(); // call
      await interpreter.executeInstruction(); // ret

      expect(interpreter.stack.pop32(), equals(77));
    });

    test('ret returns value and restores PC', () async {
      /// Spec: "return L1: Return from the current function."
      // callf 0x210 -> stack, then add 5+3
      final opcodes = [
        ...op2(GlulxOp.callf),
        0x82,
        0x02, 0x10,
        // After return (PC = 0x105):
        GlulxOp.add, // 0x10
        0x11, 0x08, // L1=1, L2=1, S1=8
        0x05, 0x03, // 5 + 3
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction(); // callf
      await interpreter.executeInstruction(); // ret
      expect(interpreter.pc, equals(0x105)); // back to add

      await interpreter.executeInstruction(); // add

      expect(interpreter.stack.pop32(), equals(8));
      expect(interpreter.stack.pop32(), equals(99));
    });

    test('catch stores token and branches', () async {
      /// Spec: "catch S1 L1: Generate catch token, branch to L1."
      // catch -> stack, branch +6
      // Modes: S1=8 (low), L1=1 (high) = 0x18
      final opcodes = [
        GlulxOp.catchEx, // 0x32
        0x18, // S1=8, L1=1
        0x06, // offset 6 -> 0x103 + 6 - 2 = 0x107
        GlulxOp.nop, GlulxOp.nop, GlulxOp.nop, GlulxOp.nop,
        GlulxOp.nop, // 0x107
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction(); // catch

      expect(interpreter.pc, equals(0x107));
      final token = interpreter.stack.pop32();
      expect(token, greaterThan(0));
    });

    // ========== C0 function stack argument order test ==========

    test('C0 function receives first arg as topmost (below count)', () async {
      /// Spec: "last argument pushed first, first argument topmost.
      /// Then the number of arguments is pushed on top of that."
      // callfii 0x230, 10, 99 -> stack
      // Function 0x230 adds top two stack values (count + first arg)
      // With args [10, 99], correct stack is: [99, 10, 2] bottom->top
      // add pops 2 and 10, pushes 12, ret returns 12
      // Wrong order would give different result (e.g., 101)
      final opcodes = [
        ...op2(GlulxOp.callfii), // 0x81, 0x62
        0x12, 0x81, // L1=mode 2, L2=mode 1, L3=mode 1, S1=mode 8
        0x02, 0x30, // L1 = 0x230 (C0 function)
        0x0A, // L2 = 10 (first arg)
        0x63, // L3 = 99 (second arg)
      ];
      gameData = createGameData(opcodes);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction(); // callfii
      await interpreter.executeInstruction(); // add
      await interpreter.executeInstruction(); // ret

      // Should return 12 (count=2 + firstArg=10), not 101 (count=2 + secondArg=99)
      expect(interpreter.stack.pop32(), equals(12));
    });
  });
}

// Local MockGlkIoProvider removed
