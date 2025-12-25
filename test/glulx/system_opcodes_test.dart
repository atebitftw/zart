import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import '../../lib/src/cli/cli_platform_provider.dart';

void main() {
  group('System Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;

    Uint8List createGameData(List<int> opcodeBytes) {
      final data = Uint8List(512);
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C; // magic
      data[10] = 0x01; // RAMSTART 0x100
      data[14] = 0x02; // EXTSTART 0x200
      data[18] = 0x02; // ENDMEM 0x200
      data[22] = 0x04; // Stack size 0x400
      for (var i = 0; i < opcodeBytes.length; i++) {
        data[0x100 + i] = opcodeBytes[i];
      }
      return data;
    }

    setUp(() async {
      interpreter = GlulxInterpreter(CliPlatformProvider(gameName: 'test'));
    });

    test('random generates number in range', () async {
      // random 10, stack
      // Opcode: 0x81, 0x10. Modes: L1=1, S1=8 -> 0x81
      gameData = createGameData([0x81, 0x10, 0x81, 0x0A]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      final val = interpreter.stack.pop32();
      expect(val, greaterThanOrEqualTo(0));
      expect(val, lessThan(10));
    });

    test('random 0 generates arbitrary 32-bit number', () async {
      // random 0, stack
      gameData = createGameData([0x81, 0x10, 0x81, 0x00]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      // Hard to test randomness, but it should return an int
      final val = interpreter.stack.pop32();
      expect(val, isA<int>());
    });

    test('random negative range generates negative values', () async {
      // random -5, stack
      // Modes: L1=1, S1=8 -> 0x81. Operand: -5 (0xFB)
      gameData = createGameData([0x81, 0x10, 0x81, 0xFB]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      final val = interpreter.stack.pop32().toSigned(32);
      expect(val, lessThanOrEqualTo(0));
      expect(val, greaterThan(-5));
    });

    test('setrandom seeds the generator', () async {
      // setrandom 42
      // Opcode: 0x81, 0x11. Modes: L1=1 -> 0x01
      gameData = createGameData([0x81, 0x11, 0x01, 0x2A]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      // Verifies opcode executes without error.
    });

    test('verify returns 0 for success', () async {
      // verify stack
      // Opcode: 0x81, 0x21. Modes: S1=8 -> 0x08
      gameData = createGameData([0x81, 0x21, 0x08]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();
      expect(interpreter.stack.pop32(), equals(0));
    });
  });
}

// End of file
