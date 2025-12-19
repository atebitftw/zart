import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';

void main() {
  group('Stream Opcodes', () {
    late GlulxInterpreter interpreter;
    late GlulxInterpreterTestingHarness harness;
    late Uint8List gameData;
    late MockGlkIoProvider mockIo;

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
      mockIo = MockGlkIoProvider();
      interpreter = GlulxInterpreter(mockIo);
    });

    Future<void> setupIosysGlk(GlulxInterpreter interpreter, GlulxInterpreterTestingHarness harness) async {
      // Execute setiosys 2, 0
      // Opcode: 0x81, 0x49. Modes: L1=1, L2=0 -> 0x01. Operand: 2
      final setupBytes = [0x81, 0x49, 0x01, 0x02];
      final originalPC = interpreter.pc;
      // Temporarily inject setup code at 0x1F0 (arbitrary safe spot in RAM)
      for (var i = 0; i < setupBytes.length; i++) {
        interpreter.memoryMap.writeByte(0x1F0 + i, setupBytes[i]);
      }
      harness.setProgramCounter(0x1F0);
      await interpreter.executeInstruction();
      harness.setProgramCounter(originalPC);
    }

    test('streamchar outputs a character', () async {
      // streamchar 'A' (0x41)
      // Opcode: 0x70. Modes: L1=1 -> 0x01
      gameData = createGameData([0x70, 0x01, 0x41]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await setupIosysGlk(interpreter, harness);

      await interpreter.executeInstruction();
      expect(mockIo.output, contains(0x41));
    });

    test('streamunichar outputs a unicode character', () async {
      // streamunichar 0x1234
      // Opcode: 0x73. Modes: L1=3 (4-byte constant) -> 0x03
      gameData = createGameData([0x73, 0x03, 0x00, 0x00, 0x12, 0x34]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await setupIosysGlk(interpreter, harness);

      await interpreter.executeInstruction();
      expect(mockIo.output, contains(0x1234));
    });

    test('streamnum outputs decimals', () async {
      // streamnum -123
      // Opcode: 0x71. Modes: L1=1 -> 0x01. Operand: -123 (0x85)
      gameData = createGameData([0x71, 0x01, 0x85]);
      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await setupIosysGlk(interpreter, harness);

      await interpreter.executeInstruction();
      // "-123" -> [0x2D, 0x31, 0x32, 0x33]
      expect(mockIo.output, equals([0x2D, 0x31, 0x32, 0x33]));
    });

    test('streamstr outputs an E0 string', () async {
      // streamstr addr
      // Opcode: 0x72. Modes: L1=2 -> 0x02. Operand: 0x200
      gameData = createGameData([0x72, 0x02, 0x02, 0x00]);
      // E0 string at 0x200: [0xE0, 'H', 'e', 'l', 'l', 'o', 0x00]
      gameData[0x200] = 0xE0;
      gameData[0x201] = 0x48; // H
      gameData[0x202] = 0x65; // e
      gameData[0x203] = 0x6C; // l
      gameData[0x204] = 0x6C; // l
      gameData[0x205] = 0x6F; // o
      gameData[0x206] = 0x00;

      await interpreter.load(gameData);
      harness = GlulxInterpreterTestingHarness(interpreter);
      harness.setProgramCounter(0x100);
      interpreter.stack.pushFrame(Uint8List.fromList([0, 0, 0, 0]));

      await setupIosysGlk(interpreter, harness);

      await interpreter.executeInstruction();
      expect(String.fromCharCodes(mockIo.output), equals('Hello'));
    });
  });
}

class MockGlkIoProvider extends TestGlkIoProvider {
  final List<int> output = [];

  @override
  FutureOr<int> glkDispatch(int selector, List<int> args) {
    if (selector == GlkIoSelectors.putChar || selector == GlkIoSelectors.putCharUni) {
      output.add(args[0]);
    }
    return 0;
  }
}
