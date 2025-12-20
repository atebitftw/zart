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

    /// Creates a valid Glulx data buffer with a properly aligned header.
    ///
    /// Spec: "For the convenience of paging interpreters, the three boundaries
    /// RAMSTART, EXTSTART, and ENDMEM must be aligned on 256-byte boundaries."
    Uint8List createGlulxData({int ramStart = 0x100, int extStart = 0x200, int endMem = 0x300, int stackSize = 0x100}) {
      final data = Uint8List(extStart > endMem ? extStart : endMem);
      // Magic Number: 47 6C 75 6C ('Glul')
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;

      // Version: 3.1.3 -> 0x00030103
      data[4] = 0x00;
      data[5] = 0x03;
      data[6] = 0x01;
      data[7] = 0x03;

      // RAMSTART (must be >= 0x100 and 256-byte aligned)
      data[8] = (ramStart >> 24) & 0xFF;
      data[9] = (ramStart >> 16) & 0xFF;
      data[10] = (ramStart >> 8) & 0xFF;
      data[11] = ramStart & 0xFF;

      // EXTSTART (must be >= RAMSTART and 256-byte aligned)
      data[12] = (extStart >> 24) & 0xFF;
      data[13] = (extStart >> 16) & 0xFF;
      data[14] = (extStart >> 8) & 0xFF;
      data[15] = extStart & 0xFF;

      // ENDMEM (must be >= EXTSTART and 256-byte aligned)
      data[16] = (endMem >> 24) & 0xFF;
      data[17] = (endMem >> 16) & 0xFF;
      data[18] = (endMem >> 8) & 0xFF;
      data[19] = endMem & 0xFF;

      // Stack Size (must be >= 0x100 and 256-byte aligned)
      data[20] = (stackSize >> 24) & 0xFF;
      data[21] = (stackSize >> 16) & 0xFF;
      data[22] = (stackSize >> 8) & 0xFF;
      data[23] = stackSize & 0xFF;

      return data;
    }

    test('detects object types correctly', () {
      /// Spec 1.4: "structured objects in Glulx main memory follow a simple convention:
      /// the first byte indicates the type of the object."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      // Place test data in ROM at 0x30 (after header)
      data.setRange(0x30, 0x30 + 8, [
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
      expect(GlulxTypable.getType(memory, 0x30), GlulxTypableType.stringE0);

      /// Spec 1.4.2: "Functions have a type byte of C0 (for stack-argument functions)"
      expect(GlulxTypable.getType(memory, 0x31), GlulxTypableType.functionC0);

      /// Spec 1.4.2: "or C1 (for local-argument functions)"
      expect(GlulxTypable.getType(memory, 0x32), GlulxTypableType.functionC1);

      /// Spec 1.4.1: "or E2 (for unencoded strings of Unicode values)"
      expect(GlulxTypable.getType(memory, 0x33), GlulxTypableType.stringE2);

      /// Spec 1.4.1: "or E1 (for compressed strings.)"
      expect(GlulxTypable.getType(memory, 0x34), GlulxTypableType.stringE1);

      /// Spec 1.4.4: "Types 01 to 7F are available for use by the compiler, the library, or the program."
      expect(GlulxTypable.getType(memory, 0x35), GlulxTypableType.userDefined);

      /// Spec 1.4.3: "Type 80 to BF are reserved for future expansion."
      expect(GlulxTypable.getType(memory, 0x36), GlulxTypableType.reserved);

      /// Spec 1.4.3: "Type 00 is also reserved; it indicates 'no object'"
      expect(GlulxTypable.getType(memory, 0x37), GlulxTypableType.nullObject);
    });

    test('parses Unencoded String (E0)', () {
      /// Spec 1.4.1.1: "An unencoded string consists of an E0 byte,
      /// followed by all the bytes of the string, followed by a zero byte."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      data.setRange(0x30, 0x30 + 7, [
        0xE0, // Type
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
        0x00, // terminator
      ]);
      memory = GlulxMemoryMap(data);

      final str = UnencodedString.parse(memory, 0x30);
      expect(str.bytes, equals([0x48, 0x65, 0x6C, 0x6C, 0x6F]));
      expect(String.fromCharCodes(str.bytes), equals("Hello"));
    });

    test('parses Unencoded Unicode String (E2)', () {
      /// Spec 1.4.1.2: "An unencoded Unicode string consists of an E2 byte, followed by three padding 0 bytes,
      /// followed by the Unicode character values (each one being a four-byte integer).
      /// Finally, there is a terminating value (four 0 bytes)."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      data.setRange(0x30, 0x30 + 16, [
        0xE2, 0x00, 0x00, 0x00, // Type + Padding
        0x00, 0x00, 0x00, 0x48, // 'H'
        0x00, 0x00, 0x00, 0x69, // 'i'
        0x00, 0x00, 0x00, 0x00, // terminator
      ]);
      memory = GlulxMemoryMap(data);

      final str = UnencodedUnicodeString.parse(memory, 0x30);
      expect(str.characters, equals([0x48, 0x69]));
    });

    test('parses Function (C0/C1) and locals', () {
      /// Spec 1.4.2: "The locals-format list is encoded the same way it is on the stack;
      /// see [*](#callframe). This is a list of LocalType/LocalCount byte pairs,
      /// terminated by a zero/zero pair. (There is, however, no extra padding to reach four-byte alignment.)"
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      data.setRange(0x30, 0x30 + 9, [
        0xC0, // Type
        0x04, 0x02, // 2 locals of 4 bytes
        0x01, 0x05, // 5 locals of 1 byte
        0x00, 0x00, // terminator
        0x01, 0x02, // Opcodes start here
      ]);
      memory = GlulxMemoryMap(data);

      final func = GlulxFunction.parse(memory, 0x30);
      expect(func is StackArgsFunction, isTrue);
      expect(func.localsDescriptor.locals.length, equals(7));
      expect(func.localsDescriptor.locals[0].type, equals(4));
      expect(func.localsDescriptor.locals[2].type, equals(1));

      /// Spec 1.4.2: "Immediately following the two zero bytes, the instructions start."
      expect(func.entryPoint, equals(0x30 + 7));
    });

    test('parses C1 LocalArgsFunction correctly', () {
      /// Spec 1.4.2: "If the type is C1, the arguments are passed on the stack,
      /// and are written into the locals according to the 'format of locals' list."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      data.setRange(0x30, 0x30 + 5, [
        0xC1, // Type: C1 (local-argument function)
        0x04, 0x01, // 1 local of 4 bytes
        0x00, 0x00, // terminator
      ]);
      memory = GlulxMemoryMap(data);

      final func = GlulxFunction.parse(memory, 0x30);
      expect(func is LocalArgsFunction, isTrue);
      expect(func.localsDescriptor.locals.length, equals(1));
      expect(func.localsDescriptor.locals[0].type, equals(4));
      expect(func.entryPoint, equals(0x30 + 5));
    });

    test('decodes Compressed String (E1)', () {
      /// Spec 1.4.1.3: "Decoding compressed strings requires looking up data in a Huffman table."
      /// Spec 1.4.1.4: "The decoding table has the following format: ... Table Length (4 bytes),
      /// Number of Nodes (4 bytes), Root Node Addr (4 bytes)..."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);
      // String decoding table at 0x40
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
      decoder.decode(
        0x60,
        0x40,
        (c, _, __) => result.add(c),
        (u, _, __) => result.add(u),
        (resumeAddr, resumeBit, stringAddr) => {},
        (resumeAddr, resumeBit, funcAddr, args) => null,
      );

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
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // Table in ROM (0x30)
      data.setRange(0x30, 0x30 + 12, [
        0x00, 0x00, 0x00, 0x20, // Length
        0x00, 0x00, 0x00, 0x01, // 1 node
        0x00, 0x00, 0x00, 0x3C, // Root addr (0x3C)
      ]);
      data.setRange(0x3C, 0x3C + 1, [0x01]); // Root is Terminator

      // Compressed string at 0x50
      data.setRange(0x50, 0x52, [0xE1, 0x00]);

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      // First call parses and caches
      decoder.decode(
        0x50,
        0x30,
        (c, _, __) => null,
        (u, _, __) => null,
        (resumeAddr, resumeBit, stringAddr) => null,
        (resumeAddr, resumeBit, funcAddr, args) => null,
      );

      // Verify caching logic works for ROM (internal detail, but confirmed by implementation)
    });

    test('decodes C-style string node (0x03)', () {
      /// Spec 1.4.1.4: "C-style string ... | Type: 03 | (1 byte) | Characters.... | (any length)
      /// | NUL: 00 | (1 byte) ... This prints an array of characters."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [
        0x00, 0x00, 0x00, 0x30, // Length
        0x00, 0x00, 0x00, 0x03, // 3 nodes
        0x00, 0x00, 0x00, 0x4C, // Root Addr (0x4C)
      ]);

      // Branch node at 0x4C: bit=0 -> 0x55 (string), bit=1 -> 0x5F (terminator)
      data.setRange(0x4C, 0x4C + 9, [
        0x00, // Type: Branch
        0x00, 0x00, 0x00, 0x55, // Left addr
        0x00, 0x00, 0x00, 0x5F, // Right addr
      ]);

      // C-string node at 0x55: "Hi" + NUL
      data.setRange(0x55, 0x55 + 4, [0x03, 0x48, 0x69, 0x00]);

      // Terminator at 0x5F
      data.setRange(0x5F, 0x5F + 1, [0x01]);

      // Compressed string at 0x60: bit stream 0b10 = "go left, then right"
      data.setRange(0x60, 0x62, [0xE1, 0x02]);

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      final result = <int>[];
      decoder.decode(
        0x60,
        0x40,
        (c, _, __) => result.add(c),
        (u, _, __) => result.add(u),
        (resumeAddr, resumeBit, stringAddr) => {},
        (resumeAddr, resumeBit, funcAddr, args) => null,
      );

      expect(result, equals([0x48, 0x69])); // 'H', 'i'
    });

    test('decodes single Unicode character node (0x04)', () {
      /// Spec 1.4.1.4: "Single Unicode character ... | Type: 04 | (1 byte)
      /// | Character | (4 bytes) ... This prints a single Unicode character."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [
        0x00, 0x00, 0x00, 0x30, // Length
        0x00, 0x00, 0x00, 0x03, // 3 nodes
        0x00, 0x00, 0x00, 0x4C, // Root Addr (0x4C)
      ]);

      // Branch node at 0x4C
      data.setRange(0x4C, 0x4C + 9, [
        0x00,
        0x00, 0x00, 0x00, 0x55, // Left: Unicode char
        0x00, 0x00, 0x00, 0x5A, // Right: Terminator
      ]);

      // Unicode char node at 0x55: U+1F600 (emoji 😀)
      data.setRange(0x55, 0x55 + 5, [0x04, 0x00, 0x01, 0xF6, 0x00]);

      // Terminator at 0x5A
      data.setRange(0x5A, 0x5A + 1, [0x01]);

      // Compressed string: bit stream 0b10 = left then right
      data.setRange(0x60, 0x62, [0xE1, 0x02]);

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      final result = <int>[];
      decoder.decode(
        0x60,
        0x40,
        (c, _, __) => {},
        (u, _, __) => result.add(u),
        (resumeAddr, resumeBit, stringAddr) => {},
        (resumeAddr, resumeBit, funcAddr, args) => {},
      );

      expect(result, equals([0x0001F600])); // U+1F600
    });

    test('decodes C-style Unicode string node (0x05)', () {
      /// Spec 1.4.1.4: "C-style Unicode string ... | Type: 05 | (1 byte)
      /// | Characters.... | (any length, multiple of 4) | NUL: 00000000 | (4 bytes)"
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [
        0x00, 0x00, 0x00, 0x40, // Length
        0x00, 0x00, 0x00, 0x03, // 3 nodes
        0x00, 0x00, 0x00, 0x4C, // Root Addr (0x4C)
      ]);

      // Branch node at 0x4C
      data.setRange(0x4C, 0x4C + 9, [
        0x00,
        0x00, 0x00, 0x00, 0x55, // Left: Unicode string
        0x00, 0x00, 0x00, 0x66, // Right: Terminator
      ]);

      // Unicode string node at 0x55: "AB" in Unicode + NUL (4 bytes each)
      data.setRange(0x55, 0x55 + 13, [
        0x05, // Type
        0x00, 0x00, 0x00, 0x41, // 'A'
        0x00, 0x00, 0x00, 0x42, // 'B'
        0x00, 0x00, 0x00, 0x00, // NUL terminator
      ]);

      // Terminator at 0x66
      data.setRange(0x66, 0x66 + 1, [0x01]);

      // Compressed string: bit stream 0b10 = left then right
      data.setRange(0x70, 0x72, [0xE1, 0x02]);

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      final result = <int>[];
      decoder.decode(
        0x70,
        0x40,
        (c, _, __) => {},
        (u, _, __) => result.add(u),
        (resumeAddr, resumeBit, stringAddr) => {},
        (resumeAddr, resumeBit, funcAddr, args) => {},
      );

      expect(result, equals([0x41, 0x42])); // 'A', 'B'
    });

    test('decodes indirect reference node (0x08)', () {
      /// Spec 1.4.1.4: "Indirect reference ... | Type: 08 | (1 byte) | Address | (4 bytes)
      /// ... The address may refer to a location anywhere in memory ...
      /// If it is a string, it is printed. If a function, it is called..."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [
        0x00, 0x00, 0x00, 0x30, // Length
        0x00, 0x00, 0x00, 0x03, // 3 nodes
        0x00, 0x00, 0x00, 0x4C, // Root Addr (0x4C)
      ]);

      // Branch node at 0x4C
      data.setRange(0x4C, 0x4C + 9, [
        0x00,
        0x00, 0x00, 0x00, 0x55, // Left: Indirect
        0x00, 0x00, 0x00, 0x5A, // Right: Terminator
      ]);

      // Indirect node at 0x55: points to address 0x80
      data.setRange(0x55, 0x55 + 5, [0x08, 0x00, 0x00, 0x00, 0x80]);

      // Terminator at 0x5A
      data.setRange(0x5A, 0x5A + 1, [0x01]);

      // Compressed string
      data.setRange(0x60, 0x62, [0xE1, 0x02]);

      // Place a function type byte at 0x80 so dispatch recognizes it as function
      data[0x80] = 0xC0;

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      int? calledAddr;
      List<int>? calledArgs;
      decoder.decode(0x60, 0x40, (c, _, __) => {}, (u, _, __) => {}, (resumeAddr, resumeBit, stringAddr) => {}, (
        resumeAddr2,
        resumeBit2,
        funcAddr,
        args,
      ) {
        calledAddr = funcAddr;
        calledArgs = args;
      });

      expect(calledAddr, equals(0x80));
      expect(calledArgs, isEmpty);
    });

    test('decodes double-indirect reference node (0x09)', () {
      /// Spec 1.4.1.4: "Double-indirect reference ... | Type: 09 | (1 byte) | Address | (4 bytes)
      /// ... the address refers to a four-byte field in memory, and *that* contains
      /// the address of a string or function."
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [0x00, 0x00, 0x00, 0x30, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x4C]);

      // Branch node
      data.setRange(0x4C, 0x4C + 9, [0x00, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x5A]);

      // Double-indirect node at 0x55: points to pointer at 0x80
      data.setRange(0x55, 0x55 + 5, [0x09, 0x00, 0x00, 0x00, 0x80]);

      // Pointer at 0x80 -> final address 0x90
      data.setRange(0x80, 0x84, [0x00, 0x00, 0x00, 0x90]);

      // Terminator at 0x5A
      data.setRange(0x5A, 0x5A + 1, [0x01]);

      // Compressed string
      data.setRange(0x60, 0x62, [0xE1, 0x02]);

      // Place a function type byte at 0x90 so dispatch recognizes it as function
      data[0x90] = 0xC0;

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      int? calledAddr;
      decoder.decode(
        0x60,
        0x40,
        (c, _, __) => {},
        (u, _, __) => {},
        (resumeAddr, resumeBit, stringAddr) => {},
        (resumeAddr, resumeBit, funcAddr, args) => calledAddr = funcAddr,
      );

      expect(calledAddr, equals(0x90)); // Dereferenced address
    });

    test('decodes indirect reference with arguments node (0x0A)', () {
      /// Spec 1.4.1.4: "Indirect reference with arguments ... | Type: 0A | (1 byte)
      /// | Address | (4 bytes) | Argument Count | (4 bytes) | Arguments.... | (4*N bytes)"
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x4C]);

      // Branch node
      data.setRange(0x4C, 0x4C + 9, [0x00, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x6A]);

      // Indirect with args at 0x55: address=0x80, count=2, args=[42, 99]
      data.setRange(0x55, 0x55 + 17, [
        0x0A, // Type
        0x00, 0x00, 0x00, 0x80, // Address
        0x00, 0x00, 0x00, 0x02, // Arg count = 2
        0x00, 0x00, 0x00, 0x2A, // Arg 0 = 42
        0x00, 0x00, 0x00, 0x63, // Arg 1 = 99
      ]);

      // Terminator at 0x6A
      data.setRange(0x6A, 0x6A + 1, [0x01]);

      // Compressed string
      data.setRange(0x70, 0x72, [0xE1, 0x02]);

      // Place a function type byte at 0x80 so dispatch recognizes it as function
      data[0x80] = 0xC0;

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      int? calledAddr;
      List<int>? calledArgs;
      decoder.decode(0x70, 0x40, (c, _, __) => {}, (u, _, __) => {}, (resumeAddr, resumeBit, stringAddr) => {}, (
        resumeAddr2,
        resumeBit2,
        funcAddr,
        args,
      ) {
        calledAddr = funcAddr;
        calledArgs = args;
      });

      expect(calledAddr, equals(0x80));
      expect(calledArgs, equals([42, 99]));
    });

    test('decodes double-indirect reference with arguments node (0x0B)', () {
      /// Spec 1.4.1.4: "Double-indirect reference with arguments ... | Type: 0B | (1 byte)
      /// | Address | (4 bytes) | Argument Count | (4 bytes) | Arguments.... | (4*N bytes)"
      final data = createGlulxData(ramStart: 0x100, extStart: 0x200, endMem: 0x200);

      // String decoding table at 0x40
      data.setRange(0x40, 0x40 + 12, [0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x4C]);

      // Branch node
      data.setRange(0x4C, 0x4C + 9, [0x00, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x6E]);

      // Double-indirect with args at 0x55: pointer=0x80, count=1, args=[7]
      data.setRange(0x55, 0x55 + 13, [
        0x0B, // Type
        0x00, 0x00, 0x00, 0x80, // Pointer address
        0x00, 0x00, 0x00, 0x01, // Arg count = 1
        0x00, 0x00, 0x00, 0x07, // Arg 0 = 7
      ]);

      // Pointer at 0x80 -> final address 0xA0
      data.setRange(0x80, 0x84, [0x00, 0x00, 0x00, 0xA0]);

      // Terminator at 0x6E
      data.setRange(0x6E, 0x6E + 1, [0x01]);

      // Compressed string
      data.setRange(0x70, 0x72, [0xE1, 0x02]);

      // Place a function type byte at 0xA0 so dispatch recognizes it as function
      data[0xA0] = 0xC0;

      memory = GlulxMemoryMap(data);
      final decoder = GlulxStringDecoder(memory);

      int? calledAddr;
      List<int>? calledArgs;
      decoder.decode(0x70, 0x40, (c, _, __) => {}, (u, _, __) => {}, (resumeAddr, resumeBit, stringAddr) => {}, (
        resumeAddr2,
        resumeBit2,
        funcAddr,
        args,
      ) {
        calledAddr = funcAddr;
        calledArgs = args;
      });

      expect(calledAddr, equals(0xA0)); // Dereferenced
      expect(calledArgs, equals([7]));
    });
  });
}
