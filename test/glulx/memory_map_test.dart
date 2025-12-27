import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'glulx_test_utils.dart';

/// Creates a minimal valid Glulx header for testing.
///
/// Spec: "The header is the first 36 bytes of memory."
/// Header layout:
///   bytes 0-3: Magic Number (0x476C756C = 'Glul')
///   bytes 4-7: Glulx Version
///   bytes 8-11: RAMSTART
///   bytes 12-15: EXTSTART
///   bytes 16-19: ENDMEM
///   bytes 20-23: Stack Size
///   bytes 24-27: Start Func
///   bytes 28-31: Decoding Tbl
///   bytes 32-35: Checksum
Uint8List createTestHeader({
  int ramStart = 0x100,
  int extStart = 0x200,
  int endMem = 0x300,
  int stackSize = 0x100,
  int version = 0x00030102,
  bool invalidMagic = false,
}) {
  final data = Uint8List(endMem);

  // Magic number: 'Glul' (47 6C 75 6C)
  if (invalidMagic) {
    data[0] = 0x00;
    data[1] = 0x00;
    data[2] = 0x00;
    data[3] = 0x00;
  } else {
    data[0] = 0x47;
    data[1] = 0x6C;
    data[2] = 0x75;
    data[3] = 0x6C;
  }

  // Version (big-endian)
  data[4] = (version >> 24) & 0xFF;
  data[5] = (version >> 16) & 0xFF;
  data[6] = (version >> 8) & 0xFF;
  data[7] = version & 0xFF;

  // RAMSTART (big-endian)
  data[8] = (ramStart >> 24) & 0xFF;
  data[9] = (ramStart >> 16) & 0xFF;
  data[10] = (ramStart >> 8) & 0xFF;
  data[11] = ramStart & 0xFF;

  // EXTSTART (big-endian)
  data[12] = (extStart >> 24) & 0xFF;
  data[13] = (extStart >> 16) & 0xFF;
  data[14] = (extStart >> 8) & 0xFF;
  data[15] = extStart & 0xFF;

  // ENDMEM (big-endian)
  data[16] = (endMem >> 24) & 0xFF;
  data[17] = (endMem >> 16) & 0xFF;
  data[18] = (endMem >> 8) & 0xFF;
  data[19] = endMem & 0xFF;

  // Stack Size (big-endian)
  data[20] = (stackSize >> 24) & 0xFF;
  data[21] = (stackSize >> 16) & 0xFF;
  data[22] = (stackSize >> 8) & 0xFF;
  data[23] = stackSize & 0xFF;

  // Start Func, Decoding Tbl, Checksum - leave as 0 for tests

  return data;
}

void main() {
  group('GlulxMemoryMap - Header Validation', () {
    // ==========================================================================
    // Spec: "The header is the first 36 bytes of memory."
    // ==========================================================================

    test('should throw if game data is shorter than 36 bytes', () {
      // Spec: "The header is the first 36 bytes of memory."
      final shortData = Uint8List(35);
      expect(() => GlulxMemoryMap(shortData), throwsA(isA<GlulxException>()));
    });

    test('should throw if magic number is invalid', () {
      // Spec: "Magic number: 47 6C 75 6C, which is to say the ASCII string 'Glul'."
      final invalidData = createTestHeader(invalidMagic: true);
      expect(() => GlulxMemoryMap(invalidData), throwsA(isA<GlulxException>()));
    });

    test('should accept valid magic number', () {
      // Spec: "Magic number: 47 6C 75 6C, which is to say the ASCII string 'Glul'."
      final validData = createTestHeader();
      expect(() => GlulxMemoryMap(validData), returnsNormally);
    });
  });

  group('GlulxMemoryMap - 256-Byte Alignment Validation', () {
    // ==========================================================================
    // Spec: "For the convenience of paging interpreters, the three boundaries
    // RAMSTART, EXTSTART, and ENDMEM must be aligned on 256-byte boundaries."
    // ==========================================================================

    test('should throw if RAMSTART is not 256-byte aligned', () {
      // Spec: "RAMSTART... must be aligned on 256-byte boundaries."
      final data = createTestHeader(
        ramStart: 0x101, // Not aligned
        extStart: 0x200,
        endMem: 0x300,
      );
      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if EXTSTART is not 256-byte aligned', () {
      // Spec: "EXTSTART... must be aligned on 256-byte boundaries."
      final data = createTestHeader(
        ramStart: 0x100,
        extStart: 0x201, // Not aligned
        endMem: 0x300,
      );
      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if ENDMEM is not 256-byte aligned', () {
      // Spec: "ENDMEM... must be aligned on 256-byte boundaries."
      final data = createTestHeader(
        ramStart: 0x100,
        extStart: 0x200,
        endMem: 0x301, // Not aligned
      );
      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if stack size is not 256-byte aligned', () {
      // Reference interpreter validates stack size alignment
      final data = createTestHeader(
        stackSize: 0x101, // Not aligned
      );
      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should accept properly aligned boundaries', () {
      // Spec: All boundaries must be 256-byte aligned
      final validData = createTestHeader(
        ramStart: 0x100,
        extStart: 0x200,
        endMem: 0x300,
        stackSize: 0x100,
      );
      expect(() => GlulxMemoryMap(validData), returnsNormally);
    });
  });

  group('GlulxMemoryMap - Segment Ordering Validation', () {
    // ==========================================================================
    // Spec: "ROM must be at least 256 bytes long (so that the header fits in it)."
    // Spec: Segments must be in order: 0 < RAMSTART <= EXTSTART <= ENDMEM
    // ==========================================================================

    test('should throw if RAMSTART is less than 0x100', () {
      // Spec: "ROM must be at least 256 bytes long (so that the header fits in it)."
      // This means RAMSTART must be >= 0x100.
      // We can't create this via createTestHeader easily, so create manually
      final data = Uint8List(0x200);
      // Magic
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;
      // Version
      data[4] = 0x00;
      data[5] = 0x03;
      data[6] = 0x01;
      data[7] = 0x02;
      // RAMSTART = 0x80 (too small, but 256-byte aligned... actually 0x80 is not)
      // Let's use 0x00 which is aligned but too small
      data[8] = 0x00;
      data[9] = 0x00;
      data[10] = 0x00;
      data[11] = 0x00; // RAMSTART = 0
      // EXTSTART
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x01;
      data[15] = 0x00;
      // ENDMEM
      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x02;
      data[19] = 0x00;
      // Stack size
      data[20] = 0x00;
      data[21] = 0x00;
      data[22] = 0x01;
      data[23] = 0x00;

      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if EXTSTART is less than RAMSTART', () {
      // Spec: Segments have logical ordering - EXTSTART must be >= RAMSTART
      final data = Uint8List(0x300);
      // Magic
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;
      // Version
      data[4] = 0x00;
      data[5] = 0x03;
      data[6] = 0x01;
      data[7] = 0x02;
      // RAMSTART = 0x200
      data[8] = 0x00;
      data[9] = 0x00;
      data[10] = 0x02;
      data[11] = 0x00;
      // EXTSTART = 0x100 (less than RAMSTART!)
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x01;
      data[15] = 0x00;
      // ENDMEM = 0x300
      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x03;
      data[19] = 0x00;
      // Stack size = 0x100
      data[20] = 0x00;
      data[21] = 0x00;
      data[22] = 0x01;
      data[23] = 0x00;

      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if ENDMEM is less than EXTSTART', () {
      // Spec: Segments have logical ordering - ENDMEM must be >= EXTSTART
      final data = Uint8List(0x300);
      // Magic
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;
      // Version
      data[4] = 0x00;
      data[5] = 0x03;
      data[6] = 0x01;
      data[7] = 0x02;
      // RAMSTART = 0x100
      data[8] = 0x00;
      data[9] = 0x00;
      data[10] = 0x01;
      data[11] = 0x00;
      // EXTSTART = 0x300
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x03;
      data[15] = 0x00;
      // ENDMEM = 0x200 (less than EXTSTART!)
      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x02;
      data[19] = 0x00;
      // Stack size = 0x100
      data[20] = 0x00;
      data[21] = 0x00;
      data[22] = 0x01;
      data[23] = 0x00;

      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });

    test('should throw if stack size is too small', () {
      // Reference interpreter: "if (stacksize < 0x100) fatal_error(...)"
      final data = Uint8List(0x300);
      // Magic
      data[0] = 0x47;
      data[1] = 0x6C;
      data[2] = 0x75;
      data[3] = 0x6C;
      // Version
      data[4] = 0x00;
      data[5] = 0x03;
      data[6] = 0x01;
      data[7] = 0x02;
      // RAMSTART = 0x100
      data[8] = 0x00;
      data[9] = 0x00;
      data[10] = 0x01;
      data[11] = 0x00;
      // EXTSTART = 0x200
      data[12] = 0x00;
      data[13] = 0x00;
      data[14] = 0x02;
      data[15] = 0x00;
      // ENDMEM = 0x300
      data[16] = 0x00;
      data[17] = 0x00;
      data[18] = 0x03;
      data[19] = 0x00;
      // Stack size = 0x00 (too small!)
      data[20] = 0x00;
      data[21] = 0x00;
      data[22] = 0x00;
      data[23] = 0x00;

      expect(() => GlulxMemoryMap(data), throwsA(isA<GlulxException>()));
    });
  });

  group('GlulxMemoryMap - Memory Read Operations', () {
    // ==========================================================================
    // Spec: "Main memory is a simple array of bytes, numbered from zero up."
    // Spec: "When accessing multibyte values, the most significant byte is
    //        stored first (big-endian)."
    // ==========================================================================

    late GlulxMemoryMap mem;

    setUp(() {
      final data = createTestHeader();
      // Write some test data at known locations
      data[0x50] = 0xAB;
      data[0x51] = 0xCD;
      data[0x52] = 0xEF;
      data[0x53] = 0x12;
      mem = GlulxMemoryMap(data);
    });

    test('should read bytes correctly', () {
      // Spec: "Main memory is a simple array of bytes, numbered from zero up."
      expect(mem.readByte(0x50), 0xAB);
      expect(mem.readByte(0x51), 0xCD);
      expect(mem.readByte(0x52), 0xEF);
      expect(mem.readByte(0x53), 0x12);
    });

    test('should read shorts in big-endian', () {
      // Spec: "When accessing multibyte values, the most significant byte is stored first (big-endian)."
      expect(mem.readShort(0x50), 0xABCD);
      expect(mem.readShort(0x52), 0xEF12);
    });

    test('should read words in big-endian', () {
      // Spec: "When accessing multibyte values, the most significant byte is stored first (big-endian)."
      expect(mem.readWord(0x50), 0xABCDEF12);
    });

    test('should throw on read beyond memory bounds (byte)', () {
      expect(() => mem.readByte(mem.endMem), throwsA(isA<GlulxException>()));
    });

    test('should throw on read beyond memory bounds (short)', () {
      expect(
        () => mem.readShort(mem.endMem - 1),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on read beyond memory bounds (word)', () {
      expect(
        () => mem.readWord(mem.endMem - 3),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on negative read address', () {
      expect(() => mem.readByte(-1), throwsA(isA<GlulxException>()));
    });
  });

  group('GlulxMemoryMap - Memory Write Operations', () {
    // ==========================================================================
    // Spec: "RAMSTART: The first address which the program can write to."
    // Spec: "the section marked ROM never changes during execution; it is illegal to write there."
    // ==========================================================================

    late GlulxMemoryMap mem;

    setUp(() {
      mem = GlulxMemoryMap(createTestHeader());
    });

    test('should write bytes to RAM correctly', () {
      // Spec: "RAMSTART: The first address which the program can write to."
      mem.writeByte(mem.ramStart, 0xFF);
      expect(mem.readByte(mem.ramStart), 0xFF);
    });

    test('should write shorts to RAM in big-endian', () {
      // Spec: "Multibyte values are stored big-endian."
      mem.writeShort(mem.ramStart, 0x1234);
      expect(mem.readByte(mem.ramStart), 0x12);
      expect(mem.readByte(mem.ramStart + 1), 0x34);
      expect(mem.readShort(mem.ramStart), 0x1234);
    });

    test('should write words to RAM in big-endian', () {
      // Spec: "Multibyte values are stored big-endian."
      mem.writeWord(mem.ramStart, 0xDEADBEEF);
      expect(mem.readByte(mem.ramStart), 0xDE);
      expect(mem.readByte(mem.ramStart + 1), 0xAD);
      expect(mem.readByte(mem.ramStart + 2), 0xBE);
      expect(mem.readByte(mem.ramStart + 3), 0xEF);
      expect(mem.readWord(mem.ramStart), 0xDEADBEEF);
    });

    test('should truncate values to appropriate size', () {
      mem.writeByte(mem.ramStart, 0x1FF); // Only lower 8 bits
      expect(mem.readByte(mem.ramStart), 0xFF);

      mem.writeShort(mem.ramStart, 0x1FFFF); // Only lower 16 bits
      expect(mem.readShort(mem.ramStart), 0xFFFF);
    });

    test('should throw on write to ROM (byte)', () {
      // Spec: "the section marked ROM never changes during execution; it is illegal to write there."
      expect(() => mem.writeByte(0, 0x00), throwsA(isA<GlulxException>()));
      expect(
        () => mem.writeByte(mem.ramStart - 1, 0x00),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on write to ROM (short)', () {
      // Spec: "it is illegal to write there."
      expect(
        () => mem.writeShort(mem.ramStart - 2, 0x0000),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on write to ROM (word)', () {
      // Spec: "it is illegal to write there."
      expect(
        () => mem.writeWord(0, 0x00000000),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on write beyond memory bounds (byte)', () {
      expect(
        () => mem.writeByte(mem.endMem, 0x00),
        throwsA(isA<GlulxException>()),
      );
    });

    test(
      'should throw on write beyond memory bounds (short ending past endMem)',
      () {
        expect(
          () => mem.writeShort(mem.endMem - 1, 0x0000),
          throwsA(isA<GlulxException>()),
        );
      },
    );

    test(
      'should throw on write beyond memory bounds (word ending past endMem)',
      () {
        expect(
          () => mem.writeWord(mem.endMem - 3, 0x00000000),
          throwsA(isA<GlulxException>()),
        );
      },
    );
  });

  group('GlulxMemoryMap - Dynamic Memory Resizing (setmemsize)', () {
    // ==========================================================================
    // Spec: "Store the current size of the memory map. This is originally the
    //        ENDMEM value from the header, but you can change it with the
    //        setmemsize opcode."
    //
    // Spec: "It will always be greater than or equal to ENDMEM, and will
    //        always be a multiple of 256."
    //
    // Spec: "When the memory size grows, the new space is filled with zeroes.
    //        When it shrinks, the contents of the old space are lost."
    // ==========================================================================

    late GlulxMemoryMap mem;
    late int originalEndMem;

    setUp(() {
      mem = GlulxMemoryMap(createTestHeader());
      originalEndMem = mem.endMem;
    });

    test('should return original ENDMEM initially', () {
      // Spec: "This is originally the ENDMEM value from the header"
      expect(mem.endMem, originalEndMem);
      expect(mem.origEndMem, originalEndMem);
    });

    test('should grow memory successfully', () {
      // Spec: "you can change it with the setmemsize opcode"
      final newSize = originalEndMem + 0x100;
      final result = mem.setMemorySize(newSize);
      expect(result, 0); // Success
      expect(mem.endMem, newSize);
    });

    test('should fill new space with zeroes when growing', () {
      // Spec: "When the memory size grows, the new space is filled with zeroes."
      final newSize = originalEndMem + 0x100;
      mem.setMemorySize(newSize);

      // Check that new space is zero
      for (int i = originalEndMem; i < newSize; i++) {
        expect(mem.readByte(i), 0);
      }
    });

    test('should allow writing to grown memory', () {
      final newSize = originalEndMem + 0x100;
      mem.setMemorySize(newSize);

      // Should be able to write to new area
      mem.writeByte(originalEndMem, 0xFF);
      expect(mem.readByte(originalEndMem), 0xFF);
    });

    test('should shrink memory successfully', () {
      // First grow, then shrink back
      mem.setMemorySize(originalEndMem + 0x200);
      final result = mem.setMemorySize(originalEndMem + 0x100);
      expect(result, 0); // Success
      expect(mem.endMem, originalEndMem + 0x100);
    });

    test('should fail to shrink below original ENDMEM', () {
      // Spec: Cannot resize smaller than original
      final result = mem.setMemorySize(originalEndMem - 0x100);
      expect(result, 1); // Failure
      expect(mem.endMem, originalEndMem); // Unchanged
    });

    test('should fail if new size is not 256-byte aligned', () {
      // Spec: "will always be a multiple of 256"
      final result = mem.setMemorySize(originalEndMem + 0x50);
      expect(result, 1); // Failure
      expect(mem.endMem, originalEndMem); // Unchanged
    });

    test('should return 0 if new size equals current size', () {
      final result = mem.setMemorySize(originalEndMem);
      expect(result, 0); // Success (no-op)
    });
  });

  group('GlulxMemoryMap - Memory Protection (protect opcode)', () {
    // ==========================================================================
    // Spec: "Protect a range of memory from restart, restore, restoreundo.
    //        The protected range starts at address L1 and has a length of L2 bytes.
    //        This memory is silently unaffected by the state-restoring operations."
    //
    // Spec: "Only one range can be protected at a time. Calling protect cancels
    //        any previous range. To turn off protection, call protect with
    //        L1 and L2 set to zero."
    // ==========================================================================

    late GlulxMemoryMap mem;

    setUp(() {
      mem = GlulxMemoryMap(createTestHeader());
    });

    test('should have no protection range initially', () {
      // Spec: "When the VM starts up, there is no protection range."
      final (start, end) = mem.protectionRange;
      expect(start, 0);
      expect(end, 0);
    });

    test('should set protection range correctly', () {
      // Spec: "The protected range starts at address L1 and has a length of L2 bytes."
      mem.setProtection(0x100, 0x50);
      final (start, end) = mem.protectionRange;
      expect(start, 0x100);
      expect(end, 0x150);
    });

    test('should report addresses within range as protected', () {
      mem.setProtection(0x100, 0x50);
      expect(mem.isProtected(0x100), true);
      expect(mem.isProtected(0x120), true);
      expect(mem.isProtected(0x14F), true);
    });

    test('should report addresses outside range as not protected', () {
      mem.setProtection(0x100, 0x50);
      expect(mem.isProtected(0x0FF), false);
      expect(mem.isProtected(0x150), false);
      expect(mem.isProtected(0x200), false);
    });

    test('should replace previous protection range', () {
      // Spec: "Only one range can be protected at a time. Calling protect cancels any previous range."
      mem.setProtection(0x100, 0x50);
      mem.setProtection(0x200, 0x30);

      final (start, end) = mem.protectionRange;
      expect(start, 0x200);
      expect(end, 0x230);

      // Old range should no longer be protected
      expect(mem.isProtected(0x100), false);
    });

    test('should clear protection when called with zero', () {
      // Spec: "To turn off protection, call protect with L1 and L2 set to zero."
      mem.setProtection(0x100, 0x50);
      mem.setProtection(0, 0);

      final (start, end) = mem.protectionRange;
      expect(start, 0);
      expect(end, 0);
      expect(mem.isProtected(0x100), false);
    });

    test('should preserve protected memory during restoreMemory', () {
      // Spec: "This memory is silently unaffected by the state-restoring operations."

      // Write initial values
      mem.writeByte(mem.ramStart, 0xAA);
      mem.writeByte(mem.ramStart + 1, 0xBB);
      mem.writeByte(mem.ramStart + 2, 0xCC);

      // Protect the middle byte
      mem.setProtection(mem.ramStart + 1, 1);

      // Create "saved" state with RAM data XOR'd against original
      final ramStart = mem.ramStart;
      final ramLength = mem.size - ramStart;
      final savedRam = Uint8List(ramLength);

      // XOR the target values with original bytes
      savedRam[0] = 0x11 ^ mem.readOriginalByte(ramStart);
      savedRam[1] = 0x22 ^ mem.readOriginalByte(ramStart + 1); // Protected
      savedRam[2] = 0x33 ^ mem.readOriginalByte(ramStart + 2);

      // Restore
      mem.restoreMemory(savedRam, mem.endMem, []);

      // Check results
      expect(mem.readByte(ramStart), 0x11); // Restored
      expect(mem.readByte(ramStart + 1), 0xBB); // Protected, NOT restored
      expect(mem.readByte(ramStart + 2), 0x33); // Restored
    });
  });

  group('GlulxMemoryMap - Heap Management', () {
    // ==========================================================================
    // Spec: "When you first allocate a block of memory, the heap becomes active.
    //        The current end of memory – that is, the current getmemsize value –
    //        becomes the beginning address of the heap."
    //
    // Spec: "If the allocation heap is active you may not use setmemsize –
    //        the memory map is under the control of the heap system."
    //
    // Spec: "When you free the last extant memory block, the heap becomes inactive.
    //        The interpreter will reduce the memory map size down to the
    //        heap-start address."
    // ==========================================================================

    late GlulxMemoryMap mem;

    setUp(() {
      mem = GlulxMemoryMap(createTestHeader());
    });

    test('should have inactive heap initially', () {
      expect(mem.heapIsActive, false);
      expect(mem.heapStart, 0);
    });

    test('should activate heap correctly', () {
      // Spec: "The current end of memory... becomes the beginning address of the heap."
      final originalEndMem = mem.endMem;
      mem.activateHeap();

      expect(mem.heapIsActive, true);
      expect(mem.heapStart, originalEndMem);
    });

    test('should not change heapStart if heap is already active', () {
      final originalEndMem = mem.endMem;
      mem.activateHeap();

      // Grow memory
      mem.setMemorySize(originalEndMem + 0x100, internal: true);

      // Activate again - should not change heap start
      mem.activateHeap();
      expect(mem.heapStart, originalEndMem);
    });

    test('should prevent setmemsize when heap is active', () {
      // Spec: "If the allocation heap is active you may not use setmemsize"
      mem.activateHeap();

      final result = mem.setMemorySize(mem.endMem + 0x100);
      expect(result, 1); // Failure
    });

    test('should allow internal setmemsize when heap is active', () {
      // Internal flag allows heap system to resize memory
      mem.activateHeap();

      final result = mem.setMemorySize(mem.endMem + 0x100, internal: true);
      expect(result, 0); // Success
    });

    test('should deactivate heap and shrink memory', () {
      // Spec: "When you free the last extant memory block, the heap becomes inactive.
      //        The interpreter will reduce the memory map size down to the heap-start address."
      final originalEndMem = mem.endMem;
      mem.activateHeap();

      // Grow memory (simulating heap allocation)
      mem.setMemorySize(originalEndMem + 0x200, internal: true);
      expect(mem.endMem, originalEndMem + 0x200);

      // Deactivate heap
      mem.deactivateHeap();

      expect(mem.heapIsActive, false);
      expect(mem.heapStart, 0);
      expect(mem.endMem, originalEndMem);
    });

    test('should allow setmemsize after heap deactivation', () {
      // Spec: "If you free all heap objects, the heap will then no longer be active,
      //        and you can use setmemsize."
      mem.activateHeap();
      mem.deactivateHeap();

      final result = mem.setMemorySize(mem.endMem + 0x100);
      expect(result, 0); // Success
    });
  });

  group('GlulxMemoryMap - Real Game File (monkey.gblorb)', () {
    // ==========================================================================
    // Tests using actual game file to verify real-world behavior
    // ==========================================================================

    late Uint8List storyData;

    setUp(() {
      storyData = GlulxTestUtils.loadTestGame('assets/games/monkey.gblorb');
    });

    test('should initialize and read header correctly from real game', () {
      // Spec: "The header is the first 36 bytes of memory."
      final mem = GlulxMemoryMap(storyData);

      // Values for monkey.gblorb
      expect(mem.ramStart, 3573504); // 0x368600
      expect(mem.extStart, 7905536); // 0x78A100
      expect(mem.endMem, 7905536); // 0x78A100
      expect(mem.origEndMem, 7905536);
    });

    test('should read magic number from real game', () {
      // Spec: "Magic number: 47 6C 75 6C, which is to say the ASCII string 'Glul'."
      final mem = GlulxMemoryMap(storyData);
      expect(mem.readByte(0), 0x47); // 'G'
      expect(mem.readByte(1), 0x6C); // 'l'
      expect(mem.readByte(2), 0x75); // 'u'
      expect(mem.readByte(3), 0x6C); // 'l'
      expect(mem.readWord(0), 0x476C756C);
    });

    test('should read version from real game', () {
      final mem = GlulxMemoryMap(storyData);
      // Version 3.1.2 -> 0x00030102
      expect(mem.readShort(4), 0x0003);
      expect(mem.readShort(6), 0x0102);
    });

    test('should write to RAM in real game', () {
      // Spec: "RAMSTART: The first address which the program can write to."
      final mem = GlulxMemoryMap(storyData);
      final address = mem.ramStart;

      mem.writeByte(address, 0xFF);
      expect(mem.readByte(address), 0xFF);

      mem.writeShort(address + 1, 0x1234);
      expect(mem.readShort(address + 1), 0x1234);

      mem.writeWord(address + 4, 0xDEADBEEF);
      expect(mem.readWord(address + 4), 0xDEADBEEF);
    });

    test('should protect ROM from writes in real game', () {
      // Spec: "the section marked ROM never changes during execution; it is illegal to write there."
      final mem = GlulxMemoryMap(storyData);
      expect(() => mem.writeByte(0, 0x00), throwsA(isA<GlulxException>()));
      expect(
        () => mem.writeShort(mem.ramStart - 2, 0x0000),
        throwsA(isA<GlulxException>()),
      );
      expect(
        () => mem.writeWord(100, 0x00000000),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on write beyond memory bounds in real game', () {
      final mem = GlulxMemoryMap(storyData);
      expect(
        () => mem.writeByte(mem.endMem, 0x00),
        throwsA(isA<GlulxException>()),
      );
    });

    test('should throw on read beyond memory bounds in real game', () {
      final mem = GlulxMemoryMap(storyData);
      expect(() => mem.readByte(mem.endMem), throwsA(isA<GlulxException>()));
    });
  });
}
