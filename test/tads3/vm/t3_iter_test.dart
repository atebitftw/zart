import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_iter.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

class MockStack extends T3Stack {
  MockStack() : super(100, 10);
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
  group('T3ObjIterIdx', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    T3Value makeIntVal(int i) => T3Value(T3DataType.int32)..setInt(i);

    T3ObjList createList(List<int> ints) {
      return T3ObjList(ints.map((i) => makeIntVal(i)).toList());
    }

    test('createForColl registers iterator in object table', () {
      final listVal = T3Value(T3DataType.list)..setList(0);
      final iterId = T3ObjIterIdx.createForColl(vm, listVal, 1, 5);

      expect(iterId, isNot(0));
      final obj = vm.objTable.getObj(iterId);
      expect(obj, isA<T3ObjIterIdx>());
    });

    test('constructor initializes curIndex to firstValid - 1', () {
      final listVal = T3Value(T3DataType.list)..setList(0);
      final iter = T3ObjIterIdx(listVal, 1, 5);

      expect(iter.curIndex, equals(0)); // firstValid - 1
      expect(iter.firstValid, equals(1));
      expect(iter.lastValid, equals(5));
    });

    group('getpIsNextAvail', () {
      test('returns true when more items available', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 3);

        final result = T3Value();
        expect(iter.getpIsNextAvail(vm, 0, result, 0), isTrue);
        expect(result.type, equals(T3DataType.trueValue));
      });

      test('returns false when no more items', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 1);
        iter.curIndex = 1; // At last valid

        final result = T3Value();
        expect(iter.getpIsNextAvail(vm, 0, result, 0), isTrue);
        expect(result.type, equals(T3DataType.nil));
      });
    });

    group('getpResetIter', () {
      test('resets curIndex to before first element', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 5);
        iter.curIndex = 3;

        final result = T3Value();
        expect(iter.getpResetIter(vm, 0, result, 0), isTrue);
        expect(iter.curIndex, equals(0)); // firstValid - 1
        expect(result.type, equals(T3DataType.nil));
      });
    });

    group('getpGetCurKey', () {
      test('returns current index', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 5);
        iter.curIndex = 3;

        final result = T3Value();
        expect(iter.getpGetCurKey(vm, 0, result, 0), isTrue);
        expect(result.type, equals(T3DataType.int32));
        expect(result.getAsInt(), equals(3));
      });

      test('throws when out of range (before first)', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 5);
        // curIndex is 0, which is < firstValid (1)

        final result = T3Value();
        expect(
          () => iter.getpGetCurKey(vm, 0, result, 0),
          throwsA(
            isA<T3VmException>().having(
              (e) => e.errorCode,
              'errorCode',
              vmErrOutOfRange,
            ),
          ),
        );
      });

      test('throws when out of range (after last)', () {
        final listVal = T3Value(T3DataType.list)..setList(0);
        final iter = T3ObjIterIdx(listVal, 1, 5);
        iter.curIndex = 6; // Beyond lastValid

        final result = T3Value();
        expect(
          () => iter.getpGetCurKey(vm, 0, result, 0),
          throwsA(
            isA<T3VmException>().having(
              (e) => e.errorCode,
              'errorCode',
              vmErrOutOfRange,
            ),
          ),
        );
      });
    });

    group('iterNext', () {
      test('returns true and advances when items available', () {
        // Create a list object
        final list = createList([10, 20, 30]);
        final listId = vm.objTable.registerObj(list, false);

        // Create iterator for the list
        final listVal = T3Value(T3DataType.obj)..setObj(listId);
        final iter = T3ObjIterIdx(listVal, 1, 3);
        final iterId = vm.objTable.registerObj(iter, false);

        final result = T3Value();

        // First call
        expect(iter.iterNext(vm, iterId, result), isTrue);
        expect(result.getAsInt(), equals(10));
        expect(iter.curIndex, equals(1));

        // Second call
        expect(iter.iterNext(vm, iterId, result), isTrue);
        expect(result.getAsInt(), equals(20));
        expect(iter.curIndex, equals(2));

        // Third call
        expect(iter.iterNext(vm, iterId, result), isTrue);
        expect(result.getAsInt(), equals(30));
        expect(iter.curIndex, equals(3));

        // Fourth call - no more items
        expect(iter.iterNext(vm, iterId, result), isFalse);
        expect(iter.curIndex, equals(3)); // Unchanged
      });

      test('returns false immediately when no items', () {
        final list = createList([]);
        final listId = vm.objTable.registerObj(list, false);

        final listVal = T3Value(T3DataType.obj)..setObj(listId);
        final iter = T3ObjIterIdx(listVal, 1, 0); // Empty range
        final iterId = vm.objTable.registerObj(iter, false);

        final result = T3Value();
        expect(iter.iterNext(vm, iterId, result), isFalse);
      });
    });

    group('markRefs', () {
      test('handles object collection reference', () {
        final list = createList([1, 2, 3]);
        final listId = vm.objTable.registerObj(list, false);

        final collVal = T3Value(T3DataType.obj)..setObj(listId);
        final iter = T3ObjIterIdx(collVal, 1, 3);

        // Verify the collection type is correctly identified as an object
        expect(iter.collectionValue.type, equals(T3DataType.obj));
        expect(iter.collectionValue.getAsObj(), equals(listId));
      });

      test('handles constant list collection (no marking needed)', () {
        final collVal = T3Value(T3DataType.list)..setList(1234);
        final iter = T3ObjIterIdx(collVal, 1, 3);

        // Constant lists don't need marking - verify no crash
        expect(iter.collectionValue.type, equals(T3DataType.list));
      });
    });
  });

  group('T3MetaclassIter', () {
    test('has correct name', () {
      final meta = T3MetaclassIter();
      expect(meta.getMetaName(), equals('iterator/030001'));
    });

    test('createForImageLoad throws', () {
      final meta = T3MetaclassIter();
      expect(
        () => meta.createForImageLoad(T3VM(), 1),
        throwsA(isA<T3VmException>()),
      );
    });

    test('createFromStack throws', () {
      final meta = T3MetaclassIter();
      expect(
        () => meta.createFromStack(T3VM(), Uint8List(0), 0, 0),
        throwsA(isA<T3VmException>()),
      );
    });
  });

  group('T3MetaclassIterIdx', () {
    test('has correct name', () {
      final meta = T3MetaclassIterIdx();
      expect(meta.getMetaName(), equals('indexed-iterator/030000'));
    });

    test('getSupermetaReg returns iterator metaclass', () {
      final meta = T3MetaclassIterIdx();
      expect(meta.getSupermetaReg(), equals(T3ObjIter.metaclassReg));
    });

    test('createFromStack throws', () {
      final meta = T3MetaclassIterIdx();
      expect(
        () => meta.createFromStack(T3VM(), Uint8List(0), 0, 0),
        throwsA(isA<T3VmException>()),
      );
    });
  });

  group('T3ObjIter base class', () {
    test('isOfMetaclass returns true for iterator metaclass', () {
      final listVal = T3Value(T3DataType.list)..setList(0);
      final iter = T3ObjIterIdx(listVal, 1, 3);

      expect(iter.isOfMetaclass(T3ObjIter.metaclassReg), isTrue);
      expect(iter.isOfMetaclass(T3ObjIterIdx.metaclassRegIdx), isTrue);
    });
  });
}
