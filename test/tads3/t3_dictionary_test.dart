import 'dart:convert';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_dictionary.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3Dictionary', () {
    test('Creation', () {
      final dict = T3Dictionary.create(1);
      expect(dict.objectId, 1);
      expect(dict.metaclass, 'dictionary2');
      expect(dict.comparator.type, T3DataType.nil);
    });

    test('addWord, isWordDefined, findWord', () {
      final dict = T3Dictionary.create(1);

      // Add a word
      dict.addWord('book', 10, 100);
      expect(dict.isWordDefined('book'), isTrue);
      expect(dict.isWordDefined('table'), isFalse);

      // Find the word
      var matches = dict.findWord('book');
      expect(matches.length, 1);
      expect(matches[0].objectId, 10);
      expect(matches[0].propId, 100);

      // Add duplicate word with different object/prop
      dict.addWord('book', 11, 101);
      matches = dict.findWord('book');
      expect(matches.length, 2);

      // Order is preserved (insertion order)
      expect(matches[0].objectId, 10);
      expect(matches[1].objectId, 11);
      expect(matches[1].propId, 101);

      // Is word defined still true
      expect(dict.isWordDefined('book'), isTrue);
    });

    test('delWord', () {
      final dict = T3Dictionary.create(1);
      dict.addWord('book', 10, 100);
      dict.addWord('book', 11, 101);

      // Remove specific entry
      dict.delWord('book', 10, 100);
      var matches = dict.findWord('book');
      expect(matches.length, 1);
      expect(matches[0].objectId, 11);

      // Remove last entry
      dict.delWord('book', 11, 101);
      expect(dict.isWordDefined('book'), isFalse);
      expect(dict.findWord('book'), isEmpty);
    });

    test('setComparator', () {
      final dict = T3Dictionary.create(1);
      final comp = T3Value.fromObject(99);
      dict.setComparator(comp);
      expect(dict.comparator.value, 99);
    });

    test('Serialization and XOR obfuscation', () {
      final dict = T3Dictionary.create(5);
      dict.setComparator(T3Value.fromObject(123));
      dict.addWord('A', 1000, 20); // 'A' is 0x41. 0x41 ^ 0xBD = 0xFC.

      final data = dict.save();

      // Check structure manually
      // Comparator ID (4 bytes): 123 (0x7B) -> 7B 00 00 00
      // Entry Count (2 bytes): 1 -> 01 00
      // Entry 1:
      //   Key Len (1 byte): 1 -> 01
      //   Key Bytes (1 byte): 0x41 ^ 0xBD -> 0xFC
      //   Sub Count (2 bytes): 1 -> 01 00
      //   Obj ID (4 bytes): 1000 (0x3E8) -> E8 03 00 00
      //   Prop ID (2 bytes): 20 (0x14) -> 14 00

      // Total expected length: 4 + 2 + 1 + 1 + 2 + 4 + 2 = 16 bytes
      expect(data.length, 16);

      // Verify XOR byte
      expect(data[7], 0xFC);

      // Restore
      final restored = T3Dictionary.fromData(5, data);
      expect(restored.objectId, 5);
      expect(restored.comparator.value, 123);
      expect(restored.isWordDefined('A'), isTrue);

      final matches = restored.findWord('A');
      expect(matches.length, 1);
      expect(matches[0].objectId, 1000);
      expect(matches[0].propId, 20);
    });
  });
}
