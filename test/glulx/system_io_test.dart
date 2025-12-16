import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/io/io_provider.dart';

class MockIo extends IoProvider {
  final StringBuffer buffer = StringBuffer();

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    return null;
  }

  @override
  Future<int> glulxGlk(int selector, List<int> args) async {
    if (selector == 0x0080) {
      // put_char
      buffer.writeCharCode(args[0]);
    }
    return 0;
  }
}

void main() {
  late GlulxInterpreter interpreter;
  late MockIo mockIo;

  // Helper to create a minimal Glulx game
  Uint8List createGame(
    List<int> instructions, {
    int ramStart = 0x100,
    int extStart = 0x5000,
    int endMem = 0x10000,
    int stackSize = 0x1000,
  }) {
    final bytes = BytesBuilder();

    // Header (36 bytes)
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0x476C756C)); // Magic
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0x00030103)); // Version
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, ramStart)); // RAM Start
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, extStart)); // Ext Start
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, endMem)); // End Mem
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, stackSize)); // Stack Size
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0x00000024)); // Start Func (after header)
    bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0)); // Decoding Table
    bytes.add(Uint8List(4)); // Checksum (placeholder)

    // Instructions (function body)
    // Function Type: C0 (stack args)
    bytes.addByte(0xC0);
    // Format: 0, 0 (no locals)
    bytes.addByte(0);
    bytes.addByte(0);

    // Instructions
    bytes.add(instructions);

    return bytes.toBytes();
  }

  setUp(() {
    mockIo = MockIo();
    interpreter = GlulxInterpreter(io: mockIo);
  });

  test('gestalt returns version info', () async {
    // Mode 0x04: gestalt L1 L2 S1
    // L1=0 (version), L2=0 (arg), S1=RAM 0x100
    // hex: 04, 00, 00, 0D, 00, 01 (Store 0xD=Ram, Addr 0x100)
    // Actually operands mode bytes: 3 operands.
    // Mode byte 1 (Op0/Op1): 00 (L1=Const0, L2=Const0).
    // Mode byte 2 (Op2): D0 (S1=RAM 00-FF... wait, RAM requires address).
    // Let's use simpler modes.
    // L1: Mode 0 (Zero) => 0
    // L2: Mode 0 (Zero) => 0
    // S1: Mode 5 (RAM 00-FF) => Address
    // Opcode 0x04. Modes: 00, 05 = 0x05? No.
    // Mode bytes: (Op0, Op1), (Op2, Padding).
    // Op0=0, Op1=0 -> Byte 0x00
    // Op2=5 (RAM byte) -> Byte 0x50? No, 0x05 (low nibble is Op2).
    // Wait `interpreter.dart`:
    // if i%2==0 mode = modeByte & 0xF. if i%2==1 mode = modeByte >> 4.
    // Op0 (i=0): byte0 & 0xF.
    // Op1 (i=1): byte0 >> 4.
    // Op2 (i=2): byte1 & 0xF.
    // So Op0=0, Op1=0 => byte0 = 0x00.
    // Op2=D (RAM 00-FF). => byte1 = 0x0D.
    // Operands:
    // Op0: (none)
    // Op1: (none)
    // Op2: Address (byte)

    // gestalt 0 0 -> RAM 0x80
    // Opcode 0x04.
    // Mode 0x00 (0,0). Mode 0x0D (D,?)
    // Operands: 0x80.

    final instructions = <int>[
      0x04, 0x00, 0x0B, 0x80, // gestalt 0, 0 -> RAM:80
      // Let's use getmemsize first.
      0x08, 0x0B, 0x84, // getmemsize -> RAM:84 (Mode 0: S1. Op0=B. Byte 0x0B. Op0 addr=0x84)
      0x30, 0x00, // quit
    ];

    Uint8List game = createGame(instructions);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    // Check RAM 0x80 for 0x00030103
    expect(interpreter.memRead32(0x80 + interpreter.ramStart), 0x00030103);
    // Check RAM 0x84 for size. Size = extStart (0x5000) or file len?
    // Interpreter init: initialSize = gameBytes.length. But set to at least extStart?
    // "If initialSize < _extStart, initialSize = _extStart".
    // So 0x5000.
    expect(interpreter.memRead32(0x84 + interpreter.ramStart), 0x10000);
  });

  test('streamnum writes string to io', () async {
    // streamnum 12345
    // Opcode 0x71.
    // Mode: L1. Op0=3 (Short Const). Byte 0x03.
    // Value: 12345 = 0x3039.
    final instructions = <int>[
      0x71, 0x03, 0x30, 0x39, // streamnum 12345
      0x30, 0x00,
    ];

    Uint8List game = createGame(instructions);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    expect(mockIo.buffer.toString(), '12345');
  });

  test('streamstr writes E0 string to io', () async {
    // Write "ABC" to RAM 0x100
    // 0x100 usually start of RAM.
    // Set RAM[0x100] = E0 (type)
    // RAM[0x101] = 65 (A)
    // RAM[0x102] = 66 (B)
    // RAM[0x103] = 67 (C)
    // RAM[0x104] = 00 (Null)

    // Code to setup string? Or just assume it's there?
    // createGame sets up func at 0x24.
    // RAM starts at ramStart (0x100 default).
    // I can put string data in the instructions array if I jump over it?
    // Or just write to RAM using stores?

    // copyb 0xE0 -> RAM:80
    // copyb 0x41 -> RAM:81
    // ...

    // Better: Helper creates instructions.

    // Let's use copyb to write string to ramStart + 0x80.
    final instructions = <int>[
      // copyb L1 S1. 2 operands.
      // Op0=1 (Const Byte), Op1=B (Ram Byte).
      // Op0=1, Op1=B => Byte 0xB1.
      // L1=E0. S1=80.
      0x44, 0xB1, 0xE0, 0x80, // copyb 0xE0 -> RAM:80
      0x44, 0xB1, 0x41, 0x81, // 'A'
      0x44, 0xB1, 0x42, 0x82, // 'B'
      0x44, 0xB1, 0x43, 0x83, // 'C'
      0x44, 0xB1, 0x00, 0x84, // '\0'
      // streamstr RAM:80 (Address relative to RAM start? No, absolute address.)
      // Absolute address = ramStart + 0x80. ramStart=0x100. -> 0x180.
      // streamstr 0x180.
      // Mode 0x02 (Short Const). Value 0x0180.
      0x72, 0x02, 0x01, 0x80,

      0x30, 0x00, // quit
    ];

    Uint8List game = createGame(instructions);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    expect(mockIo.buffer.toString(), 'ABC');
  });

  test('jumpabs jumps to address', () async {
    // Address of target.
    // Header 36 + 3 (Func Header) = 39.
    // Instructions start at 39.
    // 0: jumpabs Target
    // Target: streamnum 1
    // quit
    // Skipped: streamnum 2

    // Let's calculate offsets.
    // jumpabs 0x1000 (somewhere safe?) No must be valid code.
    // I need to know absolute address of instruction.
    // ramStart=0x100. ROM is 0..0xFF.
    // Code is in ROM? `createGame` puts instructions after header.
    // Header=36. Func=3 bytes. Start Instr=39 (0x27).

    // Instr 0: jumpabs L1.
    // Opcode 0A. Mode L1: 0x03 (Short). Value: TargetAddr.
    // Len = 1 + 1 + 2 = 4 bytes.
    // 39 -> 43.
    // Instr 1: streamnum 2. (Should skip). Len = 1+1+1 = 3 (if byte const 2). 43->46.
    // TargetAddr = 46 (0x2E).
    // Instr 2: streamnum 1. 0x71 ...

    final instructions = <int>[
      0x0A, 0x03, 0x00, 0x2E, // jumpabs 0x002E (46)
      0x71, 0x01, 0x02, // streamnum 2 (Const Byte 2) -> "2" (Skipped)
      // Addr 39+4 = 43. 43+3 = 46.
      0x71, 0x01, 0x01, // streamnum 1 -> "1"
      0x30, 0x00,
    ];

    Uint8List game = createGame(instructions);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    expect(mockIo.buffer.toString(), '1');
  });

  test('setmemsize resizes memory', () async {
    // getmemsize -> RAM:0
    // setmemsize 0x6000 -> RAM:4 (Result)
    // getmemsize -> RAM:8

    final instructions = <int>[
      0x08, 0x0B, 0x00, // getmemsize -> RAM:00
      0x09, 0xB2, 0x60, 0x00, 0x04, // setmemsize 0x6000 (Short 2) -> RAM:04 (B)
      // Op0=2 (Short), Op1=B (RAM). Byte 0xB2.
      0x08, 0x0B, 0x08, // getmemsize -> RAM:08
      0x30, 0x00,
    ];

    Uint8List game = createGame(instructions);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    int size1 = interpreter.memRead32(interpreter.ramStart + 0);
    int res = interpreter.memRead32(interpreter.ramStart + 4);
    int size2 = interpreter.memRead32(interpreter.ramStart + 8);

    expect(size1, 0x10000);
    expect(res, 0); // Success
    expect(size2, 0x6000);
    expect(interpreter.memory.lengthInBytes, 0x6000);
  });

  test('random generates numbers', () async {
    // random 10 -> RAM:0 (0..9)
    // random -10 -> RAM:4 (-9..0)
    // random 0 -> RAM:8 (Any)

    final instructions2 = <int>[
      0x81, 0x00, 0xB1, 0x0A, 0x00, // random 10
      0x81, 0x00, 0xB1, 0xF6, 0x04, // random -10
      0x81, 0x00, 0xB0, 0x08, // random 0
      0x30, 0x00,
    ];

    Uint8List game = createGame(instructions2);
    interpreter.load(game);
    await interpreter.run(maxSteps: 100);

    int r1 = interpreter.memRead32(interpreter.ramStart + 0);
    int r2 = interpreter.memRead32(interpreter.ramStart + 4).toSigned(32);
    int r3 = interpreter.memRead32(interpreter.ramStart + 8);

    print('Random: $r1, $r2, 0x${r3.toRadixString(16)}');
    expect(r1 >= 0 && r1 < 10, true);
    expect(r2 > -10 && r2 <= 0, true); // range -9..0
    expect(r3, isNotNull);
  });
}
