import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_bytarr.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

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
  group('T3ObjByteArray', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    T3ObjByteArray createByteArray(List<int> bytes) {
      final arr = T3ObjByteArray(bytes.length);
      for (var i = 0; i < bytes.length; i++) {
        arr.setElement(i + 1, bytes[i]);
      }
      return arr;
    }

    int register(T3Object obj) {
      final id = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(id)!.obj = obj;
      return id;
    }

    // -------------------------------------------------------------------------
    // Construction tests
    // -------------------------------------------------------------------------

    test('constructor creates array of given size', () {
      final arr = T3ObjByteArray(10);
      expect(arr.length, equals(10));
    });

    test('all bytes initialized to zero', () {
      final arr = T3ObjByteArray(5);
      for (var i = 1; i <= 5; i++) {
        expect(arr.getElement(i), equals(0));
      }
    });

    test('fromBytes constructor copies data', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final arr = T3ObjByteArray.fromBytes(bytes);
      expect(arr.length, equals(5));
      expect(arr.getElement(1), equals(1));
      expect(arr.getElement(5), equals(5));
    });

    // -------------------------------------------------------------------------
    // Index get/set tests
    // -------------------------------------------------------------------------

    test('getElement and setElement work correctly', () {
      final arr = T3ObjByteArray(3);
      arr.setElement(1, 100);
      arr.setElement(2, 200);
      arr.setElement(3, 255);
      expect(arr.getElement(1), equals(100));
      expect(arr.getElement(2), equals(200));
      expect(arr.getElement(3), equals(255));
    });

    test('getElement throws on index < 1', () {
      final arr = T3ObjByteArray(3);
      expect(() => arr.getElement(0), throwsA(isA<T3VmException>()));
    });

    test('getElement throws on index > length', () {
      final arr = T3ObjByteArray(3);
      expect(() => arr.getElement(4), throwsA(isA<T3VmException>()));
    });

    test('setElement throws on value < 0', () {
      final arr = T3ObjByteArray(3);
      expect(() => arr.setElement(1, -1), throwsA(isA<T3VmException>()));
    });

    test('setElement throws on value > 255', () {
      final arr = T3ObjByteArray(3);
      expect(() => arr.setElement(1, 256), throwsA(isA<T3VmException>()));
    });

    test('indexValQ works for 1-based indexing', () {
      final arr = createByteArray([10, 20, 30]);
      final result = T3Value();
      arr.indexValQ(vm, result, 0, T3Value(T3DataType.int32)..setInt(2));
      expect(result.getAsInt(), equals(20));
    });

    test('setIndexValQ works for 1-based indexing', () {
      final arr = createByteArray([10, 20, 30]);
      final result = T3Value();
      arr.setIndexValQ(
        vm,
        result,
        0,
        T3Value(T3DataType.int32)..setInt(2),
        T3Value(T3DataType.int32)..setInt(99),
      );
      expect(arr.getElement(2), equals(99));
    });

    // -------------------------------------------------------------------------
    // Integer read/write tests
    // -------------------------------------------------------------------------

    test('readInt 8-bit unsigned', () {
      final arr = createByteArray([0, 128, 255]);
      final result = T3Value();

      vm.stack.pushInt(fmtInt8 | fmtUnsigned);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 6, result, 0, 2); // readInt
      expect(result.getAsInt(), equals(0));

      vm.stack.pushInt(fmtInt8 | fmtUnsigned);
      vm.stack.pushInt(2);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(128));

      vm.stack.pushInt(fmtInt8 | fmtUnsigned);
      vm.stack.pushInt(3);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(255));
    });

    test('readInt 8-bit signed', () {
      final arr = createByteArray([0, 127, 128, 255]);
      final result = T3Value();

      vm.stack.pushInt(fmtInt8 | fmtSigned);
      vm.stack.pushInt(2);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(127));

      vm.stack.pushInt(fmtInt8 | fmtSigned);
      vm.stack.pushInt(3);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(-128));

      vm.stack.pushInt(fmtInt8 | fmtSigned);
      vm.stack.pushInt(4);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(-1));
    });

    test('readInt 16-bit little-endian unsigned', () {
      final arr = createByteArray([0x34, 0x12]); // 0x1234
      final result = T3Value();

      vm.stack.pushInt(fmtInt16 | fmtLittleEndian | fmtUnsigned);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(0x1234));
    });

    test('readInt 16-bit big-endian unsigned', () {
      final arr = createByteArray([0x12, 0x34]); // 0x1234
      final result = T3Value();

      vm.stack.pushInt(fmtInt16 | fmtBigEndian | fmtUnsigned);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(0x1234));
    });

    test('readInt 32-bit little-endian unsigned', () {
      final arr = createByteArray([0x78, 0x56, 0x34, 0x12]); // 0x12345678
      final result = T3Value();

      vm.stack.pushInt(fmtInt32 | fmtLittleEndian | fmtUnsigned);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 6, result, 0, 2);
      expect(result.getAsInt(), equals(0x12345678));
    });

    test('writeInt 16-bit little-endian', () {
      final arr = T3ObjByteArray(4);
      final result = T3Value();

      vm.stack.pushInt(0x1234);
      vm.stack.pushInt(fmtInt16 | fmtLittleEndian);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 7, result, 0, 3); // writeInt

      expect(arr.getElement(1), equals(0x34));
      expect(arr.getElement(2), equals(0x12));
    });

    test('writeInt 16-bit big-endian', () {
      final arr = T3ObjByteArray(4);
      final result = T3Value();

      vm.stack.pushInt(0x1234);
      vm.stack.pushInt(fmtInt16 | fmtBigEndian);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 7, result, 0, 3);

      expect(arr.getElement(1), equals(0x12));
      expect(arr.getElement(2), equals(0x34));
    });

    test('writeInt 32-bit little-endian', () {
      final arr = T3ObjByteArray(4);
      final result = T3Value();

      vm.stack.pushInt(0x12345678);
      vm.stack.pushInt(fmtInt32 | fmtLittleEndian);
      vm.stack.pushInt(1);
      arr.evalProp(vm, 7, result, 0, 3);

      expect(arr.getElement(1), equals(0x78));
      expect(arr.getElement(2), equals(0x56));
      expect(arr.getElement(3), equals(0x34));
      expect(arr.getElement(4), equals(0x12));
    });

    // -------------------------------------------------------------------------
    // fillWith tests
    // -------------------------------------------------------------------------

    test('fillWith fills entire array', () {
      final arr = T3ObjByteArray(5);
      final result = T3Value();
      final selfId = register(arr);

      vm.stack.pushInt(42);
      arr.evalProp(vm, 4, result, selfId, 1);

      for (var i = 1; i <= 5; i++) {
        expect(arr.getElement(i), equals(42));
      }
    });

    test('fillWith fills partial range', () {
      final arr = createByteArray([1, 2, 3, 4, 5]);
      final result = T3Value();
      final selfId = register(arr);

      vm.stack.pushInt(2); // count
      vm.stack.pushInt(2); // start
      vm.stack.pushInt(99); // value
      arr.evalProp(vm, 4, result, selfId, 3);

      expect(arr.getElement(1), equals(1));
      expect(arr.getElement(2), equals(99));
      expect(arr.getElement(3), equals(99));
      expect(arr.getElement(4), equals(4));
      expect(arr.getElement(5), equals(5));
    });

    // -------------------------------------------------------------------------
    // copyFrom tests
    // -------------------------------------------------------------------------

    test('copyFrom copies between arrays', () {
      final src = createByteArray([100, 200, 255]);
      final dst = T3ObjByteArray(5);
      final srcId = register(src);
      final dstId = register(dst);
      final result = T3Value();

      vm.stack.pushInt(3); // count
      vm.stack.pushInt(2); // dstIdx
      vm.stack.pushInt(1); // srcIdx
      vm.stack.pushObj(srcId);
      dst.evalProp(vm, 3, result, dstId, 4);

      expect(dst.getElement(1), equals(0));
      expect(dst.getElement(2), equals(100));
      expect(dst.getElement(3), equals(200));
      expect(dst.getElement(4), equals(255));
      expect(dst.getElement(5), equals(0));
    });

    // -------------------------------------------------------------------------
    // subarray tests
    // -------------------------------------------------------------------------

    test('subarray extracts portion', () {
      final arr = createByteArray([10, 20, 30, 40, 50]);
      final selfId = register(arr);
      final result = T3Value();

      vm.stack.pushInt(3); // count
      vm.stack.pushInt(2); // start
      arr.evalProp(vm, 2, result, selfId, 2);

      final subArr = vm.objTable.getObj(result.getAsObj()!) as T3ObjByteArray;
      expect(subArr.length, equals(3));
      expect(subArr.getElement(1), equals(20));
      expect(subArr.getElement(2), equals(30));
      expect(subArr.getElement(3), equals(40));
    });

    // -------------------------------------------------------------------------
    // Equality tests
    // -------------------------------------------------------------------------

    test('equals returns true for same content', () {
      final arr1 = createByteArray([1, 2, 3]);
      final arr2 = createByteArray([1, 2, 3]);
      final id1 = register(arr1);
      final id2 = register(arr2);

      final val = T3Value(T3DataType.obj)..setObj(id2);
      expect(arr1.equals(vm, id1, val, 0), isTrue);
    });

    test('equals returns false for different content', () {
      final arr1 = createByteArray([1, 2, 3]);
      final arr2 = createByteArray([1, 2, 4]);
      final id1 = register(arr1);
      final id2 = register(arr2);

      final val = T3Value(T3DataType.obj)..setObj(id2);
      expect(arr1.equals(vm, id1, val, 0), isFalse);
    });

    test('equals returns false for different length', () {
      final arr1 = createByteArray([1, 2, 3]);
      final arr2 = createByteArray([1, 2]);
      final id1 = register(arr1);
      final id2 = register(arr2);

      final val = T3Value(T3DataType.obj)..setObj(id2);
      expect(arr1.equals(vm, id1, val, 0), isFalse);
    });

    test('equals returns true for self-reference', () {
      final arr = createByteArray([1, 2, 3]);
      final id = register(arr);

      final val = T3Value(T3DataType.obj)..setObj(id);
      expect(arr.equals(vm, id, val, 0), isTrue);
    });

    // -------------------------------------------------------------------------
    // Hash tests
    // -------------------------------------------------------------------------

    test('calcHash returns consistent value', () {
      final arr = createByteArray([1, 2, 3, 4, 5]);
      final hash1 = arr.calcHash(vm, 0, 0);
      final hash2 = arr.calcHash(vm, 0, 0);
      expect(hash1, equals(hash2));
      expect(hash1, equals(15)); // 1+2+3+4+5
    });

    // -------------------------------------------------------------------------
    // SHA-256 and MD5 tests
    // -------------------------------------------------------------------------

    test('sha256 returns 64-character hex string', () {
      final arr = createByteArray([72, 101, 108, 108, 111]); // "Hello"
      final result = T3Value();
      register(arr);

      arr.evalProp(vm, 10, result, 0, 0); // sha256

      final strObj = vm.objTable.getObj(result.getAsObj()!);
      expect(strObj, isNotNull);
    });

    test('digestMD5 returns 32-character hex string', () {
      final arr = createByteArray([72, 101, 108, 108, 111]); // "Hello"
      final result = T3Value();
      register(arr);

      arr.evalProp(vm, 11, result, 0, 0); // digestMD5

      final strObj = vm.objTable.getObj(result.getAsObj()!);
      expect(strObj, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Image loading tests
    // -------------------------------------------------------------------------

    test('loadFromImage parses correctly', () {
      final arr = T3ObjByteArray(0);
      // Format: UINT4(count) + bytes
      // count = 5
      final imageData = Uint8List.fromList([
        5, 0, 0, 0, // count = 5 (little-endian)
        10, 20, 30, 40, 50, // bytes
      ]);

      arr.loadFromImage(vm, 0, imageData, 0, imageData.length);

      expect(arr.length, equals(5));
      expect(arr.getElement(1), equals(10));
      expect(arr.getElement(5), equals(50));
    });
  });

  group('T3MetaclassByteArray', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    test('getMetaName returns correct identifier', () {
      expect(
        T3MetaclassByteArray.instance.getMetaName(),
        equals('bytearray/030002'),
      );
    });

    test('createFromStack with integer creates sized array', () {
      vm.stack.pushInt(10);
      final id = T3MetaclassByteArray.instance.createFromStack(
        vm,
        Uint8List(0),
        0,
        1,
      );
      final arr = vm.objTable.getObj(id) as T3ObjByteArray;
      expect(arr.length, equals(10));
    });

    test('createFromStack from ByteArray copies', () {
      // Create source array
      final src = T3ObjByteArray.fromBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      final srcId = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(srcId)!.obj = src;

      // Create copy
      vm.stack.pushObj(srcId);
      final id = T3MetaclassByteArray.instance.createFromStack(
        vm,
        Uint8List(0),
        0,
        1,
      );
      final arr = vm.objTable.getObj(id) as T3ObjByteArray;

      expect(arr.length, equals(5));
      expect(arr.getElement(1), equals(1));
      expect(arr.getElement(5), equals(5));
    });

    test('isMetaInstanceOf returns true for ByteArray', () {
      final arr = T3ObjByteArray(5);
      final id = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(id)!.obj = arr;

      expect(T3MetaclassByteArray.instance.isMetaInstanceOf(vm, id), isTrue);
    });
  });
}
