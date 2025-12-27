import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

void main() {
  /// Glulx Spec Section 2.4.5: Miscellaneous Opcodes
  group('Gestalt Opcode', () {
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

    test('gestalt GlulxVersion returns 0x00030103', () async {
      /// Spec: gestalt L1 L2 S1 - Query capability L1 with argument L2.
      /// Selector 0 = GlulxVersion -> returns Glulx spec version 3.1.3

      // Opcode: 0x100 (gestalt) - encoded as 2-byte form: 0x81 0x00
      // Modes: L1=mode 1 (1-byte const), L2=mode 0 (zero), S1=mode 8 (stack push)
      // Operands: L1=0 (GlulxVersion), L2 is implicit zero
      gameData = createGameData([
        0x81, 0x00, // gestalt opcode (0x100 encoded as 2-byte)
        0x10, 0x08, // modes: L1=mode 0, L2=mode 1, S1=mode 8
        0x00, // L2=0 (arg, not used for this selector)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // Glulx spec version 3.1.3
      expect(interpreter.stack.pop32(), equals(0x00030103));
    });

    test('gestalt TerpVersion returns interpreter version', () async {
      /// Selector 1 = TerpVersion

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes: L1=mode 1, L2=mode 1, S1=mode 8
        0x01, // L1=1 (TerpVersion)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      // Zart version 0.1.0
      expect(interpreter.stack.pop32(), equals(0x00000100));
    });

    test('gestalt ResizeMem returns 1 (supported)', () async {
      /// Selector 2 = ResizeMem

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x02, // L1=2 (ResizeMem)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt Undo returns 1 (supported)', () async {
      /// Selector 3 = Undo

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x03, // L1=3 (Undo)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt IOSystem returns 1 for null system (0)', () async {
      /// Selector 4 = IOSystem, arg 0 = null I/O system

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x04, // L1=4 (IOSystem)
        0x00, // L2=0 (null)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt IOSystem returns 1 for filter system (1)', () async {
      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x04, // L1=4 (IOSystem)
        0x01, // L2=1 (filter)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt IOSystem returns 1 for Glk system (2)', () async {
      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x04, // L1=4 (IOSystem)
        0x02, // L2=2 (Glk)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt IOSystem returns 0 for unknown system', () async {
      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x04, // L1=4 (IOSystem)
        0x05, // L2=5 (unknown)
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(0));
    });

    test('gestalt Unicode returns 1 (supported)', () async {
      /// Selector 5 = Unicode

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x05, // L1=5 (Unicode)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt Float returns 1 (supported)', () async {
      /// Selector 11 = Float

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x0B, // L1=11 (Float)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt Double returns 1 (supported)', () async {
      /// Selector 13 = Double

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x0D, // L1=13 (Double)
        0x00, // L2=0
      ]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0]));

      await interpreter.executeInstruction();

      expect(interpreter.stack.pop32(), equals(1));
    });

    test('gestalt unknown selector returns 0', () async {
      /// Reference gestalt.c: default: return 0;

      gameData = createGameData([
        0x81, 0x00, // gestalt opcode
        0x11, 0x08, // modes
        0x7F, // L1=127 (unknown selector)
        0x00, // L2=0
      ]);
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
