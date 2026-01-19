import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

void main() {
  group('T3ObjList', () {
    late T3VM vm;

    setUp(() {
      vm = T3VM();
    });

    T3ObjList createList(List<int> ints) {
      return T3ObjList(ints.map((i) => T3Value(T3DataType.int32)..setInt(i)).toList());
    }

    test('length returns element count', () {
      final list = createList([1, 2, 3, 4, 5]);
      expect(list.length, equals(5));
    });

    test('length handles empty list', () {
      final list = T3ObjList([]);
      expect(list.length, equals(0));
    });

    test('getElement returns 1-based indexed element', () {
      final list = createList([10, 20, 30]);
      expect(list.getElement(1).getAsInt(), equals(10));
      expect(list.getElement(2).getAsInt(), equals(20));
      expect(list.getElement(3).getAsInt(), equals(30));
    });

    test('indexOf finds element (1-based result)', () {
      final list = createList([10, 20, 30, 20, 40]);
      final needle = T3Value(T3DataType.int32)..setInt(20);
      expect(list.indexOf(needle), equals(2));
    });

    test('indexOf returns 0 when not found', () {
      final list = createList([10, 20, 30]);
      final needle = T3Value(T3DataType.int32)..setInt(99);
      expect(list.indexOf(needle), equals(0));
    });

    test('indexOf with start position', () {
      final list = createList([10, 20, 30, 20, 40]);
      final needle = T3Value(T3DataType.int32)..setInt(20);
      expect(list.indexOf(needle, 3), equals(4));
    });

    test('lastIndexOf finds last occurrence', () {
      final list = createList([10, 20, 30, 20, 40]);
      final needle = T3Value(T3DataType.int32)..setInt(20);
      expect(list.lastIndexOf(needle), equals(4));
    });

    test('sublist extracts elements (1-based)', () {
      final list = createList([10, 20, 30, 40, 50]);
      final sub = list.sublist(2, 3);
      expect(sub.length, equals(3));
      expect(sub.getElement(1).getAsInt(), equals(20));
      expect(sub.getElement(2).getAsInt(), equals(30));
      expect(sub.getElement(3).getAsInt(), equals(40));
    });

    test('sublist to end when no length', () {
      final list = createList([10, 20, 30, 40, 50]);
      final sub = list.sublist(3);
      expect(sub.length, equals(3));
      expect(sub.getElement(1).getAsInt(), equals(30));
    });

    test('isListlike returns true', () {
      final list = createList([1, 2, 3]);
      expect(list.isListlike(vm, 0), isTrue);
    });

    test('llLength returns element count', () {
      final list = createList([1, 2, 3, 4]);
      expect(list.llLength(vm, 0), equals(4));
    });
  });

  group('T3ObjList.fromConstPool', () {
    test('parses empty list', () {
      final data = Uint8List.fromList([0, 0]); // count = 0
      final list = T3ObjList.fromConstPool(data, 0);
      expect(list.length, equals(0));
    });

    test('parses list with int elements', () {
      // List with 2 integers: 42 and 100
      final data = Uint8List.fromList([
        2, 0, // count = 2
        T3DataType.int32.index, 42, 0, 0, 0, // int 42
        T3DataType.int32.index, 100, 0, 0, 0, // int 100
      ]);
      final list = T3ObjList.fromConstPool(data, 0);
      expect(list.length, equals(2));
      expect(list.getElement(1).getAsInt(), equals(42));
      expect(list.getElement(2).getAsInt(), equals(100));
    });

    test('parses list with nil and true', () {
      final data = Uint8List.fromList([
        2, 0, // count = 2
        T3DataType.nil.index, // nil
        T3DataType.trueValue.index, // true
      ]);
      final list = T3ObjList.fromConstPool(data, 0);
      expect(list.length, equals(2));
      expect(list.getElement(1).type, equals(T3DataType.nil));
      expect(list.getElement(2).type, equals(T3DataType.trueValue));
    });
  });

  group('T3MetaclassList', () {
    test('has correct name', () {
      expect(T3MetaclassList.name, equals('list/030010'));
    });

    test('metaclass returns correct name', () {
      final meta = T3MetaclassList();
      expect(meta.getMetaName(), equals('list/030010'));
    });
  });
}
