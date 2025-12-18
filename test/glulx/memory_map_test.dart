import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'glulx_test_utils.dart';

void main() {
  group('GlulxMemoryMap (monkey.gblorb)', () {
    late Uint8List storyData;

    setUp(() {
      storyData = GlulxTestUtils.loadTestGame('assets/games/monkey.gblorb');
    });

    test('should initialize and read header correctly', () {
      // Spec: "The header is the first 36 bytes of memory."
      // Values for monkey.gblorb
      final mem = GlulxMemoryMap(storyData);
      expect(mem.ramStart, 3573504); // 0x368600
      expect(mem.extStart, 7905536); // 0x78A100
      expect(mem.endMem, 7905536); // 0x78A100
    });

    test('should read bytes correctly', () {
      // Spec: "Main memory is a simple array of bytes, numbered from zero up."
      final mem = GlulxMemoryMap(storyData);
      expect(mem.readByte(0), 0x47); // 'G'
      expect(mem.readByte(1), 0x6C); // 'l'
      expect(mem.readByte(2), 0x75); // 'u'
      expect(mem.readByte(3), 0x6C); // 'l'
    });

    test('should read shorts in big-endian', () {
      // Spec: "When accessing multibyte values, the most significant byte is stored first (big-endian)."
      final mem = GlulxMemoryMap(storyData);
      // Byte 4-5 are version major/minor. Version 3.1.2 -> 0x0003, 0x0102
      expect(mem.readShort(4), 0x0003);
      expect(mem.readShort(6), 0x0102);
    });

    test('should read words in big-endian', () {
      // Spec: "When accessing multibyte values, the most significant byte is stored first (big-endian)."
      final mem = GlulxMemoryMap(storyData);
      // Word at offset 0 should be the magic number 47 6C 75 6C
      expect(mem.readWord(0), 0x476C756C);
    });

    test('should write to RAM correctly', () {
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

    test('should protect ROM from writes', () {
      // Spec: "the section marked ROM never changes during execution; it is illegal to write there."
      final mem = GlulxMemoryMap(storyData);
      expect(() => mem.writeByte(0, 0x00), throwsA(isA<GlulxException>()));
      expect(() => mem.writeShort(mem.ramStart - 2, 0x0000), throwsA(isA<GlulxException>()));
      expect(() => mem.writeWord(100, 0x00000000), throwsA(isA<GlulxException>()));
    });

    test('should throw if writing beyond memory bounds', () {
      final mem = GlulxMemoryMap(storyData);
      expect(() => mem.writeByte(mem.endMem, 0x00), throwsA(isA<GlulxException>()));
    });

    test('should throw if magic number is invalid', () {
      final corruptedData = Uint8List.fromList(storyData);
      corruptedData[0] = 0x00;
      expect(() => GlulxMemoryMap(corruptedData), throwsA(isA<GlulxException>()));
    });
  });
}
