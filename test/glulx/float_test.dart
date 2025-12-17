import 'package:test/test.dart';

import 'package:zart/src/glulx/interpreter.dart';
import 'dart:typed_data';

import 'dart:math' as math;
import 'package:zart/src/glulx/glulx_opcodes.dart';

// Helper to create a basic Glulx game with given opcodes
GlulxInterpreter createInterpreter(List<int> code) {
  // Minimal header (36 bytes) + code
  final memory = Uint8List(2048);
  final view = ByteData.view(memory.buffer);

  // Magic 'Glul'
  view.setUint32(0, 0x476C756C);
  view.setUint32(4, 0x00030101); // Version
  view.setUint32(8, 0); // RAM start (0 for easier testing)
  view.setUint32(12, 2048); // Ext start (End of file data)
  view.setUint32(16, 2048); // End mem (enough for stack)
  view.setUint32(20, 1024); // Stack size
  view.setUint32(24, 36); // Start func
  view.setUint32(32, 0); // Checksum

  // Function Header at 36: Type C0 (Stack args), No locals
  memory[36] = 0xC0;
  memory[37] = 0x00;
  memory[38] = 0x00;

  // Copy code to 39 (after function header)
  for (var i = 0; i < code.length; i++) {
    memory[39 + i] = code[i];
  }

  final interp = GlulxInterpreter();
  interp.load(memory);
  return interp;
}

// Helper to encode float as 32-bit int
int floatToBits(double val) {
  var list = Float32List(1);
  list[0] = val;
  return list.buffer.asInt32List()[0];
}

// Helper to decode float from 32-bit int
double bitsToFloat(int val) {
  var list = Int32List(1);
  list[0] = val;
  return list.buffer.asFloat32List()[0];
}

// Helper to encode opcode to bytes (variable length)
List<int> encodeOp(int op) {
  if (op <= 0x7F) return [op];
  if (op <= 0x3FFF) return [(op >> 8) | 0x80, op & 0xFF];
  return [(op >> 24) | 0xC0, (op >> 16) & 0xFF, (op >> 8) & 0xFF, op & 0xFF];
}

void main() {
  group('Glulx Floating Point Opcodes', () {
    test('numtof converts int to float', () {
      // numtof 42 (0x2A) -> RAM 100
      final code = <int>[
        ...encodeOp(GlulxOpcodes.numtof),
        0xD1, // Modes: L1=ConstByte(1), S1=ConstRAM(D=13)
        42, // L1 val
        // S1 addr (address 100)
        0, 100,
        ...encodeOp(GlulxOpcodes.quit), // ret 0
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      int resultBits = interp.memory.getUint32(100);
      double result = bitsToFloat(resultBits);
      expect(result, equals(42.0));
    });

    test('ftonumz converts float to int (truncate)', () {
      // ftonumz 42.7 -> RAM 100 (should be 42)
      int floatBits = floatToBits(42.7);

      final code = <int>[
        ...encodeOp(GlulxOpcodes.ftonumz),
        0xD3, // Modes: L1=ConstInt(3), S1=ConstRAM(D)
        (floatBits >> 24) & 0xFF, (floatBits >> 16) & 0xFF, (floatBits >> 8) & 0xFF, floatBits & 0xFF,
        0, 100, // Dest addr 100
        ...encodeOp(GlulxOpcodes.quit), // ret 0
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      int result = interp.memory.getUint32(100);
      expect(result, equals(42));
    });

    test('ftonumz handles negative truncation', () {
      // ftonumz -42.7 -> -42
      int floatBits = floatToBits(-42.7);

      final code = <int>[
        ...encodeOp(GlulxOpcodes.ftonumz),
        0xD3,
        (floatBits >> 24) & 0xFF,
        (floatBits >> 16) & 0xFF,
        (floatBits >> 8) & 0xFF,
        floatBits & 0xFF,
        0, 100, // Dest addr 100
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      int result = interp.memory.getInt32(100); // Signed check
      expect(result, equals(-42));
    });

    test('ftonumn converts float to int (round)', () {
      // ftonumn 42.7 -> 43
      int floatBits = floatToBits(42.7);

      final code = <int>[
        ...encodeOp(GlulxOpcodes.ftonumn),
        0xD3,
        (floatBits >> 24) & 0xFF,
        (floatBits >> 16) & 0xFF,
        (floatBits >> 8) & 0xFF,
        floatBits & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      int result = interp.memory.getUint32(100);
      expect(result, equals(43));
    });

    test('fadd adds floats', () {
      // fadd 1.5 2.5 -> 4.0
      int f1 = floatToBits(1.5);
      int f2 = floatToBits(2.5);

      // fadd (0x1A0) L1 L2 S1
      // Encoding 0x1A0 -> 0x81 0xA0
      // Modes: L1, L2, S1
      // Pack into 2 bytes: (L1, L2), (S1, 0)
      // L1=3 (Int), L2=3 (Int), S1=D (RAM)
      // Byte 1: 0x33. Byte 2: 0x0D.

      final code = <int>[
        ...encodeOp(GlulxOpcodes.fadd),
        0x33, 0x0D, // Modes
        (f1 >> 24) & 0xFF, (f1 >> 16) & 0xFF, (f1 >> 8) & 0xFF, f1 & 0xFF,
        (f2 >> 24) & 0xFF, (f2 >> 16) & 0xFF, (f2 >> 8) & 0xFF, f2 & 0xFF,
        0, 100, // Addr 100
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      expect(bitsToFloat(interp.memory.getUint32(100)), equals(4.0));
    });

    test('sqrt calculates square root', () {
      // sqrt 16.0 -> 4.0
      int f1 = floatToBits(16.0);

      // sqrt (0x1A8) L1 S1
      // 0x81 0xA8
      // Modes: 0xD3 (L1=3, S1=D)

      final code = <int>[
        ...encodeOp(GlulxOpcodes.sqrt),
        0xD3, // Modes
        (f1 >> 24) & 0xFF, (f1 >> 16) & 0xFF, (f1 >> 8) & 0xFF, f1 & 0xFF,
        0, 100,
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      expect(bitsToFloat(interp.memory.getUint32(100)), equals(4.0));
    });

    test('fmod calculates modulus', () {
      // fmod 5.5 2.0 -> 1.5
      int f1 = floatToBits(5.5);
      int f2 = floatToBits(2.0);

      // fmod 0x1A4 -> 0x81 0xA4
      // Modes: 0x33 0x0D

      final code = <int>[
        ...encodeOp(GlulxOpcodes.fmod),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      expect(bitsToFloat(interp.memory.getUint32(100)), equals(1.5));
    });

    test('sin calculates sine', () {
      // sin(0) = 0
      int f1 = floatToBits(0.0);

      final code = <int>[
        ...encodeOp(GlulxOpcodes.sin),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      expect(bitsToFloat(interp.memory.getUint32(100)), equals(0.0));
    });

    test('ceil and floor', () {
      // ceil 1.2 -> 2.0
      // floor 1.8 -> 1.0
      int f1 = floatToBits(1.2);
      int f2 = floatToBits(1.8);

      // ceil 0x198
      // floor 0x199

      final code = <int>[
        ...encodeOp(GlulxOpcodes.ceil),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,

        ...encodeOp(GlulxOpcodes.floor),
        0xD3,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        104,

        ...encodeOp(GlulxOpcodes.quit),
      ];

      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);

      expect(bitsToFloat(interp.memory.getUint32(100)), equals(2.0));
      expect(bitsToFloat(interp.memory.getUint32(104)), equals(1.0));
    });
    test('fsub subtracts floats', () {
      int f1 = floatToBits(5.5);
      int f2 = floatToBits(2.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.fsub),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), equals(3.5));
    });

    test('fmul multiplies floats', () {
      int f1 = floatToBits(2.0);
      int f2 = floatToBits(3.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.fmul),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), equals(6.0));
    });

    test('fdiv divides floats', () {
      int f1 = floatToBits(10.0);
      int f2 = floatToBits(2.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.fdiv),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), equals(5.0));
    });

    test('exp calculates exponent', () {
      // exp(1.0) approx 2.71828
      int f1 = floatToBits(1.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.exp),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(2.71828, 0.0001));
    });

    test('log calculates natural log', () {
      int f1 = floatToBits(math.e);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.log),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(1.0, 0.0001));
    });

    test('pow calculates power', () {
      int f1 = floatToBits(2.0);
      int f2 = floatToBits(3.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.pow),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), equals(8.0));
    });

    test('cos calculates cosine', () {
      int f1 = floatToBits(math.pi);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.cos),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(-1.0, 0.0001));
    });

    test('tan calculates tangent', () {
      int f1 = floatToBits(0.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.tan),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(0.0, 0.0001));
    });

    test('asin calculates arc sine', () {
      int f1 = floatToBits(1.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.asin),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(math.pi / 2, 0.0001));
    });

    test('acos calculates arc cosine', () {
      int f1 = floatToBits(1.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.acos),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(0.0, 0.0001));
    });

    test('atan calculates arc tangent', () {
      int f1 = floatToBits(0.0);
      final code = <int>[
        ...encodeOp(GlulxOpcodes.atan),
        0xD3,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(0.0, 0.0001));
    });

    test('atan2 calculates arc tangent 2', () {
      // atan2(0, 1) = 0
      int f1 = floatToBits(0.0); // y
      int f2 = floatToBits(1.0); // x
      final code = <int>[
        ...encodeOp(GlulxOpcodes.atan2),
        0x33,
        0x0D,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interp = createInterpreter(code);
      interp.run(maxSteps: 5000);
      expect(bitsToFloat(interp.memory.getUint32(100)), closeTo(0.0, 0.0001));
    });

    test('jfeq branches on equality', () {
      int f1 = floatToBits(2.5);
      int f2 = floatToBits(2.5);
      int f3 = floatToBits(3.0);

      // Branch offset calculation:
      // Fail Block: copy (0x40) + modes + L1 + S1 + quit (0x120 + modes)
      // copy: 0x40 0x91 00 00 64 -> 5 bytes.
      // quit: 0x81 0x20 -> 2 bytes.
      // Total 7 bytes.

      final codeEqual = <int>[
        ...encodeOp(GlulxOpcodes.jfeq),
        0x33, 0x01, // L1=Int, L2=Int, L3=ConstByte
        (f1 >> 24) & 0xFF, (f1 >> 16) & 0xFF, (f1 >> 8) & 0xFF, f1 & 0xFF,
        (f2 >> 24) & 0xFF, (f2 >> 16) & 0xFF, (f2 >> 8) & 0xFF, f2 & 0xFF,
        7, // Offset 7
        // Fail Block
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 0, 0, 100,
        ...encodeOp(GlulxOpcodes.quit),

        // Success Block
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 1, 0, 100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpEq = createInterpreter(codeEqual);
      interpEq.run(maxSteps: 5000);
      expect(interpEq.memory.getUint32(100), equals(1));

      // Not Equal
      final codeNotEq = <int>[
        ...encodeOp(GlulxOpcodes.jfeq),
        0x33, 0x01,
        (f1 >> 24) & 0xFF, (f1 >> 16) & 0xFF, (f1 >> 8) & 0xFF, f1 & 0xFF,
        (f3 >> 24) & 0xFF, (f3 >> 16) & 0xFF, (f3 >> 8) & 0xFF, f3 & 0xFF,
        7,

        // Fail Block
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 0, 0, 100,
        ...encodeOp(GlulxOpcodes.quit),

        // Success Block
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 1, 0, 100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpNe = createInterpreter(codeNotEq);
      interpNe.run(maxSteps: 5000);
      expect(interpNe.memory.getUint32(100), equals(0));
    });
    test('jfne branches on inequality', () {
      int f1 = floatToBits(2.5);
      int f2 = floatToBits(3.0);
      int f3 = floatToBits(2.5);

      // Case 1: Not Equal (2.5 != 3.0) -> Branch Taken (1)
      final codeNe = <int>[
        ...encodeOp(GlulxOpcodes.jfne),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpNe = createInterpreter(codeNe);
      interpNe.run(maxSteps: 5000);
      expect(interpNe.memory.getUint32(100), equals(1));

      // Case 2: Equal (2.5 == 2.5) -> Branch Not Taken (0)
      final codeEq = <int>[
        ...encodeOp(GlulxOpcodes.jfne),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f3 >> 24) & 0xFF,
        (f3 >> 16) & 0xFF,
        (f3 >> 8) & 0xFF,
        f3 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpEq = createInterpreter(codeEq);
      interpEq.run(maxSteps: 5000);
      expect(interpEq.memory.getUint32(100), equals(0));
    });

    test('jflt branches on less than', () {
      int f1 = floatToBits(2.0);
      int f2 = floatToBits(3.0);

      // 2.0 < 3.0 -> Taken
      final codeLt = <int>[
        ...encodeOp(GlulxOpcodes.jflt),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpLt = createInterpreter(codeLt);
      interpLt.run(maxSteps: 5000);
      expect(interpLt.memory.getUint32(100), equals(1));

      // 3.0 < 2.0 -> Not Taken
      final codeGt = <int>[
        ...encodeOp(GlulxOpcodes.jflt),
        0x33,
        0x01,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpGt = createInterpreter(codeGt);
      interpGt.run(maxSteps: 5000);
      expect(interpGt.memory.getUint32(100), equals(0));
    });

    // Skipping extensive tests for jfle, jfgt, jfge to avoid huge file,
    // assuming logic is similar. But I should add at least one simple check for each.

    test('jfle branches on less or equal', () {
      int f1 = floatToBits(2.0);
      int f2 = floatToBits(2.0);
      // 2.0 <= 2.0 -> Taken
      final codeLe = <int>[
        ...encodeOp(GlulxOpcodes.jfle),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpLe = createInterpreter(codeLe);
      interpLe.run(maxSteps: 5000);
      expect(interpLe.memory.getUint32(100), equals(1));
    });

    test('jfgt branches on greater than', () {
      int f1 = floatToBits(3.0);
      int f2 = floatToBits(2.0);
      // 3.0 > 2.0 -> Taken
      final codeGt = <int>[
        ...encodeOp(GlulxOpcodes.jfgt),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpGt = createInterpreter(codeGt);
      interpGt.run(maxSteps: 5000);
      expect(interpGt.memory.getUint32(100), equals(1));
    });

    test('jfge branches on greater or equal', () {
      int f1 = floatToBits(2.0);
      int f2 = floatToBits(2.0);
      // 2.0 >= 2.0 -> Taken
      final codeGe = <int>[
        ...encodeOp(GlulxOpcodes.jfge),
        0x33,
        0x01,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpGe = createInterpreter(codeGe);
      interpGe.run(maxSteps: 5000);
      expect(interpGe.memory.getUint32(100), equals(1));
    });

    test('jisnan branches on NaN', () {
      int f1 = floatToBits(double.nan);
      // NaN -> Taken
      final codeNan = <int>[
        ...encodeOp(GlulxOpcodes.jisnan),
        0x13, // L1=Const4 (float), L2=Const1 (Branch)
        (f1 >> 24) & 0xFF, (f1 >> 16) & 0xFF, (f1 >> 8) & 0xFF, f1 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 0, 0, 100, ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy), 0xD1, 1, 0, 100, ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpNan = createInterpreter(codeNan);
      interpNan.run(maxSteps: 5000);
      expect(interpNan.memory.getUint32(100), equals(1));

      // 1.0 -> Not Taken
      int f2 = floatToBits(1.0);
      final codeNum = <int>[
        ...encodeOp(GlulxOpcodes.jisnan),
        0x13,
        (f2 >> 24) & 0xFF,
        (f2 >> 16) & 0xFF,
        (f2 >> 8) & 0xFF,
        f2 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpNum = createInterpreter(codeNum);
      interpNum.run(maxSteps: 5000);
      expect(interpNum.memory.getUint32(100), equals(0));
    });

    test('jisinf branches on Infinity', () {
      int f1 = floatToBits(double.infinity);
      // Inf -> Taken
      final codeInf = <int>[
        ...encodeOp(GlulxOpcodes.jisinf),
        0x13,
        (f1 >> 24) & 0xFF,
        (f1 >> 16) & 0xFF,
        (f1 >> 8) & 0xFF,
        f1 & 0xFF,
        7,
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        0,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
        ...encodeOp(GlulxOpcodes.copy),
        0xD1,
        1,
        0,
        100,
        ...encodeOp(GlulxOpcodes.quit),
      ];
      final interpInf = createInterpreter(codeInf);
      interpInf.run(maxSteps: 5000);
      expect(interpInf.memory.getUint32(100), equals(1));
    });
  });
}
