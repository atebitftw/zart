import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/glulx/interpreter.dart';
import 'package:zart/src/glulx/glulx_accelerator.dart';

import 'test_terminal_display.dart';

void main() {
  late GlulxInterpreter interpreter;
  late GlulxAccelerator accelerator;

  setUp(() {
    final display = TestTerminalDisplay();
    final io = GlulxTerminalProvider(display);
    interpreter = GlulxInterpreter(io: io);
    accelerator = GlulxAccelerator(interpreter);

    // Initialize minimal memory
    // Header (36 bytes) + some RAM
    final bytes = Uint8List(0x1000);
    // Set Magic and Version
    bytes.buffer.asByteData().setUint32(0, 0x476C756C); // Magic
    bytes.buffer.asByteData().setUint32(4, 0x00030103); // Version
    bytes.buffer.asByteData().setUint32(8, 0x100); // RAM Start
    bytes.buffer.asByteData().setUint32(12, 0x500); // Ext Start
    bytes.buffer.asByteData().setUint32(16, 0x1000); // End Mem
    bytes.buffer.asByteData().setUint32(20, 0x1000); // Stack Size
    interpreter.load(bytes);
  });

  test('Z__Region identifies objects correctly', () {
    // RAM Start is 0x100.
    // Address 0x100: Type Byte 0x70 (Object).
    interpreter.memWrite8(0x100, 0x70);

    // Address 0x101: Type Byte 0x60 (Nothing/Dict?).
    interpreter.memWrite8(0x101, 0x60);

    // Address 0x102: Type Byte 0xC0 (String).
    interpreter.memWrite8(0x102, 0xC0);

    // Address 0x103: Type Byte 0xE0 (Routine).
    interpreter.memWrite8(0x103, 0xE0);

    // Act & Assert
    // Func 1: Z__Region
    expect(accelerator.execute(1, [0x100]), 1, reason: 'Object');
    expect(accelerator.execute(1, [0x101]), 0, reason: 'None');
    expect(accelerator.execute(1, [0x102]), 2, reason: 'String');
    expect(accelerator.execute(1, [0x103]), 3, reason: 'Routine');

    // ROM check (Address 20 < RAMStart)
    // Even if type byte is 0x70
    interpreter.memWrite8(20, 0x70);
    expect(
      accelerator.execute(1, [20]),
      0,
      reason: 'ROM address should return 0 for Object',
    );
  });

  test('CP__Tab finds property address', () {
    // Setup Object at 0x100
    interpreter.memWrite8(0x100, 0x70); // Object type

    // Setup Params
    // Param 7 (NUM_ATTR_BYTES) = 7 (Default)
    accelerator.setParam(7, 7);

    // CP_Tab offset calculation:
    // offset = 3 + (7 ~/ 4) = 3 + 1 = 4.
    // Address of Property Table Pointer = 0x100 + 4*4 = 0x110.

    // Write Property Table Pointer -> 0x200
    interpreter.memWrite32(0x110, 0x200);

    // Setup Property Table at 0x200
    // Header: Count = 2.
    interpreter.memWrite32(0x200, 2);

    // Entry 1 (0x204): ID 10, Addr 0x300. (Struct size 10)
    // Structure: ID (2 bytes), Addr (4 bytes?), Size (4 bytes?).
    // Spec: "Property table ... ordered by ID ...
    // Struct: [ID (2), Value (4), Method (4)]? No.
    // Spec says for BinarySearch:
    // StructSize is 10 bytes.
    // Layout found in "Objects" section of spec?
    // Actually, I6 veneer usually defines:
    //   word id; long prop_addr; long prop_len; ?
    //   2 + 4 + 4 = 10 bytes. Correct.

    // Entry 0 (0x204): ID 5.
    interpreter.memWrite16(0x204, 5);
    interpreter.memWrite32(0x206, 0xABC); // Val/Addr
    interpreter.memWrite32(0x20A, 4); // Len/Whatever

    // Entry 1 (0x20E): ID 10.
    interpreter.memWrite16(0x20E, 10);
    interpreter.memWrite32(
      0x210,
      0xDEF,
    ); // Val/Addr (This is what CP__Tab returns!)
    // Wait, CP__Tab returns "res".
    // binarysearch returns "address of the found structure" (by default)
    // OR result if "ReturnIndex" option? No options passed.
    // So CP__Tab returns 0x20E (Entry address).

    // Func 2 (CP__Tab) Call
    // Find ID 10.
    final res = accelerator.execute(2, [0x100, 10]);

    expect(
      res,
      0x20E,
      reason: 'Should return address of property entry for ID 10',
    );

    // Find ID 5.
    expect(accelerator.execute(2, [0x100, 5]), 0x204);

    // Find ID 99 (Missing).
    expect(accelerator.execute(2, [0x100, 99]), 0);
  });
}
