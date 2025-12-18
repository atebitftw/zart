import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

void main() {
  group('Floating Point Opcodes', () {
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

    int floatToBits(double f) {
      final bd = ByteData(4);
      bd.setFloat32(0, f);
      return bd.getUint32(0);
    }

    double bitsToFloat(int bits) {
      final bd = ByteData(4);
      bd.setUint32(0, bits);
      return bd.getFloat32(0);
    }

    setUp(() async {
      interpreter = GlulxInterpreter(MockGlkIoProvider());
    });

    test('numtof converts integer to float', () async {
      // numtof 100, stack
      // Opcode: 0x81, 0x90. Modes: L1=1, S1=8 -> 0x81
      gameData = createGameData([0x81, 0x90, 0x81, 100]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      final bits = interpreter.stack.pop32();
      expect(bitsToFloat(bits), equals(100.0));
    });

    test('ftonumz converts float to integer (truncate)', () async {
      // ftonumz 3.14, stack
      // Opcode: 0x81, 0x91. Modes: L1=3 (4-byte const), S1=8 -> 0x83
      final piBits = floatToBits(3.14);
      gameData = createGameData([
        0x81,
        0x91,
        0x83,
        (piBits >> 24) & 0xFF,
        (piBits >> 16) & 0xFF,
        (piBits >> 8) & 0xFF,
        piBits & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(3));
    });

    test('fadd adds two floats', () async {
      // fadd 1.5, 2.5, stack
      // Opcode: 0x81, 0xA0. Modes: L1=3, L2=3, S1=8 -> 0x33, 0x08
      final f1Bits = floatToBits(1.5);
      final f2Bits = floatToBits(2.5);
      gameData = createGameData([
        0x81,
        0xA0,
        0x33,
        0x08,
        (f1Bits >> 24) & 0xFF,
        (f1Bits >> 16) & 0xFF,
        (f1Bits >> 8) & 0xFF,
        f1Bits & 0xFF,
        (f2Bits >> 24) & 0xFF,
        (f2Bits >> 16) & 0xFF,
        (f2Bits >> 8) & 0xFF,
        f2Bits & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      final bits = interpreter.stack.pop32();
      expect(bitsToFloat(bits), equals(4.0));
    });

    test('fmul multiplies two floats', () async {
      // fmul 2.0, 3.5, stack
      // Opcode: 0x81, 0xA2. Modes: 0x33, 0x08
      final f1Bits = floatToBits(2.0);
      final f2Bits = floatToBits(3.5);
      gameData = createGameData([
        0x81,
        0xA2,
        0x33,
        0x08,
        (f1Bits >> 24) & 0xFF,
        (f1Bits >> 16) & 0xFF,
        (f1Bits >> 8) & 0xFF,
        f1Bits & 0xFF,
        (f2Bits >> 24) & 0xFF,
        (f2Bits >> 16) & 0xFF,
        (f2Bits >> 8) & 0xFF,
        f2Bits & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      final bits = interpreter.stack.pop32();
      expect(bitsToFloat(bits), equals(7.0));
    });

    test('fdiv divides two floats', () async {
      // fdiv 10.0, 4.0, stack
      // Opcode: 0x81, 0xA3. Modes: 0x33, 0x08
      final f1Bits = floatToBits(10.0);
      final f2Bits = floatToBits(4.0);
      gameData = createGameData([
        0x81,
        0xA3,
        0x33,
        0x08,
        (f1Bits >> 24) & 0xFF,
        (f1Bits >> 16) & 0xFF,
        (f1Bits >> 8) & 0xFF,
        f1Bits & 0xFF,
        (f2Bits >> 24) & 0xFF,
        (f2Bits >> 16) & 0xFF,
        (f2Bits >> 8) & 0xFF,
        f2Bits & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      final bits = interpreter.stack.pop32();
      expect(bitsToFloat(bits), equals(2.5));
    });

    group('Trigonometric Opcodes', () {
      test('sin returns correct value', () async {
        // sin 0.0, stack
        // Modes: L1=3, S1=8 -> 0x83
        final f1Bits = floatToBits(0.0);
        gameData = createGameData([
          0x81,
          0xB0,
          0x83,
          (f1Bits >> 24) & 0xFF,
          (f1Bits >> 16) & 0xFF,
          (f1Bits >> 8) & 0xFF,
          f1Bits & 0xFF,
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        final bits = interpreter.stack.pop32();
        expect(bitsToFloat(bits), closeTo(0.0, 0.00001));
      });

      test('atan2 returns correct quadrant', () async {
        // atan2 1.0, 1.0, stack (pi/4)
        // Modes: L1=3, L2=3, S1=8 -> 0x33, 0x08
        final f1Bits = floatToBits(1.0);
        final f2Bits = floatToBits(1.0);
        gameData = createGameData([
          0x81,
          0xB6,
          0x33,
          0x08,
          (f1Bits >> 24) & 0xFF,
          (f1Bits >> 16) & 0xFF,
          (f1Bits >> 8) & 0xFF,
          f1Bits & 0xFF,
          (f2Bits >> 24) & 0xFF,
          (f2Bits >> 16) & 0xFF,
          (f2Bits >> 8) & 0xFF,
          f2Bits & 0xFF,
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        final bits = interpreter.stack.pop32();
        expect(bitsToFloat(bits), closeTo(0.785398, 0.00001));
      });
    });

    group('Floating Comparison Branches', () {
      test('jisnan branches on NaN', () async {
        // jisnan NaN, offset 10
        // Modes: L1=3, L2=1 -> 0x13
        final nanBits = floatToBits(double.nan);
        gameData = createGameData([
          0x81, 0xC0, 0x13,
          (nanBits >> 24) & 0xFF, (nanBits >> 16) & 0xFF, (nanBits >> 8) & 0xFF, nanBits & 0xFF,
          0x10, // branch offset
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        // Opcode(2) + Modes(1) + Op1(4) + Offset(1) = 8 bytes.
        // PC was 0x100. Next is 0x108.
        // Branch (0x108 + 0x10 - 2) = 0x116
        expect(interpreter.pc, equals(0x116));
      });

      test('jfeq branches on exact equality', () async {
        // jfeq 1.0, 1.0, 0.0, offset 16
        // Modes: L1=3, L2=3, L3=3, L4=1 -> 0x33, 0x13
        final f1Bits = floatToBits(1.0);
        final f2Bits = floatToBits(1.0);
        final f3Bits = floatToBits(0.0);
        gameData = createGameData([
          0x81, 0xC2, 0x33, 0x13,
          (f1Bits >> 24) & 0xFF, (f1Bits >> 16) & 0xFF, (f1Bits >> 8) & 0xFF, f1Bits & 0xFF,
          (f2Bits >> 24) & 0xFF, (f2Bits >> 16) & 0xFF, (f2Bits >> 8) & 0xFF, f2Bits & 0xFF,
          (f3Bits >> 24) & 0xFF, (f3Bits >> 16) & 0xFF, (f3Bits >> 8) & 0xFF, f3Bits & 0xFF,
          0x10, // offset
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        // Opcode(2) + Modes(2) + Op1(4) + Op2(4) + Op3(4) + Offset(1) = 17 bytes.
        // Next is 0x111.
        // Branch (0x111 + 0x10 - 2) = 0x11F
        expect(interpreter.pc, equals(0x11F));
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
