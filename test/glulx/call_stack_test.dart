import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/zart.dart' show Debugger;

final maxSteps = Debugger
    .maxSteps; // do not change this without getting permission from user.

// Helper to create a Glulx game file with code
Uint8List createGame(List<int> code, {int ramStart = 0x400}) {
  final fileSize = 1024;
  final buffer = ByteData(fileSize);

  // Magic 'Glul'
  buffer.setUint32(0, 0x476C756C);
  // Version
  buffer.setUint32(4, 0x00030101);
  // RAM Start
  buffer.setUint32(8, ramStart);
  // Ext Start
  buffer.setUint32(12, fileSize);
  // End Mem
  buffer.setUint32(16, fileSize * 2);
  // Stack Size
  buffer.setUint32(20, 4096);
  // Start Func (at 0x40 typically)
  buffer.setUint32(24, 0x40);

  // Decoding Table
  buffer.setUint32(28, 0);
  // Checksum
  buffer.setUint32(32, 0);

  final bytes = buffer.buffer.asUint8List();

  // Copy code to 0x40
  final codeStart = 0x40;
  for (int i = 0; i < code.length; i++) {
    if (codeStart + i < bytes.length) {
      bytes[codeStart + i] = code[i];
    }
  }

  return bytes;
}

// Extension to write functions at specific addresses
Uint8List createGameWithFunctions(
  Map<int, List<int>> functions, {
  int startFuncAddr = 0x40,
}) {
  final fileSize = 2048;
  final buffer = ByteData(fileSize);

  buffer.setUint32(0, 0x476C756C);
  buffer.setUint32(8, 0x1000); // RAM Start high
  buffer.setUint32(12, fileSize);
  buffer.setUint32(16, 0x5000);
  buffer.setUint32(20, 4096);
  buffer.setUint32(24, startFuncAddr);

  final bytes = buffer.buffer.asUint8List();

  functions.forEach((addr, code) {
    for (int i = 0; i < code.length; i++) {
      if (addr + i < bytes.length) {
        bytes[addr + i] = code[i];
      }
    }
  });

  return bytes;
}

void main() {
  group('Glulx Stack and Call Tests', () {
    late GlulxInterpreter interpreter;

    setUp(() {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
      });
      interpreter = GlulxInterpreter();
    });

    test('stkcount', () async {
      // Logic:
      // 1. push 10
      // 2. push 20
      // 3. stkcount -> res
      final code = [
        // Function Header (Type C0, Locals Format 0,0)
        0xC0, 0x00, 0x00,
        // copy 10 push. Modes: Op1=1, Op2=8 -> 0x81
        GlulxOp.copy, 0x81, 10,
        // copy 20 push. Modes: Op1=1, Op2=8 -> 0x81
        GlulxOp.copy, 0x81, 20,
        // stkcount -> RAM[ramStart + 0x100]. Mode: Op0=E (RAM Any).
        // ModeByte=0x0E. Address offset 0x100.
        GlulxOp.stkcount, 0x0F, 0x00, 0x00, 0x01, 0x00,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // We pushed 2 items on top of the frame.
      // PLUS C0 pushes ArgCount (0). So 3 items.
      // Mode E data 0x00, 0x00, 0x01, 0x00 = offset 0x100
      // Absolute address = ramStart (0x400) + 0x100 = 0x500
      expect(interpreter.memRead32(interpreter.ramStart + 0x100), equals(3));
    });

    test('stkpeek', () async {
      interpreter.debugMode = true; // ENABLE DEBUG LOGGING
      final code = [
        0xC0, 0x00, 0x00,
        // Push 10
        GlulxOp.copy, 0x81, 10,
        // Push 20
        GlulxOp.copy, 0x81, 20,
        // stkpeek 0 -> RAM[ramStart + 0x100] (Should be 20)
        // Pos=0 (Mode 1 - Const Byte 0). Dest=RAM (Mode E - RAM Any).
        // Byte 1: Op0(1) | Op1(E)<<4 = 0xE1.
        // Op0 Value: 0. Op1 Value: 0x100.
        GlulxOp.stkpeek, 0xF1, 0x00, 0x00, 0x00, 0x01, 0x00,
        // stkpeek 1 -> RAM[ramStart + 0x104] (Should be 10)
        GlulxOp.stkpeek, 0xF1, 0x01, 0x00, 0x00, 0x01, 0x04,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // ramStart is 0x400. Mode E data 0x00,0x00,0x01,0x00 = offset 0x100
      // Absolute address = 0x400 + 0x100 = 0x500
      expect(interpreter.memRead32(interpreter.ramStart + 0x100), equals(20));
      expect(interpreter.memRead32(interpreter.ramStart + 0x104), equals(10));
    });

    test('stkswap', () async {
      final code = [
        0xC0, 0x00, 0x00,
        GlulxOp.copy, 0x81, 10,
        GlulxOp.copy, 0x81, 20,
        GlulxOp.stkswap,
        // Pop into RAM to verify order
        // Pop (Top) -> RAM[ramStart + 0x100]. Should be 10.
        // copy stack(8) -> RAM(E). Mode 0xE8.
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x00,
        // Pop (Next) -> RAM[ramStart + 0x104]. Should be 20.
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x04,
        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(interpreter.ramStart + 0x100), equals(10));
      expect(interpreter.memRead32(interpreter.ramStart + 0x104), equals(20));
    });

    test('stkroll', () async {
      // Stack: A (bottom), B, C, D, E (top)
      // stkroll 5 2 -> Rotate 5 items by 2 spots.
      final code = [
        0xC0, 0x00, 0x00,
        GlulxOp.copy, 0x81, 0xA,
        GlulxOp.copy, 0x81, 0xB,
        GlulxOp.copy, 0x81, 0xC,
        GlulxOp.copy, 0x81, 0xD,
        GlulxOp.copy, 0x81, 0xE,

        // stkroll 5 2
        // Op1: 5 (Mode 1). Op2: 2 (Mode 1).
        // ModeByte: 0x11.
        GlulxOp.stkroll, 0x11, 5, 2,

        // Pop 5 items and store to RAM[ramStart + 0x100..0x114]
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x00, // Top
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x04,
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x08,
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x0C,
        GlulxOp.copy, 0xF8, 0x00, 0x00, 0x01, 0x10, // Bottom

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      interpreter.load(createGame(code));
      await interpreter.run(maxSteps: maxSteps);

      // Expected: B (0xB) is Top
      expect(interpreter.memRead32(interpreter.ramStart + 0x100), equals(0xB));
      expect(interpreter.memRead32(interpreter.ramStart + 0x104), equals(0xA));
      expect(interpreter.memRead32(interpreter.ramStart + 0x108), equals(0xE));
      expect(interpreter.memRead32(interpreter.ramStart + 0x10C), equals(0xD));
      // Bottom is C (0xC)
      expect(interpreter.memRead32(interpreter.ramStart + 0x110), equals(0xC));
    });

    test('call and ret', () async {
      // Main calls 0x100.

      final mainFunc = [
        0xC0, 0x00, 0x00, // Header
        // call 0x100 0 -> RAM[0x200]
        // call is opcode 0x30 (1-byte)
        // Op1: 0x100 (Mode 2 - Short Const).
        // Op2: 0 (Mode 1 - Byte Const 0).
        // Op3: RAM[0x200] (Mode E - RAM 0000-FFFF).
        // Modes: Op1(2), Op2(1) -> 0x12.
        // Byte 2: Op3(E) -> 0x0E.
        GlulxOp.call, 0x12, 0x0F,
        0x01, 0x00, // Address 0x100
        0, // 0 args (Byte const)
        0x00, 0x00, 0x05, 0x00, // Dest 0x500

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      final calledFunc = [
        0xC0, 0x00, 0x00, // Header
        // ret 42 (opcode 0x31, 1-byte)
        // Op1: 42 (Mode 1).
        GlulxOp.ret, 0x01, 42,
      ];

      final functions = {0x40: mainFunc, 0x100: calledFunc};

      interpreter.load(createGameWithFunctions(functions));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(interpreter.ramStart + 0x500), equals(42));
    });

    test('call with arguments', () async {
      final mainFunc = [
        0xC0, 0x00, 0x00, // Header
        // Push 10, 20
        GlulxOp.copy, 0x81, 10,
        GlulxOp.copy, 0x81, 20,

        // call 0x100 2 -> RAM[0x200]
        // call is opcode 0x30 (1-byte)
        // Op1(0x100) Mode 2. Op2(2) Mode 1. Op3(RAM 0x200) Mode E.
        // Byte 1: Op1(2) | Op2(1)<<4 = 0x12.
        // Byte 2: Op3(E) = 0x0E.
        GlulxOp.call, 0x12, 0x0F,
        0x01, 0x00, // Address 0x100
        2, // NumArgs
        0x00, 0x00, 0x05, 0x00, // Dest 0x500

        GlulxOp.quit >> 8 & 0x7F | 0x80, GlulxOp.quit & 0xFF,
      ];

      final calledFunc = [
        0xC1,
        0x04,
        0x02,
        0x00,
        0x00, // Header: C1 (Locals), 2 Locals of 4 bytes
        // stack aligned to 4 bytes in interpreter.
        // Copy Local(0) -> Stack
        // Locals start at 0 (first), 4 (second).
        // Op1: Local(0). Mode: 9 (Local byte). Val=0.
        // Op2: Stack(8). Mode: 8.
        // Byte: 0x89.
        GlulxOp.copy, 0x89, 0x00,
        // Copy Local(4) -> Stack
        GlulxOp.copy, 0x89, 0x04,
        // add Stack Stack -> Stack
        GlulxOp.add, 0x88, 0x08,
        // ret Stack (opcode 0x31, 1-byte)
        GlulxOp.ret, 0x08,
      ];

      final functions = {0x40: mainFunc, 0x100: calledFunc};

      interpreter.load(createGameWithFunctions(functions));
      await interpreter.run(maxSteps: maxSteps);

      expect(interpreter.memRead32(interpreter.ramStart + 0x500), equals(30));
    });
  });
}
