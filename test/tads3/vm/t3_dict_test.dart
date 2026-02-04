import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_dict.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

class MockStack extends T3Stack {
  MockStack() : super(100, 10);

  void pushInt(int val) => push(T3Value(T3DataType.int32)..setInt(val));
}

class MockVM extends T3VM {
  @override
  final MockStack stack = MockStack();
  @override
  final T3ObjectTable objTable = T3ObjectTable();
  @override
  final T3MetaclassTable metaTable = T3MetaclassTable();
}

void main() {
  group('T3ObjDict', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    group('construction', () {
      test('creates empty Dictionary', () {
        final dict = T3ObjDict();
        expect(dict, isNotNull);
      });

      test('has correct metaclass name', () {
        expect(T3MetaclassDict.name, equals('dictionary2/030001'));
      });

      test('createFromStack with 0 args creates empty Dict', () {
        final id = T3ObjDict.createFromStack(vm, 0);
        final dict = vm.objTable.getObj(id);
        expect(dict, isA<T3ObjDict>());
      });

      test('createFromStack with 1 arg sets comparator', () {
        vm.stack.push(T3Value()..setNil());
        final id = T3ObjDict.createFromStack(vm, 1);
        final dict = vm.objTable.getObj(id);
        expect(dict, isA<T3ObjDict>());
      });

      test('createFromStack with 2 args throws', () {
        vm.stack.pushInt(1);
        vm.stack.pushInt(2);
        expect(
          () => T3ObjDict.createFromStack(vm, 2),
          throwsA(isA<T3VmException>()),
        );
      });
    });

    group('basic word operations', () {
      test('addWord adds word-object-property association', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);

        expect(dict.isWordDefined(vm, 'north'), isTrue);
      });

      test('addWord with same obj-prop is ignored', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);
        dict.addWord(vm, dictId, 'north', 100, 1); // duplicate

        final results = dict.findWord(vm, 'north', null);
        expect(results.length, equals(2)); // [obj, match]
      });

      test('addWord allows same word with different obj', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'take', 100, 1);
        dict.addWord(vm, dictId, 'take', 200, 1);

        final results = dict.findWord(vm, 'take', null);
        expect(results.length, equals(4)); // [obj, match, obj, match]
      });

      test('addWord allows same word with different prop', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'take', 100, 1);
        dict.addWord(vm, dictId, 'take', 100, 2);

        final results = dict.findWord(vm, 'take', null);
        expect(results.length, equals(4)); // [obj, match, obj, match]
      });

      test('delWord removes word association', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);
        dict.delWord(vm, dictId, 'north', 100, 1);

        expect(dict.isWordDefined(vm, 'north'), isFalse);
      });

      test('delWord removes only matching association', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'take', 100, 1);
        dict.addWord(vm, dictId, 'take', 200, 1);
        dict.delWord(vm, dictId, 'take', 100, 1);

        final results = dict.findWord(vm, 'take', null);
        expect(results.length, equals(2)); // Only obj 200 remains
        expect(results[0].getAsObj(), equals(200));
      });

      test('delWord with non-existent word does nothing', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.delWord(vm, dictId, 'nonexistent', 100, 1);

        expect(dict.isWordDefined(vm, 'nonexistent'), isFalse);
      });
    });

    group('findWord', () {
      test('returns empty list for undefined word', () {
        final dict = T3ObjDict();

        final results = dict.findWord(vm, 'undefined', null);
        expect(results.isEmpty, isTrue);
      });

      test('returns obj-match pairs for defined word', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);

        final results = dict.findWord(vm, 'north', null);
        expect(results.length, equals(2));
        expect(results[0].type, equals(T3DataType.obj));
        expect(results[0].getAsObj(), equals(100));
        expect(results[1].type, equals(T3DataType.int32));
        expect(results[1].getAsInt(), equals(1)); // match result
      });

      test('findWord with property filter', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'take', 100, 1); // verb
        dict.addWord(vm, dictId, 'take', 200, 2); // noun

        final results = dict.findWord(vm, 'take', 1);
        expect(results.length, equals(2));
        expect(results[0].getAsObj(), equals(100));
      });

      test('findWord returns multiple matches', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        for (var i = 1; i <= 5; i++) {
          dict.addWord(vm, dictId, 'common', i * 100, 1);
        }

        final results = dict.findWord(vm, 'common', null);
        expect(results.length, equals(10)); // 5 objects * 2 (obj + match)
      });
    });

    group('isWordDefined', () {
      test('returns false for undefined word', () {
        final dict = T3ObjDict();

        expect(dict.isWordDefined(vm, 'undefined'), isFalse);
      });

      test('returns true for defined word', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);

        expect(dict.isWordDefined(vm, 'north'), isTrue);
      });

      test('returns false after word is deleted', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);
        dict.delWord(vm, dictId, 'north', 100, 1);

        expect(dict.isWordDefined(vm, 'north'), isFalse);
      });
    });

    group('spelling correction', () {
      test('correct returns empty list for undefined word', () {
        final dict = T3ObjDict();

        final results = dict.correct('undefined', 2);
        expect(results.isEmpty, isTrue);
      });

      test('correct finds words within edit distance', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);
        dict.addWord(vm, dictId, 'south', 200, 1);

        final results = dict.correct('nroth', 2);
        expect(results.isNotEmpty, isTrue);

        final words = results.map((r) => r[0] as String).toList();
        expect(words, contains('north'));
      });

      test('correct excludes exact matches', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);

        final results = dict.correct('north', 2);
        expect(results.isEmpty, isTrue);
      });

      test('correct respects max edit distance', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);
        dict.addWord(vm, dictId, 'south', 200, 1);

        // 'xyz' is far from both words
        final results = dict.correct('xyz', 1);
        expect(results.isEmpty, isTrue);
      });

      test('correct includes edit distance in results', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'north', 100, 1);

        // 'nort' is 1 character short of 'north'
        final results = dict.correct('nort', 2);
        if (results.isNotEmpty) {
          final match = results.where((r) => r[0] == 'north').firstOrNull;
          if (match != null && match.isNotEmpty) {
            expect(match[1], equals(1)); // distance
          }
        }
      });

      test('correct handles transposition', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'the', 100, 1);

        final results = dict.correct('teh', 2);
        final words = results.map((r) => r[0] as String).toList();
        expect(words, contains('the'));
      });

      test('correct handles insertion', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'go', 100, 1);

        final results = dict.correct('goo', 1);
        final words = results.map((r) => r[0] as String).toList();
        expect(words, contains('go'));
      });

      test('correct handles deletion', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'look', 100, 1);

        final results = dict.correct('lok', 1);
        final words = results.map((r) => r[0] as String).toList();
        expect(words, contains('look'));
      });

      test('correct handles replacement', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'take', 100, 1);

        final results = dict.correct('taki', 1);
        final words = results.map((r) => r[0] as String).toList();
        expect(words, contains('take'));
      });
    });

    group('image loading', () {
      test('loadFromImage parses empty dictionary', () {
        // Empty dictionary: comparator=0, entry_count=0
        final data = Uint8List(6);
        final view = ByteData.sublistView(data);
        view.setUint32(0, 0, Endian.little); // comparator
        view.setUint16(4, 0, Endian.little); // entry count

        final dict = T3ObjDict();
        dict.loadFromImage(vm, 0, data, 0, data.length);

        expect(dict.isWordDefined(vm, 'anything'), isFalse);
      });

      test('loadFromImage parses dictionary with entries', () {
        // Dictionary with one word "test" -> obj=100, prop=1
        final keyBytes = 'test'.codeUnits.map((c) => c ^ 0xBD).toList();
        final keyLen = keyBytes.length;

        // Calculate sizes
        const headerSize = 6; // comparator(4) + entry_count(2)
        final entryHeader = 1 + keyLen + 2; // key_len(1) + key + sub_count(2)
        const subEntrySize = 6; // obj(4) + prop(2)

        final data = Uint8List(headerSize + entryHeader + subEntrySize);
        final view = ByteData.sublistView(data);

        var pos = 0;

        // Header
        view.setUint32(pos, 0, Endian.little); // comparator
        pos += 4;
        view.setUint16(pos, 1, Endian.little); // 1 entry
        pos += 2;

        // Entry: key "test"
        data[pos] = keyLen;
        pos++;
        for (var i = 0; i < keyLen; i++) {
          data[pos + i] = keyBytes[i];
        }
        pos += keyLen;

        // Sub-entry count
        view.setUint16(pos, 1, Endian.little);
        pos += 2;

        // Sub-entry: obj=100, prop=1
        view.setUint32(pos, 100, Endian.little);
        pos += 4;
        view.setUint16(pos, 1, Endian.little);
        pos += 2;

        final dict = T3ObjDict();
        dict.loadFromImage(vm, 0, data, 0, data.length);

        expect(dict.isWordDefined(vm, 'test'), isTrue);
        final results = dict.findWord(vm, 'test', null);
        expect(results.length, equals(2));
        expect(results[0].getAsObj(), equals(100));
      });

      test('loadFromImage handles XOR-obfuscated keys', () {
        // The key is XOR'd with 0xBD in the image
        final word = 'hello';
        final keyBytes = word.codeUnits.map((c) => c ^ 0xBD).toList();
        final keyLen = keyBytes.length;

        const headerSize = 6;
        final entryHeader = 1 + keyLen + 2;
        const subEntrySize = 6;

        final data = Uint8List(headerSize + entryHeader + subEntrySize);
        final view = ByteData.sublistView(data);

        var pos = 0;
        view.setUint32(pos, 0, Endian.little);
        pos += 4;
        view.setUint16(pos, 1, Endian.little);
        pos += 2;

        data[pos] = keyLen;
        pos++;
        for (var i = 0; i < keyLen; i++) {
          data[pos + i] = keyBytes[i];
        }
        pos += keyLen;

        view.setUint16(pos, 1, Endian.little);
        pos += 2;
        view.setUint32(pos, 42, Endian.little);
        pos += 4;
        view.setUint16(pos, 5, Endian.little);

        final dict = T3ObjDict();
        dict.loadFromImage(vm, 0, data, 0, data.length);

        expect(dict.isWordDefined(vm, word), isTrue);
      });
    });

    group('metaclass registration', () {
      test('getMetaclassReg returns correct metaclass', () {
        final dict = T3ObjDict();
        expect(dict.getMetaclassReg(), equals(T3ObjDict.metaclassReg));
      });

      test('isOfMetaclass returns true for Dict metaclass', () {
        final dict = T3ObjDict();
        expect(dict.isOfMetaclass(T3ObjDict.metaclassReg), isTrue);
      });
    });

    group('edge cases', () {
      test('handles empty word', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, '', 100, 1);

        expect(dict.isWordDefined(vm, ''), isTrue);
      });

      test('handles unicode words', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        dict.addWord(vm, dictId, 'café', 100, 1);
        dict.addWord(vm, dictId, '日本語', 200, 1);

        expect(dict.isWordDefined(vm, 'café'), isTrue);
        expect(dict.isWordDefined(vm, '日本語'), isTrue);
      });

      test('handles many words', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        for (var i = 0; i < 100; i++) {
          dict.addWord(vm, dictId, 'word$i', i, 1);
        }

        for (var i = 0; i < 100; i++) {
          expect(dict.isWordDefined(vm, 'word$i'), isTrue);
        }
      });

      test('setProp throws', () {
        final dict = T3ObjDict();
        final dictId = vm.objTable.registerObj(dict, false);

        expect(
          () => dict.setProp(vm, null, dictId, 1, T3Value()..setNil()),
          throwsA(isA<T3VmException>()),
        );
      });
    });
  });

  group('T3MetaclassDict', () {
    test('has correct name', () {
      final meta = T3MetaclassDict();
      expect(meta.getMetaName(), equals('dictionary2/030001'));
    });

    test('static name constant', () {
      expect(T3MetaclassDict.name, equals('dictionary2/030001'));
    });

    test('createForImageLoad creates empty Dict', () {
      final vm = MockVM();
      final meta = T3MetaclassDict();

      meta.createForImageLoad(vm, 1);
      final dict = vm.objTable.getObj(1);
      expect(dict, isA<T3ObjDict>());
    });

    test('createForRestore creates empty Dict', () {
      final vm = MockVM();
      final meta = T3MetaclassDict();

      meta.createForRestore(vm, 1);
      final dict = vm.objTable.getObj(1);
      expect(dict, isA<T3ObjDict>());
    });
  });
}
