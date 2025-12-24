import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import '../../bin/cli/cli_platform_provider.dart';

void main() {
  group('Double Precision Opcodes', () {
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

    List<int> doubleToBits(double d) {
      final bd = ByteData(8);
      bd.setFloat64(0, d);
      final hi = bd.getUint32(0);
      final lo = bd.getUint32(4);
      return [hi, lo];
    }

    double bitsToDouble(int hi, int lo) {
      final bd = ByteData(8);
      bd.setUint32(0, hi);
      bd.setUint32(4, lo);
      return bd.getFloat64(0);
    }

    setUp(() async {
      interpreter = GlulxInterpreter(CliPlatformProvider(gameName: 'test'));
    });

    test('numtod converts integer to double', () async {
      // numtod = 0x200, encoded as 0x82, 0x00 (2-byte opcode)
      gameData = createGameData([0x82, 0x00, 0x81, 0x08, 100]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      // Stack order: lo was stored first, hi second. Pop gets hi first.
      final hi = interpreter.stack.pop32();
      final lo = interpreter.stack.pop32();
      expect(bitsToDouble(hi, lo), equals(100.0));
    });

    test('dadd adds two doubles', () async {
      final d1 = doubleToBits(1.5);
      final d2 = doubleToBits(2.5);
      // dadd = 0x210, encoded as 0x82, 0x10 (2-byte opcode)
      gameData = createGameData([
        0x82,
        0x10,
        0x33,
        0x33,
        0x88,
        (d1[0] >> 24) & 0xFF,
        (d1[0] >> 16) & 0xFF,
        (d1[0] >> 8) & 0xFF,
        d1[0] & 0xFF,
        (d1[1] >> 24) & 0xFF,
        (d1[1] >> 16) & 0xFF,
        (d1[1] >> 8) & 0xFF,
        d1[1] & 0xFF,
        (d2[0] >> 24) & 0xFF,
        (d2[0] >> 16) & 0xFF,
        (d2[0] >> 8) & 0xFF,
        d2[0] & 0xFF,
        (d2[1] >> 24) & 0xFF,
        (d2[1] >> 16) & 0xFF,
        (d2[1] >> 8) & 0xFF,
        d2[1] & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      // Stack order: lo was stored first, hi second. Pop gets hi first.
      final hi = interpreter.stack.pop32();
      final lo = interpreter.stack.pop32();
      expect(bitsToDouble(hi, lo), equals(4.0));
    });

    test('dmul multiplies two doubles', () async {
      final d1 = doubleToBits(2.5);
      final d2 = doubleToBits(4.0);
      // dmul = 0x212, encoded as 0x82, 0x12 (2-byte opcode)
      gameData = createGameData([
        0x82,
        0x12,
        0x33,
        0x33,
        0x88,
        (d1[0] >> 24) & 0xFF,
        (d1[0] >> 16) & 0xFF,
        (d1[0] >> 8) & 0xFF,
        d1[0] & 0xFF,
        (d1[1] >> 24) & 0xFF,
        (d1[1] >> 16) & 0xFF,
        (d1[1] >> 8) & 0xFF,
        d1[1] & 0xFF,
        (d2[0] >> 24) & 0xFF,
        (d2[0] >> 16) & 0xFF,
        (d2[0] >> 8) & 0xFF,
        d2[0] & 0xFF,
        (d2[1] >> 24) & 0xFF,
        (d2[1] >> 16) & 0xFF,
        (d2[1] >> 8) & 0xFF,
        d2[1] & 0xFF,
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await interpreter.executeInstruction();
      // Stack order: lo was stored first, hi second. Pop gets hi first.
      final hi = interpreter.stack.pop32();
      final lo = interpreter.stack.pop32();
      expect(bitsToDouble(hi, lo), equals(10.0));
    });

    group('Trigonometric Opcodes', () {
      test('dsin returns correct value', () async {
        // dsin = 0x220, encoded as 0x82, 0x20 (2-byte opcode)
        gameData = createGameData([
          0x82, 0x20, 0x33, 0x88,
          0, 0, 0, 0, // Xhi
          0, 0, 0, 0, // Xlo
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        // Stack order: lo was stored first, hi second. Pop gets hi first.
        final hi = interpreter.stack.pop32();
        final lo = interpreter.stack.pop32();
        expect(bitsToDouble(hi, lo), closeTo(0.0, 0.00001));
      });
    });

    group('Double Comparison Branches', () {
      test('jdisnan branches on NaN', () async {
        final d1 = doubleToBits(double.nan);
        // jdisnan = 0x238, encoded as 0x82, 0x38 (2-byte opcode)
        gameData = createGameData([
          0x82,
          0x38,
          0x33,
          0x01,
          (d1[0] >> 24) & 0xFF,
          (d1[0] >> 16) & 0xFF,
          (d1[0] >> 8) & 0xFF,
          d1[0] & 0xFF,
          (d1[1] >> 24) & 0xFF,
          (d1[1] >> 16) & 0xFF,
          (d1[1] >> 8) & 0xFF,
          d1[1] & 0xFF,
          0x10,
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        // Opcode(2) + Modes(2) + Op1(4) + Op2(4) + Offset(1) = 13 bytes.
        // PC 256 + 13 = 269.
        // Branch (269 + 16 - 2) = 283
        expect(interpreter.pc, equals(283));
      });

      test('jdeq branches on exact equality', () async {
        final d1 = doubleToBits(1.0);
        final d2 = doubleToBits(1.0);
        final d3 = doubleToBits(0.0);
        // jdeq = 0x230, encoded as 0x82, 0x30 (2-byte opcode)
        gameData = createGameData([
          0x82,
          0x30,
          0x33,
          0x33,
          0x33,
          0x01,
          (d1[0] >> 24) & 0xFF,
          (d1[0] >> 16) & 0xFF,
          (d1[0] >> 8) & 0xFF,
          d1[0] & 0xFF,
          (d1[1] >> 24) & 0xFF,
          (d1[1] >> 16) & 0xFF,
          (d1[1] >> 8) & 0xFF,
          d1[1] & 0xFF,
          (d2[0] >> 24) & 0xFF,
          (d2[0] >> 16) & 0xFF,
          (d2[0] >> 8) & 0xFF,
          d2[0] & 0xFF,
          (d2[1] >> 24) & 0xFF,
          (d2[1] >> 16) & 0xFF,
          (d2[1] >> 8) & 0xFF,
          d2[1] & 0xFF,
          (d3[0] >> 24) & 0xFF,
          (d3[0] >> 16) & 0xFF,
          (d3[0] >> 8) & 0xFF,
          d3[0] & 0xFF,
          (d3[1] >> 24) & 0xFF,
          (d3[1] >> 16) & 0xFF,
          (d3[1] >> 8) & 0xFF,
          d3[1] & 0xFF,
          0x10,
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

        await interpreter.executeInstruction();
        // Opcode(2) + Modes(4) + (6 * 4) + Offset(1) = 31 bytes.
        // PC 256 + 31 = 287.
        // Branch (287 + 16 - 2) = 301
        expect(interpreter.pc, equals(301));
      });
    });
  });
}

// Local MockGlkIoProvider removed
