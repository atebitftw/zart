import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_vector.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';

class MockStack {
  final List<T3Value> values = [];
  void push(T3Value val) => values.add(T3Value.copy(val));
  T3Value pop() => values.removeLast();
  void pushInt(int val) => push(T3Value(T3DataType.int32)..setInt(val));
  void pushObj(int id) => push(T3Value(T3DataType.obj)..setObj(id));
}

class MockVM extends T3VM {
  @override
  final MockStack stack = MockStack();
  @override
  final T3ObjectTable objTable = T3ObjectTable();
}

void main() {
  group('T3ObjVector', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    T3ObjVector createVector(List<int> ints) {
      final vec = T3ObjVector(ints.length);
      for (var i = 0; i < ints.length; i++) {
        vec.setIndexValQ(
          vm,
          T3Value(),
          0,
          T3Value(T3DataType.int32)..setInt(i + 1),
          T3Value(T3DataType.int32)..setInt(ints[i]),
        );
      }
      return vec;
    }

    int register(T3Object obj) {
      final id = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(id)!.obj = obj;
      return id;
    }

    test('initial size and capacity', () {
      final vec = T3ObjVector(10);
      expect(vec.length, equals(0));
      // Internal elements list should be 10
    });

    test('setElementCount resizes', () {
      final vec = T3ObjVector(5);
      vec.setElementCount(3);
      expect(vec.length, equals(3));
      vec.setElementCount(10);
      expect(vec.length, equals(10));
      expect(vec.getElement(10).type, equals(T3DataType.nil));
    });

    test('indexing get/set', () {
      final vec = createVector([10, 20]);
      final res = T3Value();
      vec.indexValQ(vm, res, 0, T3Value(T3DataType.int32)..setInt(1));
      expect(res.getAsInt(), equals(10));

      vec.setIndexValQ(
        vm,
        res,
        0,
        T3Value(T3DataType.int32)..setInt(1),
        T3Value(T3DataType.int32)..setInt(99),
      );
      expect(vec.getElement(1).getAsInt(), equals(99));
    });

    test('indexing beyond length expands by 1', () {
      final vec = createVector([10]);
      final res = T3Value();
      vec.setIndexValQ(
        vm,
        res,
        0,
        T3Value(T3DataType.int32)..setInt(2),
        T3Value(T3DataType.int32)..setInt(20),
      );
      expect(vec.length, equals(2));
      expect(vec.getElement(2).getAsInt(), equals(20));
    });

    test('append adds elements', () {
      final vec = createVector([10]);
      vm.stack.pushInt(20);
      vec.getProp(vm, 25, T3Value(), 0, [0], 1); // append
      expect(vec.length, equals(2));
      expect(vec.getElement(2).getAsInt(), equals(20));
    });

    test('insertAt shifts elements', () {
      final vec = createVector([10, 30]);
      vm.stack.pushInt(20);
      vm.stack.pushInt(2); // index 2
      vec.getProp(vm, 22, T3Value(), 0, [0], 2); // insertAt
      expect(vec.length, equals(3));
      expect(vec.getElement(1).getAsInt(), equals(10));
      expect(vec.getElement(2).getAsInt(), equals(20));
      expect(vec.getElement(3).getAsInt(), equals(30));
    });

    test('removeElementAt shifts elements', () {
      final vec = createVector([10, 20, 30]);
      vm.stack.pushInt(2); // index 2
      vec.getProp(vm, 23, T3Value(), 0, [0], 1); // removeElementAt
      expect(vec.length, equals(2));
      expect(vec.getElement(1).getAsInt(), equals(10));
      expect(vec.getElement(2).getAsInt(), equals(30));
    });

    test('toList returns T3ObjList', () {
      final vec = createVector([10, 20]);
      final res = T3Value();
      vec.getProp(vm, 1, res, 0, [0], 0); // toList
      expect(res.type, equals(T3DataType.obj));
      final listObj = vm.objTable.getObj(res.getAsObj()!);
      expect(listObj, isA<T3ObjList>());
      expect((listObj as T3ObjList).elements.length, equals(2));
    });

    test('subset returns new Vector', () {
      final vec = createVector([10, 20, 30, 40]);
      vm.stack.pushInt(2); // count
      vm.stack.pushInt(2); // start
      final res = T3Value();
      vec.getProp(vm, 5, res, 0, [0], 2); // subset
      final subVec = vm.objTable.getObj(res.getAsObj()!) as T3ObjVector;
      expect(subVec.length, equals(2));
      expect(subVec.getElement(1).getAsInt(), equals(20));
      expect(subVec.getElement(2).getAsInt(), equals(30));
    });

    test('copyFrom copies elements and expands if needed', () {
      final src = createVector([100, 200, 300]);
      final srcId = register(src);
      final dst = createVector([10]);

      vm.stack.pushInt(1); // count = 1 (default if null, but testing with 2)
      // wait, my copyFrom takes count as 4th arg
      vm.stack.pushInt(2); // count
      vm.stack.pushInt(2); // dstStart
      vm.stack.pushInt(2); // srcStart
      vm.stack.pushObj(srcId);

      dst.getProp(vm, 3, T3Value(), 0, [0], 4); // copyFrom
      expect(dst.length, equals(3));
      expect(dst.getElement(2).getAsInt(), equals(200));
      expect(dst.getElement(3).getAsInt(), equals(300));
    });

    test('fillVal fills range', () {
      final vec = createVector([0, 0, 0]);
      vm.stack.pushInt(2); // count
      vm.stack.pushInt(2); // start
      vm.stack.pushInt(9); // value
      vec.getProp(vm, 4, T3Value(), 0, [0], 3); // fillVal
      expect(vec.getElement(1).getAsInt(), equals(0));
      expect(vec.getElement(2).getAsInt(), equals(9));
      expect(vec.getElement(3).getAsInt(), equals(9));
    });

    test('indexOf finds element', () {
      final vec = createVector([10, 20, 30]);
      vm.stack.pushInt(20);
      final res = T3Value();
      vec.getProp(vm, 11, res, 0, [0], 1); // indexOf
      expect(res.getAsInt(), equals(2));
    });
  });

  group('T3MetaclassVector', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    test('createFromStack with initial size', () {
      vm.stack.pushInt(5); // initial size
      final id = T3MetaclassVector().createFromStack(vm, Uint8List(0), 0, 1);
      final vec = vm.objTable.getObj(id) as T3ObjVector;
      expect(vec.length, equals(5));
    });

    test('createFromStack from list', () {
      final list = T3ObjList([T3Value(T3DataType.int32)..setInt(42)]);
      final listId = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(listId)!.obj = list;

      vm.stack.pushObj(listId);
      final id = T3MetaclassVector().createFromStack(vm, Uint8List(0), 0, 1);
      final vec = vm.objTable.getObj(id) as T3ObjVector;
      expect(vec.length, equals(1));
      expect(vec.getElement(1).getAsInt(), equals(42));
    });
  });
}
