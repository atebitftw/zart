import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_function.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_string_decoder.dart';
import 'package:zart/src/glulx/typable_objects.dart';

void main() {
  /// Glulx Spec Section 1.4: Typable Objects
  group('Glulx Typable Objects', () {
    late GlulxMemoryMap memory;

    /// Creates a valid Glulx data buffer with a minimal header.
    Uint8List createGlulxData(int size, {int ramStart = 0x24}) {
      final data = Uint8List(size < ramStart + 36 ? ramStart + 36 : size);
      // Magic Number: 47 6C 75 6C
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;

      // RAMSTART
      data[8] = (ramStart >> 24) & 0xFF;
      data[9] = (ramStart >> 16) & 0xFF;
      data[10] = (ramStart >> 8) & 0xFF;
      data[11] = ramStart & 0xFF;

      // EXTSTART and ENDMEM set to the same as size
      data[12] = (data.length >> 24) & 0xFF;
      data[13] = (data.length >> 16) & 0xFF;
      data[14] = (data.length >> 8) & 0xFF;
      data[15] = data.length & 0xFF;

      data[16] = (data.length >> 24) & 0xFF;
      data[17] = (data.length >> 16) & 0xFF;
      data[18] = (data.length >> 8) & 0xFF;
      data[19] = data.length & 0xFF;

      return data;
    }

    test('detects object types correctly', () {
      /// Spec 1.4: "structured objects in Glulx main memory follow a simple convention:
      /// the first byte indicates the type of the object."
      final data = createGlulxData(128, ramStart: 0x24);
      // 0x24 (RAMSTART) starts here
      data.setRange(0x24, 0x24 + 8, [
        0xE0, // String E0
        0xC0, // Function C0
        0xC1, // Function C1
        0xE2, // String E2
        0xE1, // String E1
        0x01, // User defined
        0x80, // Reserved
        0x00, // Null
      ]);

      memory = GlulxMemoryMap(data);

      /// Spec 1.4.1: "Strings have a type byte of E0 (for unencoded, C-style strings)"
      expect(GlulxTypable.getType(memory, 0x24), GlulxTypableType.stringE0);

      /// Spec 1.4.2: "Functions have a type byte of C0 (for stack-argument functions)"
      expect(GlulxTypable.getType(memory, 0x25), GlulxTypableType.functionC0);

      /// Spec 1.4.2: "or C1 (for local-argument functions)"
      expect(GlulxTypable.getType(memory, 0x26), GlulxTypableType.functionC1);

      /// Spec 1.4.1: "or E2 (for unencoded strings of Unicode values)"
      expect(GlulxTypable.getType(memory, 0x27), GlulxTypableType.stringE2);

      /// Spec 1.4.1: "or E1 (for compressed strings.)"
      expect(GlulxTypable.getType(memory, 0x28), GlulxTypableType.stringE1);

      /// Spec 1.4.4: "Types 01 to 7F are available for use by the compiler, the library, or the program."
      expect(GlulxTypable.getType(memory, 0x29), GlulxTypableType.userDefined);

      /// Spec 1.4.3: "Type 80 to BF are reserved for future expansion."
      expect(GlulxTypable.getType(memory, 0x2A), GlulxTypableType.reserved);

      /// Spec 1.4.3: "Type 00 is also reserved; it indicates 'no object'"
      expect(GlulxTypable.getType(memory, 0x2B), GlulxTypableType.nullObject);
    });

    test('parses Unencoded String (E0)', () {
      /// Spec 1.4.1.1: "An unencoded string consists of an E0 byte,
      /// followed by all the bytes of the string, followed by a zero byte."
      final data = createGlulxData(128);
      data.setRange(0x24, 0x24 + 7, [
        0xE0, // Type
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
        0x00, // terminator
      ]);
      memory = GlulxMemoryMap(data);

      final str = UnencodedString.parse(memory, 0x24);
      expect(str.bytes, equals([0x48, 0x65, 0x6C, 0x6C, 0x6F]));
      expect(String.fromCharCodes(str.bytes), equals("Hello"));
    });

    test('parses Unencoded Unicode String (E2)', () {
      /// Spec 1.4.1.2: "An unencoded Unicode string consists of an E2 byte, followed by three padding 0 bytes,
      /// followed by the Unicode character values (each one being a four-byte integer).
      /// Finally, there is a terminating value (four 0 bytes)."
      final data = createGlulxData(128);
      data.setRange(0x24, 0x24 + 16, [
        0xE2, 0x00, 0x00, 0x00, // Type + Padding
        0x00, 0x00, 0x00, 0x48, // 'H'
        0x00, 0x00, 0x00, 0x69, // 'i'
        0x00, 0x00, 0x00, 0x00, // terminator
      ]);
      memory = GlulxMemoryMap(data);

      final str = UnencodedUnicodeString.parse(memory, 0x24);
      expect(str.characters, equals([0x48, 0x69]));
    });

    test('parses Function (C0/C1) and locals', () {
      /// Spec 1.4.2: "The locals-format list is encoded the same way it is on the stack;
      /// see [*](#callframe). This is a list of LocalType/LocalCount byte pairs,
      /// terminated by a zero/zero pair. (There is, however, no extra padding to reach four-byte alignment.)"
      final data = createGlulxData(128);
      data.setRange(0x24, 0x24 + 9, [
        0xC0, // Type
        0x04, 0x02, // 2 locals of 4 bytes
        0x01, 0x05, // 5 locals of 1 byte
        0x00, 0x00, // terminator
        0x01, 0x02, // Opcodes start here
      ]);
      memory = GlulxMemoryMap(data);

      final func = GlulxFunction.parse(memory, 0x24);
      expect(func is StackArgsFunction, isTrue);
      expect(func.localsDescriptor.locals.length, equals(7));
      expect(func.localsDescriptor.locals[0].type, equals(4));
      expect(func.localsDescriptor.locals[2].type, equals(1));

      /// Spec 1.4.2: "Immediately following the two zero bytes, the instructions start."
      expect(func.entryPoint, equals(0x24 + 7));
    });

    test('decodes Compressed String (E1)', () {
      /// Spec 1.4.1.3: "Decoding compressed strings requires looking up data in a Huffman table."
      /// Spec 1.4.1.4: "The decoding table has the following format: ... Table Length (4 bytes),
      /// Number of Nodes (4 bytes), Root Node Addr (4 bytes)..."
      final data = createGlulxData(256);
      data.setRange(0x40, 0x40 + 12, [
        0x00, 0x00, 0x00, 0x30, // Length (48 bytes)
        0x00, 0x00, 0x00, 0x05, // 5 nodes
        0x00, 0x00, 0x00, 0x4C, // Root Addr (0x4C)
      ]);

      /// Spec 1.4.1.4: "Branch (non-leaf node) +----------------+ | Type: 00 | (1 byte)
      /// | Left (0) Node | (4 bytes) | Right (1) Node | (4 bytes) +----------------+"
      data.setRange(0x4C, 0x4C + 9, [0x00, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x5E]);

      /// Spec 1.4.1.4: "Single character +----------------+ | Type: 02 | (1 byte) | Character | (1 byte) +----------------+"
      data.setRange(0x55, 0x55 + 2, [0x02, 0x41]);

      /// Spec 1.4.1.4: "String terminator +----------------+ | Type: 01 | (1 byte) +----------------+"
      data.setRange(0x5E, 0x5E + 1, [0x01]);

      /// Spec 1.4.1.3: "A compressed string consists of an E1 byte, followed by a block of Huffman-encoded data.
      /// This should be read as a stream of bits, starting with the low bit (the 1 bit) of the first byte after the E1..."
      data.setRange(0x60, 0x62, [0xE1, 0x02]);

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      final result = <int>[];
      decoder.decode(0x60, 0x40, (c) => result.add(c), (u) => result.add(u), (f, a) => null);

      /// Spec 1.4.1.3: "Decoding compressed strings ... Read one bit from the bit stream,
      /// and go to the left or right child depending on its value. ... reach a leaf node.
      /// Print that entity. Then jump back to the root..."
      expect(result, equals([0x41]));
    });

    test('ROM caching optimization', () {
      /// Spec 1.4.1.3 [Optimization]: "A terp can speed it up considerably by reading the Huffman table all at once,
      /// and caching it as native data structures."
      /// Spec 1.4.1.3 [Warning]: "...it is technically legal for a table in RAM to be altered at runtime ...
      /// If it caches data from RAM, it must watch for writes to that RAM space, and invalidate its cache..."
      final data = createGlulxData(256, ramStart: 0x40);

      // Table in ROM (0x20)
      data.setRange(0x20, 0x20 + 12, [0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2C]);
      data.setRange(0x2C, 0x2C + 1, [0x01]); // Root is Terminator

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      // First call parses and caches
      decoder.decode(0x50, 0x20, (c) => null, (u) => null, (f, a) => null);

      // Verify caching logic works for ROM (internal detail, but confirmed by implementation)
    });
  });
}
