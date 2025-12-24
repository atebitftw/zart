import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import '../../bin/cli/cli_platform_provider.dart';

void main() {
  /// Glulx Spec: I/O System Opcodes
  /// Reference: packages/glulxe/string.c stream_set_iosys() and stream_get_iosys()
  group('I/O System Opcodes', () {
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

    group('setiosys', () {
      test('setiosys mode 0 sets null I/O system', () async {
        /// Spec: setiosys L1 L2 - Set I/O mode to L1, rock to L2
        /// Mode 0 = None (null I/O), rock is ignored
        gameData = createGameData([
          0x81, 0x49, // setiosys opcode (0x149)
          0x00, 0x00, // modes: L1=mode 0 (zero), L2=mode 0 (zero)
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

        await interpreter.executeInstruction();

        // Verify by using getiosys - modes are stored and pushed to stack
        gameData = createGameData([
          0x81, 0x48, // getiosys opcode (0x148)
          0x88, // modes: S1=mode 8 (stack), S2=mode 8 (stack)
        ]);
        await interpreter.load(gameData);
        harness.setProgramCounter(0x100);

        await interpreter.executeInstruction();

        // Rock stored first, then mode
        expect(interpreter.stack.pop32(), equals(0)); // rock
        expect(interpreter.stack.pop32(), equals(0)); // mode
      });

      test('setiosys mode 1 sets filter I/O with rock', () async {
        /// Mode 1 = Filter, rock is the function address for character output
        gameData = createGameData([
          0x81, 0x49, // setiosys opcode (0x149)
          0x11, // modes: L1=mode 1 (1-byte), L2=mode 1 (1-byte)
          0x01, // L1 = 1 (filter mode)
          0x42, // L2 = 0x42 (function address)
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

        await interpreter.executeInstruction();

        // Verify with getiosys
        gameData = createGameData([
          0x81, 0x48, // getiosys
          0x88, // S1=stack, S2=stack
        ]);
        await interpreter.load(gameData);
        harness.setProgramCounter(0x100);

        await interpreter.executeInstruction();

        expect(interpreter.stack.pop32(), equals(0x42)); // rock (function addr)
        expect(interpreter.stack.pop32(), equals(1)); // mode
      });

      test('setiosys mode 2 sets Glk I/O (rock ignored)', () async {
        /// Mode 2 = Glk, rock is always set to 0 regardless of L2
        /// Reference: string.c - "rock = 0;" for Glk mode
        gameData = createGameData([
          0x81, 0x49, // setiosys opcode
          0x11,
          0x02, // L1 = 2 (Glk mode)
          0xFF, // L2 = 0xFF (should be ignored)
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

        await interpreter.executeInstruction();

        // Verify with getiosys
        gameData = createGameData([
          0x81, 0x48, // getiosys
          0x88, // S1=stack, S2=stack
        ]);
        await interpreter.load(gameData);
        harness.setProgramCounter(0x100);

        await interpreter.executeInstruction();

        expect(interpreter.stack.pop32(), equals(0)); // rock (forced to 0)
        expect(interpreter.stack.pop32(), equals(2)); // mode
      });

      test('setiosys unknown mode defaults to None', () async {
        /// Reference: string.c - default case falls through to iosys_None
        gameData = createGameData([
          0x81, 0x49, // setiosys opcode
          0x11,
          0x99, // L1 = 0x99 (unknown mode)
          0xAB, // L2 = 0xAB
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

        await interpreter.executeInstruction();

        // Verify with getiosys
        gameData = createGameData([
          0x81, 0x48, // getiosys
          0x88, // S1=stack, S2=stack
        ]);
        await interpreter.load(gameData);
        harness.setProgramCounter(0x100);

        await interpreter.executeInstruction();

        expect(interpreter.stack.pop32(), equals(0)); // rock (reset to 0)
        expect(interpreter.stack.pop32(), equals(0)); // mode (reset to None)
      });
    });

    group('getiosys', () {
      test('getiosys returns initial state (mode 0, rock 0)', () async {
        /// Initially, I/O system is in null mode with rock 0
        gameData = createGameData([
          0x81, 0x48, // getiosys opcode (0x148)
          0x88, // modes: S1=mode 8 (stack), S2=mode 8 (stack)
        ]);
        await interpreter.load(gameData);
        harness = GlulxInterpreterTestingHarness(interpreter);
        harness.setProgramCounter(0x100);
        interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

        await interpreter.executeInstruction();

        expect(interpreter.stack.pop32(), equals(0)); // rock
        expect(interpreter.stack.pop32(), equals(0)); // mode
      });
    });
  });
}

// Local MockGlkIoProvider removed
