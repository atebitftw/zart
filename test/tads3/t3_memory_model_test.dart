import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// T3 Memory Model unit tests with TADS 3 specification validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/model.htm
/// - "Memory Model" section (lines 427-526)
/// - "Storage Conventions" section (lines 65-167)
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/format.htm
/// - "Constant Pool Definition Block" (CPDF)
/// - "Constant Pool Page Block" (CPPG)
void main() {
  group('T3ConstantPool structure', () {
    /// Spec: model.htm lines 458-469:
    /// "Constant pool. This is a pool of static strings and lists.
    /// Constants within the constant pool are addressed by a 32-bit
    /// offset within the pool. The pool is divided into segments of
    /// a fixed size, and the segments are accessed via a segment table
    /// which contains an array of pointers to the segments."
    test('constant pool uses paged structure per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 4, pageSize: 1024);

      expect(pool.poolId, 2);
      expect(pool.pageCount, 4);
      expect(pool.pageSize, 1024);
    });

    /// Spec: model.htm lines 463-469:
    /// "Hence, to find the memory location containing a given address,
    /// divide the address's offset by the segment size to get the segment
    /// table index, retaining the remainder of the division as the
    /// segment offset; the memory location is obtained by adding the
    /// segment offset to the value of the pointer at the segment table
    /// index."
    test('offset resolution divides by page size', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 4, pageSize: 1000);

      // Load page 0 with test data
      final page0 = Uint8List(1000);
      page0[500] = 0xAB;
      pool.loadPage(0, page0);

      // Offset 500 should resolve to page 0, offset 500
      expect(pool.readByte(500), 0xAB);

      // Load page 1 with test data
      final page1 = Uint8List(1000);
      page1[234] = 0xCD;
      pool.loadPage(1, page1);

      // Offset 1234 = page 1 (1234 ~/ 1000), offset 234 (1234 % 1000)
      expect(pool.readByte(1234), 0xCD);
    });

    /// Spec: model.htm lines 469:
    /// "Each single string and list within the constant pool must be
    /// contained entirely within a single segment."
    test('page loading works correctly', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 2, pageSize: 256);

      expect(pool.isPageLoaded(0), isFalse);
      expect(pool.isPageLoaded(1), isFalse);

      pool.loadPage(0, Uint8List(256));
      expect(pool.isPageLoaded(0), isTrue);
      expect(pool.isPageLoaded(1), isFalse);
    });
  });

  group('T3ConstantPool byte ordering', () {
    /// Spec: model.htm lines 99-120:
    /// "16-bit unsigned integer. Stored as a two-byte array, with the
    /// least significant 8 bits first byte, and the most significant
    /// 8 bits in the second byte."
    /// "32-bit unsigned integer. Stored as a four-byte array. The least
    /// significant 8 bits are in the first byte..."
    test('reads little-endian integers per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // UINT16 at offset 0: 0x1234 stored as [0x34, 0x12]
      page[0] = 0x34;
      page[1] = 0x12;

      // UINT32 at offset 10: 0x12345678 stored as [0x78, 0x56, 0x34, 0x12]
      page[10] = 0x78;
      page[11] = 0x56;
      page[12] = 0x34;
      page[13] = 0x12;

      pool.loadPage(0, page);

      expect(pool.readUint16(0), 0x1234);
      expect(pool.readUint32(10), 0x12345678);
    });

    /// Spec: model.htm lines 100-103:
    /// "16-bit signed integer. Stored as a two-byte array... The value
    /// obtained by concatenating the two bytes into a single 16-bit
    /// value uses 2's complement notation."
    test('reads signed integers using twos complement per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // INT16 -1 = 0xFFFF stored as [0xFF, 0xFF]
      page[0] = 0xFF;
      page[1] = 0xFF;

      // INT32 -1 = 0xFFFFFFFF
      page[10] = 0xFF;
      page[11] = 0xFF;
      page[12] = 0xFF;
      page[13] = 0xFF;

      pool.loadPage(0, page);

      expect(pool.readInt16(0), -1);
      expect(pool.readInt32(10), -1);
    });

    /// Spec: model.htm lines 109-114:
    /// "32-bit signed integer. Stored as a four-byte array... The value
    /// obtained by concatenating the four bytes into a single 32-bit
    /// value uses 2's complement notation."
    test('reads negative 32-bit values correctly', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // -100 in 32-bit two's complement = 0xFFFFFF9C
      page[0] = 0x9C;
      page[1] = 0xFF;
      page[2] = 0xFF;
      page[3] = 0xFF;

      pool.loadPage(0, page);

      expect(pool.readInt32(0), -100);
    });
  });

  group('T3ConstantPool string reading', () {
    /// Spec: model.htm lines 383-388:
    /// "A string constant is a value with primitive type string, and a
    /// 32-bit offset into the constant pool. In the constant pool, the
    /// string's data bytes consist of a two-byte length prefix giving
    /// the number of bytes in the string, not counting the prefix bytes
    /// themselves, followed immediately by the bytes of the string."
    test('reads string with length prefix per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // String "Hello" at offset 0:
      // Length = 5 (0x0005) as UINT16 little-endian
      page[0] = 0x05;
      page[1] = 0x00;
      // UTF-8 bytes for "Hello"
      page[2] = 0x48; // H
      page[3] = 0x65; // e
      page[4] = 0x6C; // l
      page[5] = 0x6C; // l
      page[6] = 0x6F; // o

      pool.loadPage(0, page);

      expect(pool.readString(0), 'Hello');
    });

    /// Spec: model.htm lines 122-130:
    /// "Text. All text is stored as 16-bit Unicode characters. Strings
    /// are stored in UTF-8 format, which encodes 16-bit Unicode
    /// characters in one, two, or three bytes"
    test('reads UTF-8 encoded string per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // String "Café" uses multi-byte UTF-8 for é (0xC3 0xA9)
      // Length = 5 bytes (C-a-f-é where é is 2 bytes)
      page[0] = 0x05;
      page[1] = 0x00;
      page[2] = 0x43; // C
      page[3] = 0x61; // a
      page[4] = 0x66; // f
      page[5] = 0xC3; // é (byte 1)
      page[6] = 0xA9; // é (byte 2)

      pool.loadPage(0, page);

      expect(pool.readString(0), 'Café');
    });
  });

  group('T3ConstantPool list reading', () {
    /// Spec: model.htm lines 391-399:
    /// "A list constant is a value with primitive type list, and a 32-bit
    /// offset into the constant pool. In the constant pool, the list's
    /// data bytes consist of a two-byte length prefix giving the number
    /// of bytes in the list... followed immediately by the list's
    /// contents. The list consists of a series of elements concatenated
    /// together. Each element consists of a one-byte type prefix,
    /// followed immediately by the value."
    test('reads list with element count prefix per spec', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // List with 2 elements at offset 0:
      // Element count = 2 (UINT16)
      page[0] = 0x02;
      page[1] = 0x00;

      // Element 0: integer 42
      // Type = 7 (int_), Value = 42 (0x0000002A)
      page[2] = 0x07; // type
      page[3] = 0x2A; // value bytes (little-endian)
      page[4] = 0x00;
      page[5] = 0x00;
      page[6] = 0x00;

      // Element 1: integer 100
      page[7] = 0x07; // type
      page[8] = 0x64; // value = 100
      page[9] = 0x00;
      page[10] = 0x00;
      page[11] = 0x00;

      pool.loadPage(0, page);

      final list = pool.readList(0);
      expect(list.length, 2);
      expect(list[0].type, T3DataType.int_);
      expect(list[0].value, 42);
      expect(list[1].value, 100);
    });
  });

  group('T3CodePool structure', () {
    /// Spec: model.htm lines 471-478:
    /// "Code pool. This is a pool of static byte code blocks. A code
    /// block is addressed by a 32-bit offset with in the pool. As with
    /// the constant pool, the code pool is divided into segments of a
    /// fixed size, and the segments are accessed through a segment table."
    test('code pool uses paged structure per spec', () {
      final pool = T3CodePool(poolId: 1, pageCount: 8, pageSize: 4096);

      expect(pool.poolId, 1);
      expect(pool.pageCount, 8);
      expect(pool.pageSize, 4096);
      expect(pool.totalSize, 32768);
    });

    /// Spec: model.htm lines 476-478:
    /// "Note: A given method must always be stored in a single code page;
    /// a method cannot span pages."
    test('code pool loads pages independently', () {
      final pool = T3CodePool(poolId: 1, pageCount: 2, pageSize: 1024);

      expect(pool.isPageLoaded(0), isFalse);

      final page0 = Uint8List(1024);
      page0[0] = 0x01; // OPC_PUSH_0
      pool.loadPage(0, page0);

      expect(pool.isPageLoaded(0), isTrue);
      expect(pool.readByte(0), 0x01);
    });
  });

  group('T3CodePool method header reading', () {
    /// Spec: model.htm lines 1395-1400+ describes method header structure:
    /// "The method header contains:
    /// - The number of parameters the function expects to receive...
    ///   If the high-order bit of the byte is set, it indicates that the
    ///   function takes a variable number of parameters"
    test('reads method header with varargs flag per spec', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Method header:
      // Byte 0: arg count (0x83 = varargs + 3 min args)
      page[0] = 0x83;
      // Byte 1: optional args
      page[1] = 0x02;
      // Bytes 2-3: local count (UINT16) = 5
      page[2] = 0x05;
      page[3] = 0x00;
      // Bytes 4-5: stack slots (UINT16) = 10
      page[4] = 0x0A;
      page[5] = 0x00;
      // Bytes 6-7: exception table offset = 0
      page[6] = 0x00;
      page[7] = 0x00;
      // Bytes 8-9: debug record offset = 0
      page[8] = 0x00;
      page[9] = 0x00;

      pool.loadPage(0, page);

      final header = pool.readMethodHeader(0, 10);

      expect(header.isVarargs, isTrue);
      expect(header.minArgs, 3);
      expect(header.optionalArgs, 2);
      expect(header.localCount, 5);
      expect(header.stackSlots, 10);
    });

    /// Spec: Method headers specify argument requirements for validation.
    test('reads non-varargs method header', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Method with exactly 2 args, 3 locals
      page[0] = 0x02; // 2 args, no varargs
      page[1] = 0x00; // 0 optional
      page[2] = 0x03; // 3 locals
      page[3] = 0x00;
      page[4] = 0x08; // 8 stack slots
      page[5] = 0x00;
      page[6] = 0x00;
      page[7] = 0x00;
      page[8] = 0x00;
      page[9] = 0x00;

      pool.loadPage(0, page);

      final header = pool.readMethodHeader(0, 10);

      expect(header.isVarargs, isFalse);
      expect(header.minArgs, 2);
      expect(header.localCount, 3);
    });
  });

  group('T3CodePool bytecode reading', () {
    /// Spec: Bytecode is stored in code pool and accessed by offset.
    test('reads bytecode at offset', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Simple bytecode sequence
      page[0] = 0x01; // OPC_PUSH_0
      page[1] = 0x02; // OPC_PUSH_1
      page[2] = 0x22; // OPC_ADD

      pool.loadPage(0, page);

      expect(pool.readByte(0), 0x01);
      expect(pool.readByte(1), 0x02);
      expect(pool.readByte(2), 0x22);
    });

    /// Spec: Signed immediates use two's complement.
    test('reads signed byte operands', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // PUSHINT8 with -5 (0xFB in two's complement)
      page[0] = 0x03; // OPC_PUSHINT8
      page[1] = 0xFB; // -5

      pool.loadPage(0, page);

      expect(pool.readInt8(1), -5);
    });
  });

  group('T3Value portable format', () {
    /// Spec: model.htm "Storage Conventions" lines 140-149:
    /// "In order to facilitate fast loading, saving, and restoring, the
    /// T3 VM uses the same representation for certain structures in memory
    /// as it uses in a file. All data loadable from a program file... are
    /// stored in portable format in memory."
    test('value portable format matches spec', () {
      // Type 7 (int_) + value 0x12345678 in little-endian
      final data = Uint8List.fromList([7, 0x78, 0x56, 0x34, 0x12]);
      final val = T3Value.fromPortable(data, 0);

      expect(val.type, T3DataType.int_);
      expect(val.value, 0x12345678);
    });

    /// Spec: Values are 5 bytes: 1 byte type + 4 bytes data.
    test('value portable size is 5 bytes', () {
      expect(T3Value.portableSize, 5);

      final val = T3Value.fromInt(42);
      final data = Uint8List(5);
      val.toPortable(data, 0);

      expect(data[0], T3DataType.int_.code);
      expect(data[1], 42);
      expect(data[2], 0);
      expect(data[3], 0);
      expect(data[4], 0);
    });
  });

  group('T3ConstantPool edge cases', () {
    /// Empty string should be handled correctly
    test('reads empty string', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Empty string: length = 0
      page[0] = 0x00;
      page[1] = 0x00;

      pool.loadPage(0, page);

      expect(pool.readString(0), '');
    });

    /// Empty list should be handled correctly
    test('reads empty list', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Empty list: count = 0
      page[0] = 0x00;
      page[1] = 0x00;

      pool.loadPage(0, page);

      final list = pool.readList(0);
      expect(list, isEmpty);
    });

    /// Test reading from page 1+ (not just page 0)
    test('reads from non-zero page', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 4, pageSize: 100);

      // Load page 2 with test data
      final page2 = Uint8List(100);
      page2[50] = 0xDE;
      page2[51] = 0xAD;
      pool.loadPage(2, page2);

      // Offset 250 = page 2 (250 ~/ 100), offset 50 (250 % 100)
      expect(pool.readByte(250), 0xDE);
      expect(pool.readByte(251), 0xAD);
      expect(pool.readUint16(250), 0xADDE); // Little-endian
    });

    /// Accessing unloaded page should throw
    test('throws on unloaded page access', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 2, pageSize: 100);

      // Don't load any pages
      expect(() => pool.readByte(0), throwsStateError);
      expect(() => pool.readByte(100), throwsStateError);
    });

    /// Test list with different element types
    test('reads list with mixed element types', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // List with 3 elements: nil, true, int
      page[0] = 0x03; // count
      page[1] = 0x00;

      // Element 0: nil (type 1)
      page[2] = 0x01; // type = nil
      page[3] = 0x00;
      page[4] = 0x00;
      page[5] = 0x00;
      page[6] = 0x00;

      // Element 1: true (type 2)
      page[7] = 0x02; // type = true_
      page[8] = 0x00;
      page[9] = 0x00;
      page[10] = 0x00;
      page[11] = 0x00;

      // Element 2: object reference (type 5)
      page[12] = 0x05; // type = obj
      page[13] = 0x01; // object ID = 1
      page[14] = 0x00;
      page[15] = 0x00;
      page[16] = 0x00;

      pool.loadPage(0, page);

      final list = pool.readList(0);
      expect(list.length, 3);
      expect(list[0].type, T3DataType.nil);
      expect(list[1].type, T3DataType.true_);
      expect(list[2].type, T3DataType.obj);
      expect(list[2].value, 1);
    });

    /// Test string at non-zero offset
    test('reads string at arbitrary offset', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // Put some garbage data first
      page[0] = 0xFF;
      page[1] = 0xFF;

      // String "Test" at offset 50
      page[50] = 0x04; // length
      page[51] = 0x00;
      page[52] = 0x54; // T
      page[53] = 0x65; // e
      page[54] = 0x73; // s
      page[55] = 0x74; // t

      pool.loadPage(0, page);

      expect(pool.readString(50), 'Test');
    });

    /// Test multi-byte UTF-8 characters including 3-byte sequences
    test('reads 3-byte UTF-8 characters', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // String with Japanese character "日" (U+65E5) = 0xE6 0x97 0xA5
      page[0] = 0x03; // length = 3 bytes
      page[1] = 0x00;
      page[2] = 0xE6;
      page[3] = 0x97;
      page[4] = 0xA5;

      pool.loadPage(0, page);

      expect(pool.readString(0), '日');
    });

    /// Test maximum 32-bit offset values (within bounds)
    test('handles large offsets correctly', () {
      // Use a pool with larger page sizes
      final pool = T3ConstantPool(poolId: 2, pageCount: 10, pageSize: 10000);

      // Load page 5 with test data at offset 500
      final page5 = Uint8List(10000);
      page5[500] = 0x42;
      pool.loadPage(5, page5);

      // Offset 50500 = page 5, offset 500
      expect(pool.readByte(50500), 0x42);
    });

    /// Property ID elements in list
    test('reads list with property ID elements', () {
      final pool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // List with 1 element: property ID
      page[0] = 0x01;
      page[1] = 0x00;

      // Property ID (type 6) with value 0x1234
      page[2] = 0x06; // type = prop
      page[3] = 0x34;
      page[4] = 0x12;
      page[5] = 0x00;
      page[6] = 0x00;

      pool.loadPage(0, page);

      final list = pool.readList(0);
      expect(list.length, 1);
      expect(list[0].type, T3DataType.prop);
      expect(list[0].value, 0x1234);
    });
  });

  group('T3CodePool edge cases', () {
    /// Empty method header (minimal values)
    test('reads minimal method header', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // All zeros
      for (var i = 0; i < 10; i++) {
        page[i] = 0x00;
      }

      pool.loadPage(0, page);

      final header = pool.readMethodHeader(0, 10);
      expect(header.minArgs, 0);
      expect(header.optionalArgs, 0);
      expect(header.isVarargs, isFalse);
      expect(header.localCount, 0);
      expect(header.stackSlots, 0);
    });

    /// Maximum argument count (127 without varargs)
    test('reads method header with max args', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      page[0] = 0x7F; // 127 args, no varargs
      page[1] = 0x7F; // 127 optional
      page[2] = 0xFF; // 255 locals (high)
      page[3] = 0x00;
      page[4] = 0xFF;
      page[5] = 0xFF; // 65535 stack slots

      pool.loadPage(0, page);

      final header = pool.readMethodHeader(0, 10);
      expect(header.minArgs, 127);
      expect(header.optionalArgs, 127);
      expect(header.isVarargs, isFalse);
    });

    /// Reading from page boundary
    test('reads data from page boundary', () {
      final pool = T3CodePool(poolId: 1, pageCount: 2, pageSize: 100);

      final page0 = Uint8List(100);
      page0[99] = 0xAB; // Last byte of page 0
      pool.loadPage(0, page0);

      final page1 = Uint8List(100);
      page1[0] = 0xCD; // First byte of page 1
      pool.loadPage(1, page1);

      expect(pool.readByte(99), 0xAB);
      expect(pool.readByte(100), 0xCD);
    });

    /// Code pool string reading (dstring)
    test('reads string from code pool', () {
      final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 256);
      final page = Uint8List(256);

      // String "OK" at offset 10
      page[10] = 0x02; // length
      page[11] = 0x00;
      page[12] = 0x4F; // O
      page[13] = 0x4B; // K

      pool.loadPage(0, page);

      expect(pool.readString(10), 'OK');
    });
  });

  group('T3Value edge cases', () {
    /// Negative integer serialization
    test('serializes negative integer correctly', () {
      final val = T3Value.fromInt(-1);
      final data = Uint8List(5);
      val.toPortable(data, 0);

      expect(data[0], T3DataType.int_.code);
      // -1 = 0xFFFFFFFF
      expect(data[1], 0xFF);
      expect(data[2], 0xFF);
      expect(data[3], 0xFF);
      expect(data[4], 0xFF);
    });

    /// Large positive integer
    test('handles max 32-bit signed positive', () {
      final val = T3Value.fromInt(0x7FFFFFFF);
      final data = Uint8List(5);
      val.toPortable(data, 0);

      final read = T3Value.fromPortable(data, 0);
      expect(read.value, 0x7FFFFFFF);
    });

    /// Object ID serialization
    test('serializes object reference correctly', () {
      final val = T3Value.fromObject(12345);
      final data = Uint8List(5);
      val.toPortable(data, 0);

      expect(data[0], T3DataType.obj.code);
      // 12345 = 0x3039
      expect(data[1], 0x39);
      expect(data[2], 0x30);
      expect(data[3], 0x00);
      expect(data[4], 0x00);
    });

    /// Round-trip all basic types
    test('round-trips nil correctly', () {
      final val = T3Value.nil();
      final data = Uint8List(5);
      val.toPortable(data, 0);
      final read = T3Value.fromPortable(data, 0);
      expect(read.isNil, isTrue);
    });

    test('round-trips true correctly', () {
      final val = T3Value.true_();
      final data = Uint8List(5);
      val.toPortable(data, 0);
      final read = T3Value.fromPortable(data, 0);
      expect(read.isTrue, isTrue);
    });

    test('round-trips property ID correctly', () {
      final val = T3Value.fromProp(0xABCD);
      final data = Uint8List(5);
      val.toPortable(data, 0);
      final read = T3Value.fromPortable(data, 0);
      expect(read.type, T3DataType.prop);
      expect(read.value, 0xABCD);
    });
  });
}
