import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_stack.dart';

void main() {
  group('Bitwise Operations', () {
    late GlulxInterpreter interpreter;

    setUp(() {
      interpreter = GlulxInterpreter(io: null);
    });

    test('aloadbit negative offset', () async {
      List<int> prog = [];
      // aloadbit 0x91 -1 sp
      prog.add(GlulxOp.aloadbit); // Op aloadbit
      prog.add(0x11);
      prog.add(0x08); // Modes
      prog.add(0x91); // Base
      prog.add(0xFF); // Bit -1

      final mem = Uint8List(512);
      // Header
      mem[0] = 0x47;
      mem[1] = 0x6C;
      mem[2] = 0x75;
      mem[3] = 0x6C;
      mem[4] = 0x00;
      mem[5] = 0x03;
      mem[6] = 0x01;
      mem[7] = 0x03;
      mem[8] = 0x00;
      mem[9] = 0x00;
      mem[10] = 0x01;
      mem[11] = 0x00; // RAM 0x100
      mem[12] = 0x00;
      mem[13] = 0x00;
      mem[14] = 0x02;
      mem[15] = 0x00; // EXT 0x200
      mem[16] = 0x00;
      mem[17] = 0x00;
      mem[18] = 0x02;
      mem[19] = 0x00;
      mem[20] = 0x00;
      mem[21] = 0x00;
      mem[22] = 0x10;
      mem[23] = 0x00;
      mem[24] = 0x00;
      mem[25] = 0x00;
      mem[26] = 0x00;
      mem[27] = 0x40; // Start 0x40

      // Code
      for (int i = 0; i < prog.length; i++) mem[0x40 + i] = prog[i];

      // Data
      mem[0x90] = 0x80; // Byte at base-1. 10000000. Bit 7 is 1.
      mem[0x91] = 0x00; // Byte at base.

      interpreter.load(mem);
      // stack size is set by load (or verified)
      await interpreter.run(maxSteps: 300);

      expect(interpreter.stack.pop(), equals(1));
    });

    test('aloadbit positive offset', () async {
      List<int> prog = [];
      prog.add(GlulxOp.aloadbit); // aloadbit
      prog.add(0x11);
      prog.add(0x08); // modes 1, 1, 8
      prog.add(0x90); // Base
      prog.add(0x07); // Bit 7 of 0x90

      final mem = Uint8List(512);
      mem[0] = 0x47;
      mem[1] = 0x6C;
      mem[2] = 0x75;
      mem[3] = 0x6C;
      mem[4] = 0x00;
      mem[5] = 0x03;
      mem[6] = 0x01;
      mem[7] = 0x03;
      mem[8] = 0x00;
      mem[9] = 0x00;
      mem[10] = 0x01;
      mem[11] = 0x00;
      mem[12] = 0x00;
      mem[13] = 0x00;
      mem[14] = 0x02;
      mem[15] = 0x00;
      mem[16] = 0x00;
      mem[17] = 0x00;
      mem[18] = 0x02;
      mem[19] = 0x00;
      mem[20] = 0x00;
      mem[21] = 0x00;
      mem[22] = 0x10;
      mem[23] = 0x00;
      mem[24] = 0x00;
      mem[25] = 0x00;
      mem[26] = 0x00;
      mem[27] = 0x40;

      for (int i = 0; i < prog.length; i++) mem[0x40 + i] = prog[i];
      mem[0x90] = 0x80;

      interpreter.load(mem);
      await interpreter.run(maxSteps: 300);

      expect(interpreter.stack.pop(), equals(1));
    });
  });
}
