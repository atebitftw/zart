import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';

void main() {
  group('T3ObjString', () {
    test('length returns character count', () {
      final str = T3ObjString('hello');
      expect(str.length, equals(5));
    });

    test('length handles empty string', () {
      final str = T3ObjString('');
      expect(str.length, equals(0));
    });

    test('length handles unicode', () {
      final str = T3ObjString('héllo'); // 5 characters
      expect(str.length, equals(5));
    });

    test('substr extracts from start (1-based)', () {
      final str = T3ObjString('hello world');
      expect(str.substr(1, 5), equals('hello'));
    });

    test('substr extracts from middle', () {
      final str = T3ObjString('hello world');
      expect(str.substr(7, 5), equals('world'));
    });

    test('substr to end when no length', () {
      final str = T3ObjString('hello world');
      expect(str.substr(7), equals('world'));
    });

    test('substr handles out of bounds', () {
      final str = T3ObjString('hello');
      expect(str.substr(10), equals(''));
    });

    test('find locates substring (1-based result)', () {
      final str = T3ObjString('hello world');
      expect(str.find('world'), equals(7));
    });

    test('find returns 0 when not found', () {
      final str = T3ObjString('hello world');
      expect(str.find('xyz'), equals(0));
    });

    test('find with start position', () {
      final str = T3ObjString('hello hello');
      expect(str.find('hello', 2), equals(7));
    });

    test('findLast locates last occurrence', () {
      final str = T3ObjString('hello hello');
      expect(str.findLast('hello'), equals(7));
    });

    test('toUpper converts to uppercase', () {
      final str = T3ObjString('Hello World');
      expect(str.toUpper(), equals('HELLO WORLD'));
    });

    test('toLower converts to lowercase', () {
      final str = T3ObjString('Hello World');
      expect(str.toLower(), equals('hello world'));
    });

    test('startsWith checks prefix', () {
      final str = T3ObjString('hello world');
      expect(str.startsWith('hello'), isTrue);
      expect(str.startsWith('world'), isFalse);
    });

    test('endsWith checks suffix', () {
      final str = T3ObjString('hello world');
      expect(str.endsWith('world'), isTrue);
      expect(str.endsWith('hello'), isFalse);
    });
  });

  group('T3ObjString.fromConstPool', () {
    test('parses length-prefixed UTF-8', () {
      // "hello" encoded as length-prefixed UTF-8
      final data = Uint8List.fromList([
        5, 0, // length = 5 (little-endian)
        0x68, 0x65, 0x6c, 0x6c, 0x6f, // "hello"
      ]);
      final str = T3ObjString.fromConstPool(data, 0);
      expect(str.value, equals('hello'));
    });

    test('parses with offset', () {
      final data = Uint8List.fromList([
        0xFF, 0xFF, // garbage
        3, 0, // length = 3
        0x61, 0x62, 0x63, // "abc"
      ]);
      final str = T3ObjString.fromConstPool(data, 2);
      expect(str.value, equals('abc'));
    });
  });

  group('T3MetaclassString', () {
    test('has correct name', () {
      expect(T3MetaclassString.name, equals('string/030008'));
    });

    test('metaclass returns correct name', () {
      final meta = T3MetaclassString();
      expect(meta.getMetaName(), equals('string/030008'));
    });
  });
}
