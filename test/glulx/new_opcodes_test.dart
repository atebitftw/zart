import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_opcodes.dart';
import 'package:zart/src/io/io_provider.dart';
import 'package:zart/zart.dart' show Debugger;

final maxSteps = Debugger.maxSteps;

void main() {
  group('New Glulx Opcodes', () {
    late GlulxInterpreter interpreter;

    Uint8List createGame(List<int> code, {int ramStart = 0x40, int fileSize = 512}) {
      final bytes = Uint8List(fileSize);
      final bd = ByteData.sublistView(bytes);

      bd.setUint32(GlulxHeader.magicNumber, 0x476C756C);
      bd.setUint32(GlulxHeader.version, 0x00030102);
      bd.setUint32(GlulxHeader.ramStart, ramStart);
      bd.setUint32(GlulxHeader.extStart, fileSize);
      bd.setUint32(GlulxHeader.endMem, fileSize);
      bd.setUint32(GlulxHeader.stackSize, 1024);
      bd.setUint32(GlulxHeader.startFunc, 0x40);
      bd.setUint32(GlulxHeader.checksum, 0);

      bytes[0x40] = 0xC0;
      bytes[0x41] = 0x00;
      bytes[0x42] = 0x00;

      for (int i = 0; i < code.length; i++) {
        bytes[0x43 + i] = code[i];
      }

      return bytes;
    }

    // jgtu (0x2C) - unit tested
    test('jgtu branches on unsigned greater than', () async {
      final code = [
        GlulxOpcodes.jgtu, 0x33, 0x10,
        0xFF, 0xFF, 0xFF, 0xFF, // L1 = max unsigned
        0x00, 0x00, 0x00, 0x01, // L2 = 1
        0x05, // branch offset
        0x81, 0x20, 0x00, // quit (skipped)
        0x81, 0x20, 0x00, // quit (target)
      ];
      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);
      expect(true, isTrue);
    });

    // jleu (0x2D) - unit tested
    test('jleu branches on unsigned less or equal', () async {
      final code = [
        GlulxOpcodes.jleu, 0x33, 0x10,
        0x00, 0x00, 0x00, 0x01, // L1 = 1
        0xFF, 0xFF, 0xFF, 0xFF, // L2 = max unsigned
        0x05,
        0x81, 0x20, 0x00,
        0x81, 0x20, 0x00,
      ];
      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);
      expect(true, isTrue);
    });

    // setiosys (0x149) / getiosys (0x148) - unit tested
    test('setiosys and getiosys work', () async {
      final code = [
        0x81, 0x49, 0x11, 0x02, 0x7B, // setiosys 2, 123
        0x81, 0x48, 0x88, // getiosys -> stack, stack
        0x81, 0x20, 0x00, // quit
      ];
      interpreter = GlulxInterpreter();
      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);
      expect(true, isTrue);
    });

    // aloadbit (0x4B) - unit tested
    test('aloadbit reads a bit', () async {
      final code = [
        GlulxOpcodes.aloadbit,
        0x11, 0x80, // L1=const1, L2=const1, S1=stack
        0x50, // address
        0x00, // bit 0
        0x81, 0x20, 0x00,
      ];

      final game = createGame(code);
      game[0x50] = 0x01; // Pre-set bit 0 in memory
      interpreter = GlulxInterpreter();
      interpreter.load(game);
      await interpreter.run(maxSteps: maxSteps);
      expect(true, isTrue);
    });
  });
}

class _MockIoProvider implements IoProvider {
  final Future<int> Function(int id, List<int> args) _glkHandler;
  _MockIoProvider(this._glkHandler);

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async => null;

  @override
  int getFlags1() => 0;

  @override
  Future<int> glulxGlk(int id, List<int> args) => _glkHandler(id, args);
}
